import XCTest
@testable import SpiderSDK
import SpiderContract

/// Guards the SSE `plan-stream` handling: the record parser that turns `chunk`/`pageInfo`/`done`/`error`
/// events into the three `PlanStreamEvent`s (`.result` / `.done` / `.failure`, including realtime-delay
/// mapping onto legs), the stream request's wire shape (initial + `after`/`before` continuation), and the
/// public `planStream` end to end over a stubbed `URLSession.shared`. Mirrors the Kotlin SDK's RoutingStreamTest.
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
    // `hasNextPage`/`hasPreviousPage` the caller reads to drive `planStreamNext`/`planStreamPrevious`. A frame
    // without `routingErrors` means none.
    func testPageInfoMapsToTerminalDone() {
        let data = """
        { "startCursor": "c-prev", "endCursor": "c-next", "hasNextPage": true, "hasPreviousPage": false, "searchWindowUsed": "PT1H" }
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

    // The server's terminal `done` telemetry frame is not surfaced — `pageInfo` already carried the cursors, so
    // `done` only marks the sweep's end and parses to nil.
    func testDoneTelemetryFrameIsIgnored() {
        let data = """
        { "iterations": 3, "windowSeconds": 3600, "resultCount": 5, "stoppedBy": "targetResults" }
        """
        XCTAssertNil(parsePlanStreamRecord(event: "done", data: data))
    }

    // A stream `error` record is the GraphQL error envelope; a top-level BAD_REQUEST becomes a typed BadRequest.
    func testErrorEventMapsToTypedBadRequestFailure() {
        let data = """
        { "data": null, "errors": [ { "message": "searchWindow exceeds the cap", "extensions": { "code": "BAD_REQUEST", "field": "searchWindow" } } ] }
        """
        guard case .failure(let error)? = parsePlanStreamRecord(event: "error", data: data) else {
            return XCTFail("expected failure")
        }
        XCTAssertEqual(error.code, .badRequest)
        XCTAssertEqual(error.field, "searchWindow")
        XCTAssertEqual(error.message, "searchWindow exceeds the cap")
    }

    func testHeartbeatsAndUnknownEventsAreIgnored() {
        XCTAssertNil(parsePlanStreamRecord(event: "message", data: ""))
        XCTAssertNil(parsePlanStreamRecord(event: "weird", data: #"{ "x": 1 }"#))
    }

    // MARK: request wire shape

    private func streamVariablesJSON(_ variables: PlanConnectionStreamVariables) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try JSONSerialization.jsonObject(with: encoder.encode(variables)) as! [String: Any]
    }

    // Pins the initial stream request wire shape (targetResults/maxWindow + via, no cursors) so a contract
    // regen can't silently rename or reorder the fields the SDK sends to /routing/plan-stream. `searchWindow`
    // must NOT be sent — the stream paces itself.
    func testPlanStreamSendsInitialWireShapeWithoutCursors() throws {
        let (client, _) = makeClient { _ in json("{}") }
        let variables = client.routing.streamVariables(
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
        let actual = try streamVariablesJSON(variables)

        // Field presence + omission (nil optionals must not appear): the wire body carries exactly these keys.
        XCTAssertEqual(Set(actual.keys), ["dateTime", "origin", "destination", "via", "targetResults", "maxWindow"])
        XCTAssertEqual(actual["targetResults"] as? Int, 5)
        XCTAssertEqual(actual["maxWindow"] as? String, "PT180M")
        XCTAssertNil(actual["searchWindow"])
        XCTAssertNil(actual["before"])
        XCTAssertNil(actual["after"])
        let origin = ((actual["origin"] as! [String: Any])["location"] as! [String: Any])["stopLocation"] as! [String: Any]
        XCTAssertEqual(origin["stopLocationId"] as? String, "1:A")
        let via = actual["via"] as! [[String: Any]]
        let stopIds = (via[0]["passThrough"] as! [String: Any])["stopLocationIds"] as! [String]
        XCTAssertEqual(stopIds, ["1:V"])
    }

    // Reliability goes out as its wire name; without it the key is absent (see the initial wire shape above).
    func testPlanStreamSendsReliabilityWhenSet() throws {
        let (client, _) = makeClient { _ in json("{}") }
        let variables = client.routing.streamVariables(
            PlanOptions(origin: .stop("1:A"), destination: .stop("1:B"), reliability: .safe),
            targetResults: 5,
            maxWindowMinutes: 120,
            after: nil,
            before: nil
        )
        let actual = try streamVariablesJSON(variables)
        XCTAssertEqual(actual["reliability"] as? String, "SAFE")
    }

    // planStreamNext routes its raw cursor into `after` (and never `before`): the continuation request carries
    // exactly the forward cursor.
    func testPlanStreamNextSendsAfterCursor() throws {
        let (client, _) = makeClient { _ in json("{}") }
        let variables = client.routing.streamVariables(
            PlanOptions(origin: .stop("1:A"), destination: .stop("1:B")),
            targetResults: 8,
            maxWindowMinutes: 240,
            after: "c-next",
            before: nil
        )
        let actual = try streamVariablesJSON(variables)
        XCTAssertEqual(actual["after"] as? String, "c-next")
        XCTAssertNil(actual["before"])
        XCTAssertEqual(actual["targetResults"] as? Int, 8)
        XCTAssertEqual(actual["maxWindow"] as? String, "PT240M")
    }

    // planStreamPrevious routes its raw cursor into `before` (and never `after`): the continuation request
    // carries exactly the backward cursor.
    func testPlanStreamPreviousSendsBeforeCursor() throws {
        let (client, _) = makeClient { _ in json("{}") }
        let variables = client.routing.streamVariables(
            PlanOptions(origin: .stop("1:A"), destination: .stop("1:B")),
            targetResults: 5,
            maxWindowMinutes: 360,
            after: nil,
            before: "c-prev"
        )
        let actual = try streamVariablesJSON(variables)
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

    // `planStream` sends the caller's `targetResults` and `maxWindow` (both required, no SDK default) under the
    // plan-stream id, and its terminal `.done` carries the routing errors.
    func testPlanStreamSendsRequiredInputsAndEndsWithRoutingErrors() async throws {
        StubStreamProtocol.respond(status: 200, body: """
        event: chunk
        data: {"results":[]}

        event: pageInfo
        data: {"hasNextPage":false,"hasPreviousPage":false,"routingErrors":[{"code":"OUTSIDE_SERVICE_PERIOD","inputField":"DATE_TIME","description":"Outside the feed"}]}

        event: done
        data: {"resultCount":0}


        """)
        let client = SpiderClient(baseURL: "https://\(StubStreamProtocol.host)", apiKey: "k")
        let options = PlanOptions(origin: .stop("1:A"), destination: .stop("1:B"))
        let events = await collect(client.routing.planStream(options, targetResults: 3, maxWindowMinutes: 120))

        let sent = try XCTUnwrap(StubStreamProtocol.requestBody)
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: sent) as? [String: Any])
        XCTAssertEqual(body["id"] as? String, "1c7886ea99de8b6124b2363d2d935baf2b6c0a8e06144f52c596e43fccec9fb9")
        let variables = try XCTUnwrap(body["variables"] as? [String: Any])
        XCTAssertEqual(variables["maxWindow"] as? String, "PT120M")
        XCTAssertEqual(variables["targetResults"] as? Int, 3)

        // One event per SSE record, in order: the blank line between records is what separates them.
        guard events.count == 2, case .result = events[0], case .done(let done) = events[1] else {
            return XCTFail("expected result then done, got \(events)")
        }
        XCTAssertEqual(done.routingErrors.map(\.code), [.outsideServicePeriod])
    }

    // A retired persisted-query id is refused by the gateway before the stream opens; the stream ends with the
    // same `.queryRetired` failure the batch calls return.
    func testPlanStreamRetiredQueryFailsWithQueryRetired() async throws {
        StubStreamProtocol.respond(status: 410, contentType: "application/json", body: #"{"error":"query_retired","message":"persisted query is retired"}"#)
        let client = SpiderClient(baseURL: "https://\(StubStreamProtocol.host)", apiKey: "k")
        let options = PlanOptions(origin: .stop("1:A"), destination: .stop("1:B"))
        let events = await collect(client.routing.planStream(options, targetResults: 5, maxWindowMinutes: 120))

        guard events.count == 1, case .failure(let error) = events[0] else { return XCTFail("expected one failure, got \(events)") }
        XCTAssertEqual(error.code, .queryRetired)
        XCTAssertEqual(error.httpStatus, 410)
        XCTAssertTrue(error.message.contains("persisted query is retired"))
    }

    // A plan-limit refusal is the gateway's plain JSON 403, sent before the stream opens; the stream ends with the
    // same failure the batch calls return, carrying the body's message.
    func testPlanStreamPlanLimitRefusalFailsBeforeTheStream() async throws {
        let cases: [(body: String, code: SpiderErrorCode, message: String)] = [
            (#"{"error":"planning_limit_reached","message":"trip planning limit reached"}"#, .planningLimitReached, "trip planning limit reached"),
            (#"{"error":"agreement_inactive","message":"agreement is not active"}"#, .agreementInactive, "agreement is not active"),
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

    // The gateway answers a missing required variable with a 200 JSON GraphQL error before any event; it maps
    // like the batch path, to a bad request naming the field.
    func testPlanStreamJSONErrorBodyFailsAsBadRequest() async throws {
        StubStreamProtocol.respond(status: 200, contentType: "application/json", body: """
        {"data":null,"errors":[{"message":"maxWindow is required","extensions":{"code":"BAD_REQUEST","field":"maxWindow"}}]}
        """)
        let client = SpiderClient(baseURL: "https://\(StubStreamProtocol.host)", apiKey: "k")
        let options = PlanOptions(origin: .stop("1:A"), destination: .stop("1:B"))
        let events = await collect(client.routing.planStream(options, targetResults: 5, maxWindowMinutes: 120))

        guard events.count == 1, case .failure(let error) = events[0] else { return XCTFail("expected one failure, got \(events)") }
        XCTAssertEqual(error.code, .badRequest)
        XCTAssertEqual(error.field, "maxWindow")
        XCTAssertEqual(error.message, "maxWindow is required")
    }

    // A window under the 2 h platform minimum, or a via location outside its fixed limits, fails before any request.
    func testPlanStreamRejectsInputsOutsideFixedLimitsWithoutRequest() async throws {
        StubStreamProtocol.respond(status: 200, body: "")
        let client = SpiderClient(baseURL: "https://\(StubStreamProtocol.host)", apiKey: "k")
        let options = PlanOptions(origin: .stop("1:A"), destination: .stop("1:B"))
        let viaOptions = PlanOptions(origin: .stop("1:A"), destination: .stop("1:B"), via: [.passThrough(stopIds: [])])
        let cases: [(AsyncStream<PlanStreamEvent>, String)] = [
            (client.routing.planStream(options, targetResults: 5, maxWindowMinutes: 119), "maxWindow"),
            (client.routing.planStreamNext(options, targetResults: 5, maxWindowMinutes: 0, after: "c"), "maxWindow"),
            (client.routing.planStreamPrevious(options, targetResults: 5, maxWindowMinutes: -120, before: "c"), "maxWindow"),
            (client.routing.planStream(viaOptions, targetResults: 5, maxWindowMinutes: 120), "via"),
        ]
        for (stream, field) in cases {
            let events = await collect(stream)
            guard events.count == 1, case .failure(let error) = events[0] else { return XCTFail("expected one failure, got \(events)") }
            XCTAssertEqual(error.code, .badRequest)
            XCTAssertEqual(error.field, field)
            XCTAssertEqual(error.message, "\(field) is out of range")
        }
        XCTAssertNil(StubStreamProtocol.requestBody)
    }
}

// Serves one canned response to `URLSession.shared` (which `planStream` streams through) for requests to `host`,
// recording the request body, so the public stream entry points can be driven end to end.
final class StubStreamProtocol: URLProtocol {
    static let host = "stream.test"
    private static let lock = NSLock()
    private static var status = 200
    private static var contentType = "text/event-stream"
    private static var body = ""
    private static var recordedBody: Data?

    static func respond(status: Int, contentType: String = "text/event-stream", body: String) {
        lock.lock(); defer { lock.unlock() }
        self.status = status
        self.contentType = contentType
        self.body = body
        recordedBody = nil
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
