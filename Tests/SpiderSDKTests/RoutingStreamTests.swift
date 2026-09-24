import XCTest
@testable import SpiderSDK
import SpiderContract

/// Guards the SSE `plan-stream` handling: the record parser that turns `chunk`/`pageInfo`/`done`/`error`
/// events into the three `PlanStreamEvent`s (`.result` / `.done` / `.failure`, including realtime-delay
/// mapping onto legs), and the stream request's wire shape (initial + `after`/`before` continuation).
/// Mirrors the Kotlin SDK's RoutingStreamTest.
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
                  "realtimeState": "UPDATED", "realTime": true, "serviceDate": "20260715",
                  "from": { "name": "Origin", "stop": { "gtfsId": "1:A" } },
                  "to":   { "name": "Dest",   "stop": { "gtfsId": "1:B" } },
                  "route": { "shortName": "12" }, "trip": { "gtfsId": "1:T" }
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
        XCTAssertEqual(leg.serviceDate, "20260715")
        XCTAssertEqual(leg.fromGtfsId, "1:A")
        XCTAssertEqual(leg.toGtfsId, "1:B")
    }

    // The `pageInfo` frame is the terminal event: it maps to `.done(RoutePageInfo)`, carrying the continuation
    // cursors + `hasNextPage`/`hasPreviousPage` the caller reads to drive `planStreamNext`/`planStreamPrevious`.
    func testPageInfoMapsToTerminalDone() {
        let data = """
        { "startCursor": "c-prev", "endCursor": "c-next", "hasNextPage": true, "hasPreviousPage": false, "searchWindowUsed": "PT1H" }
        """
        guard case .done(let pageInfo)? = parsePlanStreamRecord(event: "pageInfo", data: data) else {
            return XCTFail("expected done")
        }
        XCTAssertEqual(pageInfo.startCursor, "c-prev")
        XCTAssertEqual(pageInfo.endCursor, "c-next")
        XCTAssertTrue(pageInfo.hasNextPage)
        XCTAssertFalse(pageInfo.hasPreviousPage)
        XCTAssertEqual(pageInfo.searchWindowUsed, "PT1H")
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
}
