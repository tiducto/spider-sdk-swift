import XCTest
@testable import SpiderSDK
import SpiderContract

/// Guards the SSE `plan-stream` handling: the record parser that turns `chunk`/`pageInfo`/`done`/`error`
/// events into `PlanStreamEvent`s (including realtime-delay mapping onto legs), and the stream request's wire
/// shape. Mirrors the Kotlin SDK's RoutingStreamTest.
final class RoutingStreamTests: XCTestCase {
    // A `chunk` carries itinerary nodes; realtime delays ride on each leg's estimated{time,delay} +
    // realtimeState + realTime and must land on the domain Leg exactly as the batch plan maps them.
    func testChunkMapsItinerariesWithRealtimeDelays() {
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
        guard case .chunk(let frontierSeconds, let found, let finalized, let itineraries)? = parsePlanStreamRecord(event: "chunk", data: data) else {
            return XCTFail("expected chunk")
        }
        XCTAssertEqual(frontierSeconds, 1800)
        XCTAssertEqual(found, 3)
        XCTAssertEqual(finalized, 1)

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

    func testPageInfoMapsToContinuationCursors() {
        let data = """
        { "startCursor": "c-prev", "endCursor": "c-next", "hasNextPage": true, "hasPreviousPage": false, "searchWindowUsed": "PT1H" }
        """
        guard case .page(let pageInfo)? = parsePlanStreamRecord(event: "pageInfo", data: data) else {
            return XCTFail("expected page")
        }
        XCTAssertEqual(pageInfo.startCursor, "c-prev")
        XCTAssertEqual(pageInfo.endCursor, "c-next")
        XCTAssertTrue(pageInfo.hasNextPage)
        XCTAssertFalse(pageInfo.hasPreviousPage)
        XCTAssertEqual(pageInfo.searchWindowUsed, "PT1H")
    }

    func testDoneMapsToTerminalSummary() {
        let data = """
        { "iterations": 3, "windowSeconds": 3600, "resultCount": 5, "stoppedBy": "targetResults" }
        """
        guard case .done(let iterations, let windowSeconds, let resultCount, let stoppedBy)? = parsePlanStreamRecord(event: "done", data: data) else {
            return XCTFail("expected done")
        }
        XCTAssertEqual(iterations, 3)
        XCTAssertEqual(windowSeconds, 3600)
        XCTAssertEqual(resultCount, 5)
        XCTAssertEqual(stoppedBy, "targetResults")
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

    // Pins the stream request wire shape (targetResults/maxWindow + via) so a contract regen can't silently
    // rename or reorder the fields the SDK sends to /routing/plan-stream.
    func testStreamVariablesSerializeToPlanStreamWireShape() throws {
        let variables = PlanConnectionStreamVariables(
            dateTime: PlanDateTimeInput(earliestDeparture: "2026-07-15T08:00:00Z"),
            origin: PlanLabeledLocationInput(
                location: PlanLocationInput(stopLocation: PlanStopLocationInput(stopLocationId: "1:A"))
            ),
            destination: PlanLabeledLocationInput(
                location: PlanLocationInput(coordinate: PlanCoordinateInput(latitude: 49.2, longitude: 16.6))
            ),
            via: [PlanViaLocationInput(passThrough: PlanPassThroughViaLocationInput(stopLocationIds: ["1:V"]))],
            targetResults: 5,
            maxWindow: "PT3H"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let actual = try JSONSerialization.jsonObject(with: encoder.encode(variables)) as! [String: Any]

        // Field presence + omission (nil optionals must not appear): the wire body carries exactly these keys.
        XCTAssertEqual(Set(actual.keys), ["dateTime", "origin", "destination", "via", "targetResults", "maxWindow"])
        XCTAssertEqual(actual["targetResults"] as? Int, 5)
        XCTAssertEqual(actual["maxWindow"] as? String, "PT3H")
        XCTAssertNil(actual["modes"])
        XCTAssertNil(actual["preferences"])
        XCTAssertNil(actual["before"])
        XCTAssertNil(actual["after"])
        let dateTime = actual["dateTime"] as! [String: Any]
        XCTAssertEqual(dateTime["earliestDeparture"] as? String, "2026-07-15T08:00:00Z")
        let origin = ((actual["origin"] as! [String: Any])["location"] as! [String: Any])["stopLocation"] as! [String: Any]
        XCTAssertEqual(origin["stopLocationId"] as? String, "1:A")
        let via = actual["via"] as! [[String: Any]]
        let stopIds = (via[0]["passThrough"] as! [String: Any])["stopLocationIds"] as! [String]
        XCTAssertEqual(stopIds, ["1:V"])
    }
}
