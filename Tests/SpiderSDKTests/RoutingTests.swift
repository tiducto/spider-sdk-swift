import XCTest
@testable import SpiderSDK

final class RoutingTests: XCTestCase {
    private let planBody = """
    {"data":{"planConnection":{
      "edges":[{"cursor":"c1","node":{
        "start":"2026-08-21T10:00:00Z","end":"2026-08-21T10:30:00Z","duration":1800,"waitingTime":120,"numberOfTransfers":1,"accessibilityScore":0.9,
        "legs":[{
          "start":{"scheduledTime":"2026-08-21T10:00:00Z"},
          "end":{"scheduledTime":"2026-08-21T10:15:00Z"},
          "from":{"name":"A","stop":{"gtfsId":"S1","wheelchairBoarding":"POSSIBLE"}},
          "to":{"name":"B","stop":{"gtfsId":"S2","wheelchairBoarding":"NOT_POSSIBLE"}},
          "mode":"BUS","route":{"shortName":"12","longName":"Line 12"},"headsign":"Downtown",
          "distance":1500.0,"duration":900.0,"accessibilityScore":1.0,
          "trip":{"gtfsId":"T1","bikesAllowed":"ALLOWED"},
          "legGeometry":{"points":"_p~iF~ps|U_ulLnnqC_mqNvxq`@"}
        }]
      }}],
      "pageInfo":{"hasNextPage":true,"hasPreviousPage":false,"startCursor":"c1","endCursor":"c1","searchWindowUsed":"PT60M"},
      "routingErrors":[],"searchDateTime":"2026-08-21T10:00:00Z"
    }}}
    """

    func testPlanPostsPersistedQueryWithHeadersAndMapsRoute() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        let result = try await client.routing.plan(PlanOptions(
            origin: .coordinate(49.19, 16.61),
            destination: .coordinate(49.22, 16.52)
        ))
        guard case .success(let route) = result else { return XCTFail("expected success") }

        // Mapped route.
        XCTAssertEqual(route.edges.count, 1)
        XCTAssertEqual(route.edges[0].cursor, "c1")
        let leg = route.edges[0].itinerary.legs[0]
        XCTAssertEqual(leg.mode, .bus)
        XCTAssertEqual(leg.routeShortName, "12")
        XCTAssertEqual(leg.fromWheelchair, .possible)
        XCTAssertEqual(leg.toWheelchair, .notPossible)
        XCTAssertEqual(leg.bikesAllowed, .allowed)
        XCTAssertEqual(leg.geometry.count, 3) // decoded polyline
        XCTAssertTrue(route.pageInfo.hasNextPage)

        // Request: URL, method, headers, persisted-query body.
        let req = mock.requests[0]
        XCTAssertEqual(req.path, "/routing/plan")
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.value(forHTTPHeaderField: "apikey"), "secret-key")
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-spider-contract-version"), "0.1")
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-spider-sdk"), "swift/0.1.0")
        XCTAssertEqual(req.value(forHTTPHeaderField: "content-type"), "application/json")
        XCTAssertEqual(req.bodyJSON["id"] as? String, "dad4f190af803a8cb50ec99c5852544297e94db8edc0d94220c8f79d98f065a7")
        let vars = req.bodyJSON["variables"] as! [String: Any]
        XCTAssertNil(vars["first"])
        XCTAssertNil(vars["last"])
        XCTAssertEqual(vars["searchWindow"] as? String, "PT60M")
        let dateTime = vars["dateTime"] as! [String: Any]
        XCTAssertNotNil(dateTime["earliestDeparture"])
        XCTAssertNil(dateTime["latestArrival"])
        let origin = ((vars["origin"] as! [String: Any])["location"] as! [String: Any])["coordinate"] as! [String: Any]
        XCTAssertEqual(origin["latitude"] as? Double, 49.19)
    }

    func testPlanNoFiltersOmitsModesAndPreferences() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        _ = try await client.routing.plan(PlanOptions(origin: .stop("S1"), destination: .stop("S2")))
        let vars = mock.requests[0].bodyJSON["variables"] as! [String: Any]
        // Null-omission: nil optionals must not appear as keys (matches the "omit nulls" wire convention).
        XCTAssertNil(vars["modes"])
        XCTAssertNil(vars["preferences"])
        XCTAssertNil(vars["via"])
        XCTAssertNil(vars["last"])
        XCTAssertNil(vars["after"])
        XCTAssertEqual(vars["searchWindow"] as? String, "PT60M")
        // stop origin -> stopLocation input
        let loc = (vars["origin"] as! [String: Any])["location"] as! [String: Any]
        XCTAssertEqual((loc["stopLocation"] as! [String: Any])["stopLocationId"] as? String, "S1")
    }

    func testPlanMapsModesTransfersWheelchairAndWindow() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        _ = try await client.routing.plan(PlanOptions(
            origin: .coordinate(49.19, 16.61),
            destination: .coordinate(49.22, 16.52),
            allowedTransitModes: [.bus, .walk, .tram], // WALK dropped (not a wire transit mode)
            maxTransfers: 2,
            searchWindowMinutes: 30,
            wheelchairAccessible: true
        ))
        let vars = mock.requests[0].bodyJSON["variables"] as! [String: Any]
        XCTAssertEqual(vars["searchWindow"] as? String, "PT30M")
        let transit = ((vars["modes"] as! [String: Any])["transit"] as! [String: Any])["transit"] as! [[String: Any]]
        XCTAssertEqual(transit.map { $0["mode"] as? String }, ["BUS", "TRAM"])
        let prefs = vars["preferences"] as! [String: Any]
        let maxTransfers = ((prefs["transit"] as! [String: Any])["transfer"] as! [String: Any])["maximumTransfers"] as? Int
        XCTAssertEqual(maxTransfers, 2)
        let enabled = ((prefs["accessibility"] as! [String: Any])["wheelchair"] as! [String: Any])["enabled"] as? Bool
        XCTAssertEqual(enabled, true)
    }

    func testPlanArriveBySetsLatestArrival() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        _ = try await client.routing.plan(PlanOptions(
            origin: .stop("S1"), destination: .stop("S2"),
            arriveBy: Date(timeIntervalSince1970: 1_700_000_000)
        ))
        let dateTime = (mock.requests[0].bodyJSON["variables"] as! [String: Any])["dateTime"] as! [String: Any]
        XCTAssertNotNil(dateTime["latestArrival"])
        XCTAssertNil(dateTime["earliestDeparture"])
    }

    func testPlanNextPagesForwardWithAfter() async throws {
        let page2 = """
        {"data":{"planConnection":{"edges":[],"pageInfo":{"hasNextPage":false,"hasPreviousPage":true,"startCursor":"c2","endCursor":"c2","searchWindowUsed":"PT60M"},"routingErrors":[],"searchDateTime":null}}}
        """
        let (client, mock) = makeClient { req in
            let vars = req.bodyJSON["variables"] as? [String: Any] ?? [:]
            return json(vars["after"] as? String == "c1" ? page2 : self.planBody)
        }
        guard case .success(let first) = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B"))) else {
            return XCTFail("expected success")
        }
        let next = try await client.routing.planNext(first)
        XCTAssertNotNil(next)
        let vars = mock.requests[1].bodyJSON["variables"] as! [String: Any]
        XCTAssertEqual(vars["after"] as? String, "c1")
        XCTAssertNil(vars["first"])
        XCTAssertNil(vars["before"])
        XCTAssertNil(vars["last"])
    }

    func testHttpErrorBecomesFailureWithMappedCode() async throws {
        let (client, _) = makeClient { _ in json("{\"code\":\"boom\",\"message\":\"nope\"}", status: 503) }
        let result = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B")))
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .server)
        XCTAssertEqual(error.httpStatus, 503)
        XCTAssertEqual(error.serverCode, "boom")
    }

    func testUpstreamGraphQLErrorsBecomeFailure() async throws {
        let (client, _) = makeClient { _ in json("{\"errors\":[{\"message\":\"bad var\"}]}") }
        let result = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B")))
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .server)
        XCTAssertTrue(error.message.contains("bad var"))
    }

    func testContractMismatchThrowsInsteadOfReturning() async throws {
        let (client, _) = makeClient { _ in json(self.planBody, contractVersion: "4.0") }
        do {
            _ = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B")))
            XCTFail("expected throw")
        } catch let error as SpiderContractMismatchError {
            XCTAssertEqual(error.expected, "0.1")
            XCTAssertEqual(error.actual, "4.0")
        }
    }

    func testDeparturesMapsAndDropsSiblingTerminatingTrips() async throws {
        let body = """
        {"data":{"asStop":{"gtfsId":"S","name":"Main Square","wheelchairBoarding":"POSSIBLE","stoptimesWithoutPatterns":[
          {"serviceDay":1700000000,"scheduledDeparture":36000,"realtimeDeparture":36060,"realtime":true,"realtimeState":"UPDATED","headsign":"Airport","trip":{"gtfsId":"T1","bikesAllowed":"ALLOWED","route":{"shortName":"12","longName":"Line 12","mode":"BUS"}}},
          {"serviceDay":1700000000,"scheduledDeparture":36300,"realtime":false,"headsign":"main square","trip":{"gtfsId":"T2","route":{"shortName":"5","mode":"TRAM"}}}
        ]}}}
        """
        let (client, mock) = makeClient { _ in json(body) }
        let result = try await client.routing.departures("S", numberOfDepartures: 10)
        guard case .success(let departures) = result else { return XCTFail("expected success") }
        XCTAssertEqual(departures.count, 1) // second dropped: headsign == stop name (case-insensitive)
        let d = departures[0]
        XCTAssertEqual(d.scheduledTimeEpochMs, (1_700_000_000 + 36_000) * 1000)
        XCTAssertEqual(d.realtimeTimeEpochMs, (1_700_000_000 + 36_060) * 1000)
        XCTAssertEqual(d.mode, .bus)
        XCTAssertEqual(d.realtimeState, .updated)
        XCTAssertTrue(d.isRealtime)
        let vars = mock.requests[0].bodyJSON["variables"] as! [String: Any]
        XCTAssertEqual(vars["numberOfDepartures"] as? Int, 10)
    }

    func testTripMapsStopsGeometryAndEnums() async throws {
        let body = """
        {"data":{"trip":{"gtfsId":"T1","directionId":"0","tripHeadsign":"Airport","bikesAllowed":"NOT_ALLOWED","route":{"shortName":"12","longName":"Line 12","mode":"BUS"},"stoptimesForDate":[
          {"serviceDay":1700000000,"scheduledArrival":36000,"scheduledDeparture":36030,"realtimeArrival":36050,"realtimeDeparture":36080,"realtime":true,"stop":{"gtfsId":"S1","name":"A","lat":49.19,"lon":16.61,"wheelchairBoarding":"POSSIBLE"}}
        ],"tripGeometry":{"points":"_p~iF~ps|U","length":2}}}}
        """
        let (client, _) = makeClient { _ in json(body) }
        let result = try await client.routing.trip("T1", serviceDate: "2026-08-21")
        guard case .success(let trip) = result else { return XCTFail("expected success") }
        XCTAssertEqual(trip.mode, .bus)
        XCTAssertEqual(trip.bikesAllowed, .notAllowed)
        XCTAssertEqual(trip.stops.count, 1)
        XCTAssertEqual(trip.stops[0].scheduledArrivalEpochMs, (1_700_000_000 + 36_000) * 1000)
        XCTAssertEqual(trip.stops[0].wheelchairBoarding, .possible)
        XCTAssertEqual(trip.geometry.count, 1)
    }
}
