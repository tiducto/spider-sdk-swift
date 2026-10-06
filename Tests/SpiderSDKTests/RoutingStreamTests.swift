import XCTest
@testable import SpiderSDK
import SpiderContract

/// Guards the SSE `plan-stream` handling: the record parser that turns `chunk`/`pageInfo` events into the
/// `PlanStreamEvent`s (`.result` / `.done` / `.failure`, including realtime-delay mapping onto legs) and ignores
/// every other event, the stream body's wire shape (initial + `after`/`before` continuation), and the public
/// `planStream` end to end over a stubbed `URLSession.shared`. Mirrors the Kotlin SDK's RoutingStreamTest.
final class RoutingStreamTests: XCTestCase {
    // A `chunk` carries itinerary nodes; realtime delays ride on each leg's estimated{time,delay} +
    // realtimeState + realTime and must land on the domain Leg exactly as the batch plan maps them. The
    // frame's internal counters are dropped — a chunk surfaces only as `.result(itineraries)`.
    func testChunkMapsItinerariesToResultWithRealtimeDelays() {
        let data = """
        {
          "frontier": 1800, "found": 3, "finalized": 1,
          "results": [
            {
              "numberOfTransfers": 1,
              "start": "2026-07-15T08:00:00Z", "end": "2026-07-15T08:30:00Z", "duration": 1800,
              "legs": [
                {
                  "mode": "BUS",
                  "start": { "scheduledTime": "2026-07-15T08:00:00Z", "estimated": { "time": "2026-07-15T08:01:00Z", "delay": "PT60S" } },
                  "end":   { "scheduledTime": "2026-07-15T08:30:00Z", "estimated": { "time": "2026-07-15T08:32:00Z", "delay": "PT120S" } },
                  "realtimeState": "UPDATED", "realTime": true, "serviceDate": "2026-07-15",
                  "from": { "name": "Origin", "stop": { "gtfsId": "1:A" } },
                  "to":   { "name": "Dest",   "stop": { "gtfsId": "1:B" } },
                  "route": { "gtfsId": "1:R12", "shortName": "12" }, "trip": { "gtfsId": "1:T" },
                  "typicalArrivalDelay": 150, "interlineWithPreviousLeg": true
                }
              ]
            }
          ]
        }
        """
        guard case .result(let itineraries)? = parsePlanStreamRecord(event: "chunk", data: data) else {
            return XCTFail("expected result")
        }

        let itinerary = itineraries[0]
        XCTAssertEqual(itinerary.numberOfTransfers, 1)
        XCTAssertEqual(itinerary.durationSeconds, 1800)

        let leg = itinerary.legs[0]
        XCTAssertEqual(leg.mode, .bus)
        XCTAssertEqual(leg.startDelaySeconds, 60)
        XCTAssertEqual(leg.endDelaySeconds, 120)
        XCTAssertEqual(leg.startEstimated, "2026-07-15T08:01:00Z")
        XCTAssertTrue(leg.isRealtime)
        XCTAssertEqual(leg.realtimeState, .updated)
        XCTAssertEqual(leg.serviceDate, "2026-07-15")
        XCTAssertEqual(leg.fromGtfsId, "1:A")
        XCTAssertEqual(leg.toGtfsId, "1:B")
        XCTAssertEqual(leg.typicalArrivalDelaySeconds, 150)
        XCTAssertTrue(leg.interlineWithPreviousLeg)
    }

    // The `pageInfo` frame is the terminal event: it maps to `.done`, carrying the continuation cursors +
    // `hasNextPage`/`hasPreviousPage` the caller reads to drive `planStreamNext`/`planStreamPrevious`.
    func testPageInfoMapsToTerminalDone() {
        let data = """
        { "startCursor": "c-prev", "endCursor": "c-next", "hasNextPage": true, "hasPreviousPage": false, "searchWindowUsed": "PT1H", "routingErrors": [] }
        """
        guard case .done(let done)? = parsePlanStreamRecord(event: "pageInfo", data: data) else {
            return XCTFail("expected done")
        }
        XCTAssertEqual(done.pageInfo.startCursor, "c-prev")
        XCTAssertEqual(done.pageInfo.endCursor, "c-next")
        XCTAssertTrue(done.pageInfo.hasNextPage)
        XCTAssertFalse(done.pageInfo.hasPreviousPage)
        XCTAssertEqual(done.pageInfo.searchWindowUsed, "PT1H")
        XCTAssertEqual(done.routingErrors, [])
    }

    // Routing outcomes (a date outside the feed, an unknown stop) ride the terminal `pageInfo` frame, shaped
    // like batch `routingErrors`, so the stream reports them as a result rather than a failure.
    func testPageInfoCarriesRoutingErrors() {
        let data = """
        { "hasNextPage": false, "hasPreviousPage": false, "routingErrors": [
          { "code": "LOCATION_NOT_FOUND", "inputField": "FROM", "description": "Origin stop not found" },
          { "code": "OUTSIDE_SERVICE_PERIOD", "inputField": "DATE_TIME", "description": "Outside the feed" }
        ] }
        """
        guard case .done(let done)? = parsePlanStreamRecord(event: "pageInfo", data: data) else {
            return XCTFail("expected done")
        }
        XCTAssertEqual(done.routingErrors.map(\.code), [.locationNotFound, .outsideServicePeriod])
        XCTAssertEqual(done.routingErrors.map(\.inputField), [.from, .dateTime])
        XCTAssertEqual(done.routingErrors[0].description, "Origin stop not found")
    }

    // The server's terminal `done` frame is not surfaced — `pageInfo` already carried the cursors, so `done` only
    // marks the sweep's end and parses to nil.
    func testDoneFrameIsIgnored() {
        let data = """
        { "iterations": 3, "windowSeconds": 3600, "resultCount": 5, "stoppedBy": "targetResults" }
        """
        XCTAssertNil(parsePlanStreamRecord(event: "done", data: data))
    }

    // An event this SDK doesn't know is ignored, so a new event is additive. `error` is not part of the stream: it
    // parses to nil like any other unknown event.
    func testHeartbeatsAndUnknownEventsAreIgnored() {
        XCTAssertNil(parsePlanStreamRecord(event: "message", data: ""))
        XCTAssertNil(parsePlanStreamRecord(event: "weird", data: #"{ "x": 1 }"#))
        XCTAssertNil(parsePlanStreamRecord(event: "progress", data: "not json"))
        XCTAssertNil(parsePlanStreamRecord(event: "error", data: #"{"data":null,"errors":[{"message":"searchWindow is invalid","extensions":{"code":"BAD_REQUEST"}}]}"#))
    }

    // A known event whose payload breaks its schema is a decoding failure.
    func testMalformedKnownEventIsADecodingFailure() {
        let cases = [
            ("chunk", #"{"results":"nope"}"#),
            ("pageInfo", #"{"hasNextPage":true}"#),
            ("pageInfo", "not json"),
        ]
        for (event, data) in cases {
            guard case .failure(let error)? = parsePlanStreamRecord(event: event, data: data) else {
                return XCTFail("expected failure for \(event) \(data)")
            }
            XCTAssertEqual(error.code, .decoding, "\(event) \(data)")
            XCTAssertEqual(error.message, "failed to decode plan-stream \(event)")
        }
    }

    // MARK: request wire shape

    private func streamBodyJSON(_ body: PlanStreamRequest) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as! [String: Any]
    }

    // Pins the initial stream request wire shape (targetResults/maxWindow + via, no cursors) so a contract
    // regen can't silently rename or reorder the fields the SDK sends to /routing/plan-stream. `searchWindow`,
    // `first` and `last` are never sent — the stream paces itself.
    func testPlanStreamSendsInitialWireShapeWithoutCursors() throws {
        let (client, _) = makeClient { _ in json("{}") }
        let body = try client.routing.streamBody(
            PlanOptions(
                origin: .stop("1:A"),
                destination: .coordinate(49.2, 16.6),
                departAt: Date(timeIntervalSince1970: 1_784_000_000),
                via: [.passThrough("1:V")]
            ),
            targetResults: 5,
            maxWindowMinutes: 180,
            after: nil,
            before: nil
        )
        let expected: [String: Any] = [
            "dateTime": ["earliestDeparture": "2026-07-14T03:33:20Z"],
            "origin": ["location": ["stopLocation": ["stopLocationId": "1:A"]]],
            "destination": ["location": ["coordinate": ["latitude": 49.2, "longitude": 16.6]]],
            "via": [["passThrough": ["stopLocationIds": ["1:V"]]]],
            "targetResults": 5,
            "maxWindow": "PT180M",
        ]
        XCTAssertEqual(try streamBodyJSON(body) as NSDictionary, expected as NSDictionary)
    }

    // Reliability goes out as its wire name on the initial request and on both continuations; without it the key
    // is absent (see the initial wire shape above).
    func testPlanStreamSendsReliabilityWhenSet() throws {
        let (client, _) = makeClient { _ in json("{}") }
        let options = PlanOptions(origin: .stop("1:A"), destination: .stop("1:B"), reliability: .safe)
        for (after, before) in [(nil, nil), ("c-next", nil), (nil, "c-prev")] as [(String?, String?)] {
            let body = try client.routing.streamBody(
                options, targetResults: 5, maxWindowMinutes: 120, after: after, before: before
            )
            XCTAssertEqual(try streamBodyJSON(body)["reliability"] as? String, "SAFE")
        }
    }

    // planStreamNext routes its raw cursor into `after` (and never `before`): the continuation request carries
    // exactly the forward cursor.
    func testPlanStreamNextSendsAfterCursor() throws {
        let (client, _) = makeClient { _ in json("{}") }
        let body = try client.routing.streamBody(
            PlanOptions(origin: .stop("1:A"), destination: .stop("1:B")),
            targetResults: 8,
            maxWindowMinutes: 240,
            after: "c-next",
            before: nil
        )
        let actual = try streamBodyJSON(body)
        XCTAssertEqual(actual["after"] as? String, "c-next")
        XCTAssertNil(actual["before"])
        XCTAssertEqual(actual["targetResults"] as? Int, 8)
        XCTAssertEqual(actual["maxWindow"] as? String, "PT240M")
    }

    // planStreamPrevious routes its raw cursor into `before` (and never `after`): the continuation request
    // carries exactly the backward cursor.
    func testPlanStreamPreviousSendsBeforeCursor() throws {
        let (client, _) = makeClient { _ in json("{}") }
        let body = try client.routing.streamBody(
            PlanOptions(origin: .stop("1:A"), destination: .stop("1:B")),
            targetResults: 5,
            maxWindowMinutes: 360,
            after: nil,
            before: "c-prev"
        )
        let actual = try streamBodyJSON(body)
        XCTAssertEqual(actual["before"] as? String, "c-prev")
        XCTAssertNil(actual["after"])
    }

    // MARK: end to end through the public entry point

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(StubStreamProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(StubStreamProtocol.self)
        super.tearDown()
    }

    private func collect(_ stream: AsyncStream<PlanStreamEvent>) async -> [PlanStreamEvent] {
        var events: [PlanStreamEvent] = []
        for await event in stream { events.append(event) }
        return events
    }

    private let declinedStream = """
    event: chunk
    data: {"frontier":0,"found":0,"finalized":0,"results":[]}

    event: pageInfo
    data: {"startCursor":null,"endCursor":null,"hasNextPage":false,"hasPreviousPage":false,"searchWindowUsed":null,"routingErrors":[{"code":"OUTSIDE_SERVICE_PERIOD","inputField":"DATE_TIME","description":"Outside the feed"}]}

    event: done
    data: {"iterations":0,"windowSeconds":0,"resultCount":0,"stoppedBy":"rejected"}


    """

    // `planStream` POSTs the bare body to /routing/plan-stream asking for an event stream, with the caller's
    // `targetResults` and `maxWindow` (both required, no SDK default), and its terminal `.done` carries the routing
    // errors.
    func testPlanStreamPostsRestBodyAndEndsWithRoutingErrors() async throws {
        StubStreamProtocol.respond(status: 200, body: declinedStream)
        let client = SpiderClient(baseURL: "https://\(StubStreamProtocol.host)", apiKey: "k")
        let options = PlanOptions(origin: .stop("1:A"), destination: .stop("1:B"))
        let events = await collect(client.routing.planStream(options, targetResults: 3, maxWindowMinutes: 120))

        let request = try XCTUnwrap(StubStreamProtocol.recordedRequest)
        XCTAssertEqual(request.url?.path, "/routing/v1/plan-stream")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "accept"), "text/event-stream")
        XCTAssertEqual(request.value(forHTTPHeaderField: "content-type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-spider-contract-version"), "1.2")
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(StubStreamProtocol.requestBody)) as? [String: Any])
        XCTAssertNil(body["id"])
        XCTAssertNil(body["variables"])
        XCTAssertEqual(body["maxWindow"] as? String, "PT120M")
        XCTAssertEqual(body["targetResults"] as? Int, 3)

        // One event per SSE record, in order: the blank line between records is what separates them.
        guard events.count == 2, case .result = events[0], case .done(let done) = events[1] else {
            return XCTFail("expected result then done, got \(events)")
        }
        XCTAssertEqual(done.routingErrors.map(\.code), [.outsideServicePeriod])
        XCTAssertFalse(done.pageInfo.hasNextPage)
    }

    // Events this SDK doesn't know, wherever they fall, are skipped; the stream still ends with its outcome.
    func testPlanStreamIgnoresUnknownEvents() async throws {
        StubStreamProtocol.respond(status: 200, body: """
        : keep-alive

        event: progress
        data: {"frontier":600}

        event: chunk
        data: {"frontier":1200,"found":1,"finalized":1,"results":[{"numberOfTransfers":0,"legs":[]}]}

        event: error
        data: {"data":null,"errors":[{"message":"boom"}]}

        event: pageInfo
        data: {"startCursor":"p","endCursor":"n","hasNextPage":true,"hasPreviousPage":true,"searchWindowUsed":"PT20M","routingErrors":[]}

        event: done
        data: {"iterations":20,"windowSeconds":1200,"resultCount":1,"stoppedBy":"somethingNew"}


        """)
        let client = SpiderClient(baseURL: "https://\(StubStreamProtocol.host)", apiKey: "k")
        let events = await collect(client.routing.planStream(PlanOptions(origin: .stop("1:A"), destination: .stop("1:B")), targetResults: 1, maxWindowMinutes: 120))

        guard events.count == 2, case .result(let itineraries) = events[0], case .done(let done) = events[1] else {
            return XCTFail("expected result then done, got \(events)")
        }
        XCTAssertEqual(itineraries.count, 1)
        XCTAssertEqual(done.pageInfo.endCursor, "n")
    }

    func testPlanStreamCutBeforePageInfoIsANetworkFailure() async throws {
        let client = SpiderClient(baseURL: "https://\(StubStreamProtocol.host)", apiKey: "k")
        let options = PlanOptions(origin: .stop("1:A"), destination: .stop("1:B"))
        let chunk = "event: chunk\ndata: {\"frontier\":1200,\"found\":1,\"finalized\":1,\"results\":[{\"numberOfTransfers\":0,\"legs\":[]}]}\n\n"
        let pageInfo = "event: pageInfo\ndata: {\"hasNextPage\":false,\"hasPreviousPage\":false,\"routingErrors\":[]}\n"
        let cases: [(body: String, results: Int)] = [
            (chunk, 1),
            (chunk + "event: chunk\ndata: {\"results\":[", 1),
            (chunk + "event: pageInfo\ndata: {\"hasNextPage\":fa", 1),
            (chunk + pageInfo, 1),
            ("", 0),
        ]
        for (body, results) in cases {
            StubStreamProtocol.respond(status: 200, body: body)
            let events = await collect(client.routing.planStream(options, targetResults: 5, maxWindowMinutes: 120))
            guard events.count == results + 1, case .failure(let error) = events[results] else {
                return XCTFail("expected \(results) result(s) then a failure, got \(events)")
            }
            XCTAssertEqual(error.code, .network, body)
            XCTAssertEqual(error.message, "plan-stream ended before pageInfo")
        }

        StubStreamProtocol.respond(status: 200, contentType: "application/json", body: #"{"itineraries":[]}"#)
        let json = await collect(client.routing.planStream(options, targetResults: 5, maxWindowMinutes: 120))
        guard json.count == 1, case .failure(let jsonError) = json[0] else { return XCTFail("expected one failure, got \(json)") }
        XCTAssertEqual(jsonError.code, .network)
    }

    // A malformed known event ends the stream: the failure is the last event, nothing after it is read.
    func testPlanStreamDecodingFailureIsTerminal() async throws {
        StubStreamProtocol.respond(status: 200, body: """
        event: chunk
        data: {"results":"nope"}

        """ + declinedStream)
        let client = SpiderClient(baseURL: "https://\(StubStreamProtocol.host)", apiKey: "k")
        let events = await collect(client.routing.planStream(PlanOptions(origin: .stop("1:A"), destination: .stop("1:B")), targetResults: 5, maxWindowMinutes: 120))

        guard events.count == 1, case .failure(let error) = events[0] else { return XCTFail("expected one failure, got \(events)") }
        XCTAssertEqual(error.code, .decoding)
    }

    // A 410 before the stream opens ends it with the same `.queryRetired` failure the batch calls return.
    func testPlanStreamRetiredAnswerFailsWithQueryRetired() async throws {
        StubStreamProtocol.respond(status: 410, contentType: "application/json", body: #"{"code":"query_retired","message":"persisted queries are retired"}"#)
        let client = SpiderClient(baseURL: "https://\(StubStreamProtocol.host)", apiKey: "k")
        let options = PlanOptions(origin: .stop("1:A"), destination: .stop("1:B"))
        let events = await collect(client.routing.planStream(options, targetResults: 5, maxWindowMinutes: 120))

        guard events.count == 1, case .failure(let error) = events[0] else { return XCTFail("expected one failure, got \(events)") }
        XCTAssertEqual(error.code, .queryRetired)
        XCTAssertEqual(error.httpStatus, 410)
        XCTAssertEqual(error.serverCode, "query_retired")
        XCTAssertTrue(error.message.contains("persisted queries are retired"))
    }

    // A plan-limit refusal is the gateway's plain JSON 403, sent before the stream opens; the stream ends with the
    // same failure the batch calls return, carrying the body's message.
    func testPlanStreamPlanLimitRefusalFailsBeforeTheStream() async throws {
        let cases: [(body: String, code: SpiderErrorCode, message: String)] = [
            (#"{"error":"planning_limit_reached","message":"trip planning limit reached"}"#, .planningLimitReached, "trip planning limit reached"),
            (#"{"error":"agreement_inactive","message":"agreement is not active"}"#, .agreementInactive, "agreement is not active"),
            (#"{"code":"planning_limit_reached","error":"planning_limit_reached","message":"limit"}"#, .planningLimitReached, "limit"),
        ]
        let client = SpiderClient(baseURL: "https://\(StubStreamProtocol.host)", apiKey: "k")
        let options = PlanOptions(origin: .stop("1:A"), destination: .stop("1:B"))
        for (body, code, message) in cases {
            StubStreamProtocol.respond(status: 403, contentType: "application/json", body: body)
            let events = await collect(client.routing.planStream(options, targetResults: 5, maxWindowMinutes: 120))

            guard events.count == 1, case .failure(let error) = events[0] else { return XCTFail("expected one failure, got \(events)") }
            XCTAssertEqual(error.code, code)
            XCTAssertEqual(error.httpStatus, 403)
            XCTAssertEqual(error.serverCode, code.rawValue)
            XCTAssertEqual(error.message, message)
        }
    }

    // Without a plan-limit code a pre-stream 403 stays unauthorized.
    func testPlanStreamPlain403StaysUnauthorized() async throws {
        StubStreamProtocol.respond(status: 403, contentType: "application/json", body: #"{"error":"forbidden","message":"access denied"}"#)
        let client = SpiderClient(baseURL: "https://\(StubStreamProtocol.host)", apiKey: "k")
        let options = PlanOptions(origin: .stop("1:A"), destination: .stop("1:B"))
        let events = await collect(client.routing.planStream(options, targetResults: 5, maxWindowMinutes: 120))

        guard events.count == 1, case .failure(let error) = events[0] else { return XCTFail("expected one failure, got \(events)") }
        XCTAssertEqual(error.code, .unauthorized)
        XCTAssertEqual(error.httpStatus, 403)
    }

    // Validation answers before the stream opens, as a JSON 400 naming the field.
    func testPlanStream400FailsAsBadRequestWithField() async throws {
        StubStreamProtocol.respond(status: 400, contentType: "application/json", body: """
        {"code":"bad_request","message":"targetResults is out of range","field":"targetResults"}
        """)
        let client = SpiderClient(baseURL: "https://\(StubStreamProtocol.host)", apiKey: "k")
        let options = PlanOptions(origin: .stop("1:A"), destination: .stop("1:B"))
        let events = await collect(client.routing.planStream(options, targetResults: 500, maxWindowMinutes: 120))

        guard events.count == 1, case .failure(let error) = events[0] else { return XCTFail("expected one failure, got \(events)") }
        XCTAssertEqual(error.code, .badRequest)
        XCTAssertEqual(error.httpStatus, 400)
        XCTAssertEqual(error.field, "targetResults")
        XCTAssertTrue(error.message.contains("targetResults is out of range"))
    }

    // A window under the 2 h platform minimum, a via location outside its fixed limits, or a visit to a coordinate
    // fails before any request.
    func testPlanStreamRejectsInputsOutsideFixedLimitsWithoutRequest() async throws {
        StubStreamProtocol.respond(status: 200, body: "")
        let client = SpiderClient(baseURL: "https://\(StubStreamProtocol.host)", apiKey: "k")
        let options = PlanOptions(origin: .stop("1:A"), destination: .stop("1:B"))
        let viaOptions = PlanOptions(origin: .stop("1:A"), destination: .stop("1:B"), via: [.passThrough(stopIds: [])])
        let coordinateVisit = PlanOptions(origin: .stop("1:A"), destination: .stop("1:B"), via: [.visit(.coordinate(49.2, 16.6))])
        let longVisit = PlanOptions(origin: .stop("1:A"), destination: .stop("1:B"), via: [.visit(.stop("1:V"), minimumWaitSeconds: 3_601)])
        let cases: [(AsyncStream<PlanStreamEvent>, String, String)] = [
            (client.routing.planStream(options, targetResults: 5, maxWindowMinutes: 119), "maxWindow", "maxWindow is out of range"),
            (client.routing.planStreamNext(options, targetResults: 5, maxWindowMinutes: 0, after: "c"), "maxWindow", "maxWindow is out of range"),
            (client.routing.planStreamPrevious(options, targetResults: 5, maxWindowMinutes: -120, before: "c"), "maxWindow", "maxWindow is out of range"),
            (client.routing.planStream(viaOptions, targetResults: 5, maxWindowMinutes: 120), "via", "via is out of range"),
            (client.routing.planStream(longVisit, targetResults: 5, maxWindowMinutes: 120), "via.visit.minimumWaitTime", "via.visit.minimumWaitTime is out of range"),
            (client.routing.planStream(coordinateVisit, targetResults: 5, maxWindowMinutes: 120), "via", "via is invalid"),
            (client.routing.planStreamNext(coordinateVisit, targetResults: 5, maxWindowMinutes: 120, after: "c"), "via", "via is invalid"),
        ]
        for (stream, field, message) in cases {
            let events = await collect(stream)
            guard events.count == 1, case .failure(let error) = events[0] else { return XCTFail("expected one failure, got \(events)") }
            XCTAssertEqual(error.code, .badRequest)
            XCTAssertEqual(error.field, field)
            XCTAssertEqual(error.message, message)
        }
        XCTAssertNil(StubStreamProtocol.recordedRequest)
    }
}

// Serves one canned response to `URLSession.shared` (which `planStream` streams through) for requests to `host`,
// recording the request and its body, so the public stream entry points can be driven end to end.
final class StubStreamProtocol: URLProtocol {
    static let host = "stream.test"
    private static let lock = NSLock()
    private static var status = 200
    private static var contentType = "text/event-stream"
    private static var body = ""
    private static var lastRequest: URLRequest?
    private static var recordedBody: Data?

    static func respond(status: Int, contentType: String = "text/event-stream", body: String) {
        lock.lock(); defer { lock.unlock() }
        self.status = status
        self.contentType = contentType
        self.body = body
        lastRequest = nil
        recordedBody = nil
    }

    static var recordedRequest: URLRequest? {
        lock.lock(); defer { lock.unlock() }
        return lastRequest
    }

    static var requestBody: Data? {
        lock.lock(); defer { lock.unlock() }
        return recordedBody
    }

    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == host }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let sent = request.httpBody ?? request.httpBodyStream.map(Self.readAll)
        Self.lock.lock()
        Self.lastRequest = request
        Self.recordedBody = sent
        let status = Self.status
        let contentType = Self.contentType
        let body = Self.body
        Self.lock.unlock()
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["content-type": contentType])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
