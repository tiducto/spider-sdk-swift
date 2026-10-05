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
          "from":{"name":"A","stop":{"gtfsId":"S1","wheelchairBoarding":"POSSIBLE","platformCode":"3","zoneId":"P"}},
          "to":{"name":"B","stop":{"gtfsId":"S2","wheelchairBoarding":"NOT_POSSIBLE","platformCode":"B","zoneId":"0"}},
          "mode":"BUS","route":{"gtfsId":"1:R12","shortName":"12","longName":"Line 12","color":"FF0000","textColor":"FFFFFF"},"headsign":"Downtown",
          "distance":1500.0,"duration":900.0,"accessibilityScore":1.0,
          "trip":{"gtfsId":"T1","bikesAllowed":"ALLOWED"},"typicalArrivalDelay":90,"interlineWithPreviousLeg":true,
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
        // Display fields pass through raw; colours stay GTFS hex without '#'.
        XCTAssertEqual(leg.routeGtfsId, "1:R12")
        XCTAssertEqual(leg.routeColor, "FF0000")
        XCTAssertEqual(leg.routeTextColor, "FFFFFF")
        XCTAssertEqual(leg.fromPlatformCode, "3")
        XCTAssertEqual(leg.toPlatformCode, "B")
        XCTAssertEqual(leg.fromZoneId, "P")
        XCTAssertEqual(leg.toZoneId, "0")
        XCTAssertEqual(leg.typicalArrivalDelaySeconds, 90)
        XCTAssertTrue(leg.interlineWithPreviousLeg)
        XCTAssertTrue(route.pageInfo.hasNextPage)

        // Request: URL, method, headers, persisted-query body.
        let req = mock.requests[0]
        XCTAssertEqual(req.path, "/routing/plan")
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.value(forHTTPHeaderField: "apikey"), "secret-key")
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-spider-contract-version"), "1.1")
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-spider-sdk"), "swift/1.0.0")
        XCTAssertEqual(req.value(forHTTPHeaderField: "content-type"), "application/json")
        XCTAssertEqual(req.bodyJSON["id"] as? String, "70c90bd46b3c765f176dda39bbb2e714b785865d70e14f6cb6d9d72d7a77c210")
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
        XCTAssertNil(vars["reliability"]) // no reliability = plan on the timetable
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
            // 2 transfers ⇒ wire maximumTransfers = 3 (the router counts boardings = transfers + 1).
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
        XCTAssertEqual(maxTransfers, 3)
        let enabled = ((prefs["accessibility"] as! [String: Any])["wheelchair"] as! [String: Any])["enabled"] as? Bool
        XCTAssertEqual(enabled, true)
    }

    // The window is sent as given: the server, not the SDK, rejects a window outside the environment's range.
    func testPlanSendsSearchWindowUnclamped() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        _ = try await client.routing.plan(PlanOptions(origin: .stop("S1"), destination: .stop("S2"), searchWindowMinutes: 0))
        let vars = mock.requests[0].bodyJSON["variables"] as! [String: Any]
        XCTAssertEqual(vars["searchWindow"] as? String, "PT0M")
    }

    // Reliability goes out as its wire name and rides along when paging.
    func testPlanSendsReliabilityAndKeepsItWhenPaging() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        let result = try await client.routing.plan(PlanOptions(origin: .stop("S1"), destination: .stop("S2"), reliability: .verySafe))
        guard case .success(let route) = result else { return XCTFail("expected success") }
        _ = try await client.routing.planNext(route)
        for request in mock.requests {
            XCTAssertEqual((request.bodyJSON["variables"] as! [String: Any])["reliability"] as? String, "VERY_SAFE")
        }
        XCTAssertEqual(mock.requests.count, 2)
        XCTAssertEqual(Reliability.allCases.map(\.rawValue), ["STANDARD", "SAFE", "VERY_SAFE"])
    }

    // Stop ids per via location (1-10) and a visit's wait (0-24 h) are fixed platform limits, checked before sending.
    func testPlanRejectsViaOutsideFixedLimitsWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        let eleven = (1...11).map { "1:V\($0)" }
        let invalid: [ViaLocation] = [
            .passThrough(stopIds: []),
            .passThrough(stopIds: eleven),
            .visit(.stop("1:V"), minimumWaitSeconds: -1),
            .visit(.stop("1:V"), minimumWaitSeconds: 86_401),
        ]
        for via in invalid {
            let result = try await client.routing.plan(PlanOptions(origin: .stop("S1"), destination: .stop("S2"), via: [via]))
            guard case .failure(let error) = result else { return XCTFail("expected failure for \(via)") }
            XCTAssertEqual(error.code, .badRequest)
            XCTAssertEqual(error.field, "via")
            XCTAssertEqual(error.message, "via is out of range")
        }
        XCTAssertTrue(mock.requests.isEmpty)
    }

    func testPlanSendsViaAtItsFixedLimits() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        let ten = (1...10).map { "1:V\($0)" }
        let result = try await client.routing.plan(PlanOptions(
            origin: .stop("S1"), destination: .stop("S2"),
            via: [.passThrough(stopIds: ten), .visit(.stop("1:W"), minimumWaitSeconds: 86_400)]
        ))
        XCTAssertTrue(result.isSuccess)
        let via = (mock.requests[0].bodyJSON["variables"] as! [String: Any])["via"] as! [[String: Any]]
        XCTAssertEqual((via[0]["passThrough"] as! [String: Any])["stopLocationIds"] as? [String], ten)
        XCTAssertEqual((via[1]["visit"] as! [String: Any])["minimumWaitTime"] as? String, "PT86400S")
    }

    // Wire values this SDK doesn't know decode to `.unknown`; an unknown via stop is a VIA routing error.
    func testPlanMapsUnknownEnumValuesAndViaLocationNotFound() async throws {
        let body = """
        {"data":{"planConnection":{
          "edges":[{"cursor":"c1","node":{"duration":60,"numberOfTransfers":0,"legs":[{
            "start":{"scheduledTime":"2026-08-21T10:00:00Z"},"end":{"scheduledTime":"2026-08-21T10:01:00Z"},
            "from":{"name":"A"},"to":{"name":"B"},"mode":"HOVERCRAFT","realtimeState":"TELEPORTED"
          }]}}],
          "pageInfo":{"hasNextPage":false,"hasPreviousPage":false},
          "routingErrors":[
            {"code":"LOCATION_NOT_FOUND","inputField":"VIA","description":"Via stop not found"},
            {"code":"SOMETHING_NEW","inputField":"SOMEWHERE_NEW","description":"New"}
          ]
        }}}
        """
        let (client, _) = makeClient { _ in json(body) }
        guard case .success(let route) = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B"))) else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(route.routingErrors.map(\.code), [.locationNotFound, .unknown])
        XCTAssertEqual(route.routingErrors.map(\.inputField), [.via, .unknown])
        let leg = route.edges[0].itinerary.legs[0]
        XCTAssertEqual(leg.mode, .unknown)
        XCTAssertEqual(leg.realtimeState, .unknown)
        // A leg with no route or stops (a walk) has no display fields, no typical delay and no interline.
        XCTAssertNil(leg.typicalArrivalDelaySeconds)
        XCTAssertFalse(leg.interlineWithPreviousLeg)
        XCTAssertNil(leg.routeGtfsId)
        XCTAssertNil(leg.routeColor)
        XCTAssertNil(leg.routeTextColor)
        XCTAssertNil(leg.fromPlatformCode)
        XCTAssertNil(leg.toPlatformCode)
        XCTAssertNil(leg.fromZoneId)
        XCTAssertNil(leg.toZoneId)
    }

    // A non-2xx routing answer whose message has the fixed `<field> is …` shape names that field.
    func testRouting400IsBadRequestWithField() async throws {
        let (client, _) = makeClient { _ in json(#"{"message":"searchWindow is out of range"}"#, status: 400) }
        let result = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B")))
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .badRequest)
        XCTAssertEqual(error.httpStatus, 400)
        XCTAssertEqual(error.field, "searchWindow")
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

    func testTopLevelBadRequestBecomesBadRequestWithFieldAndMessage() async throws {
        let body = """
        {"data":null,"errors":[{"message":"searchWindow exceeds the maximum of PT2H",\
        "extensions":{"code":"BAD_REQUEST","field":"searchWindow"}}]}
        """
        let (client, _) = makeClient { _ in json(body) }
        let result = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B")))
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .badRequest)
        XCTAssertEqual(error.code.rawValue, "bad_request")
        XCTAssertEqual(error.field, "searchWindow")
        XCTAssertEqual(error.message, "searchWindow exceeds the maximum of PT2H")
    }

    // The contract-version response header is informational: a gateway declaring another major still answers.
    func testOtherContractMajorOnResponseIsIgnored() async throws {
        let (client, _) = makeClient { _ in json(self.planBody, contractVersion: "4.0") }
        let result = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B")))
        guard case .success(let route) = result else { return XCTFail("expected success") }
        XCTAssertEqual(route.edges.count, 1)
    }

    // The gateway's 410 for a retired query id is its own error, stating the query's state.
    func testRetiredQueryMapsToQueryRetired() async throws {
        let body = #"{"error":"query_retired","message":"persisted query is retired"}"#
        let (client, _) = makeClient { _ in json(body, status: 410) }
        let result = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B")))
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .queryRetired)
        XCTAssertEqual(error.code.rawValue, "query_retired")
        XCTAssertEqual(error.httpStatus, 410)
        XCTAssertEqual(error.serverCode, "query_retired")
        XCTAssertTrue(error.message.contains("persisted query is retired"))
        for action in ["update", "upgrade", "retry"] {
            XCTAssertFalse(error.message.lowercased().contains(action))
        }
    }

    func testBare410IsQueryRetired() async throws {
        let (client, _) = makeClient { _ in json("", status: 410) }
        let result = try await client.routing.departures("S")
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .queryRetired)
        XCTAssertTrue(error.message.contains("persisted query is retired"))
    }

    // An id the gateway never had stays an unauthorized 403, carrying the gateway's own message.
    func testUnknownPersistedQueryIdStaysUnauthorized() async throws {
        let body = #"{"error":"persisted_query_rejected","message":"unknown persisted-query id: abc"}"#
        let (client, _) = makeClient { _ in json(body, status: 403) }
        let result = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B")))
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .unauthorized)
        XCTAssertEqual(error.httpStatus, 403)
        XCTAssertEqual(error.serverCode, "persisted_query_rejected")
        XCTAssertTrue(error.message.contains("unknown persisted-query id"))
        XCTAssertFalse(error.message.lowercased().contains("update"))
    }

    // A 403 without the gateway's persisted-query marker (a key not accepted here) keeps the plain key message.
    func testOtherForbiddenStaysAKeyProblem() async throws {
        let (client, _) = makeClient { _ in json(#"{"error":"Access to this API has been disallowed"}"#, status: 403) }
        let result = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B")))
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .unauthorized)
        XCTAssertNil(error.serverCode)
        XCTAssertFalse(error.message.contains("update the SDK"))
    }

    // Every boardable row is kept, including one whose headsign matches the stop name (the router, not the SDK,
    // drops a trip's arrival-only terminus).
    func testDeparturesMapsEveryRowWithServiceDate() async throws {
        let body = """
        {"data":{"asStop":{"gtfsId":"S","name":"Main Square","wheelchairBoarding":"POSSIBLE","stoptimesWithoutPatterns":[
          {"serviceDay":1700000000,"scheduledDeparture":36000,"realtimeDeparture":36060,"realtime":true,"realtimeState":"UPDATED","typicalDelay":45,"headsign":"Airport","stop":{"gtfsId":"S:P2","platformCode":"2"},"trip":{"gtfsId":"T1","bikesAllowed":"ALLOWED","wheelchairAccessible":"POSSIBLE","route":{"gtfsId":"1:R12","shortName":"12","longName":"Line 12","mode":"BUS","color":"00A0E0","textColor":"000000"}}},
          {"serviceDay":1700000000,"scheduledDeparture":36300,"realtime":false,"headsign":"main square","trip":{"gtfsId":"T2","wheelchairAccessible":"NO_INFORMATION","route":{"gtfsId":"1:R5","shortName":"5","mode":"TRAM"}}}
        ]}}}
        """
        let (client, mock) = makeClient { _ in json(body) }
        let result = try await client.routing.departures("S", numberOfDepartures: 10)
        guard case .success(let departures) = result else { return XCTFail("expected success") }
        XCTAssertEqual(departures.map(\.tripGtfsId), ["T1", "T2"])
        let d = departures[0]
        XCTAssertEqual(d.serviceDate, "2023-11-15")
        XCTAssertEqual(d.scheduledTimeEpochMs, (1_700_000_000 + 36_000) * 1000)
        XCTAssertEqual(d.realtimeTimeEpochMs, (1_700_000_000 + 36_060) * 1000)
        XCTAssertEqual(d.mode, .bus)
        XCTAssertEqual(d.realtimeState, .updated)
        XCTAssertTrue(d.isRealtime)
        XCTAssertEqual(d.typicalDelaySeconds, 45)
        XCTAssertEqual(d.routeGtfsId, "1:R12")
        XCTAssertEqual(d.routeColor, "00A0E0")
        XCTAssertEqual(d.routeTextColor, "000000")
        XCTAssertEqual(d.stopGtfsId, "S:P2")
        XCTAssertEqual(d.platformCode, "2")
        XCTAssertEqual(d.wheelchairAccessible, .possible)
        // Absent display fields stay nil; NO_INFORMATION is nil.
        let bare = departures[1]
        XCTAssertEqual(bare.routeGtfsId, "1:R5")
        XCTAssertNil(bare.routeColor)
        XCTAssertNil(bare.routeTextColor)
        XCTAssertNil(bare.stopGtfsId)
        XCTAssertNil(bare.platformCode)
        XCTAssertNil(bare.wheelchairAccessible)
        XCTAssertNil(bare.typicalDelaySeconds)
        let vars = mock.requests[0].bodyJSON["variables"] as! [String: Any]
        XCTAssertEqual(vars["numberOfDepartures"] as? Int, 10)
    }

    // Both limited inputs are required on the wire, so the SDK always sends them: 30 departures within 24 h.
    func testDeparturesAlwaysSendsCountAndTimeRange() async throws {
        let (client, mock) = makeClient { _ in json(#"{"data":{"asStop":{"gtfsId":"S","name":"S","stoptimesWithoutPatterns":[]}}}"#) }
        _ = try await client.routing.departures("S")
        let body = mock.requests[0].bodyJSON
        XCTAssertEqual(body["id"] as? String, "5ca190e60b81d09b60da95ed3b92377ee1a73cdf5236383bb883a1b230cf6811")
        let vars = body["variables"] as! [String: Any]
        XCTAssertEqual(vars["numberOfDepartures"] as? Int, 30)
        XCTAssertEqual(vars["timeRange"] as? Int, 86_400)
        XCTAssertNil(vars["startTime"])

        _ = try await client.routing.departures("S", timeRangeSeconds: 1)
        XCTAssertEqual((mock.requests[1].bodyJSON["variables"] as! [String: Any])["timeRange"] as? Int, 1)
    }

    func testDeparturesRejectsTimeRangeOutOfRangeWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json("{}") }
        for bad in [0, -60, 86_401] {
            let result = try await client.routing.departures("S", timeRangeSeconds: bad)
            guard case .failure(let error) = result else { return XCTFail("expected failure for \(bad)") }
            XCTAssertEqual(error.code, .badRequest)
            XCTAssertEqual(error.field, "timeRange")
            XCTAssertEqual(error.message, "timeRange is out of range")
        }
        XCTAssertTrue(mock.requests.isEmpty)
    }

    // A night departure past midnight belongs to the previous service date: serviceDay is 2026-09-28's
    // noon-minus-12h in Europe/Prague (22:00Z on the 27th), and 24:40 is 00:40 on the 29th local time.
    func testNightDepartureKeepsItsServiceDate() async throws {
        let body = """
        {"data":{"asStop":{"gtfsId":"S","name":"S","stoptimesWithoutPatterns":[
          {"serviceDay":1790546400,"scheduledDeparture":88800,"headsign":"Depot","trip":{"gtfsId":"N1","route":{"gtfsId":"1:N90","shortName":"N90","mode":"BUS"}}}
        ]}}}
        """
        let (client, _) = makeClient { _ in json(body) }
        guard case .success(let departures) = try await client.routing.departures("S") else { return XCTFail("expected success") }
        XCTAssertEqual(departures[0].serviceDate, "2026-09-28")
    }

    func testTripRejectsMalformedServiceDateWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json("{}") }
        for bad in ["20260921", "2026-09-31", "21-09-2026", "2026-09-21T00:00:00Z"] {
            let result = try await client.routing.trip("T1", serviceDate: bad)
            guard case .failure(let error) = result else { return XCTFail("expected failure for \(bad)") }
            XCTAssertEqual(error.code, .badRequest)
            XCTAssertEqual(error.field, "serviceDate")
            XCTAssertEqual(error.message, "serviceDate is invalid")
        }
        XCTAssertTrue(mock.requests.isEmpty)
    }

    func testTripMapsStopsGeometryAndEnums() async throws {
        let body = """
        {"data":{"trip":{"gtfsId":"T1","directionId":"0","tripHeadsign":"Airport","bikesAllowed":"NOT_ALLOWED","wheelchairAccessible":"NOT_POSSIBLE","route":{"gtfsId":"1:R12","shortName":"12","longName":"Line 12","mode":"BUS","color":"FF0000","textColor":"FFFFFF"},"stoptimesForDate":[
          {"serviceDay":1700000000,"scheduledArrival":36000,"scheduledDeparture":36030,"realtimeArrival":36050,"realtimeDeparture":36080,"realtime":true,"typicalDelay":30,"stop":{"gtfsId":"S1","name":"A","lat":49.19,"lon":16.61,"wheelchairBoarding":"POSSIBLE","platformCode":"1","zoneId":"P"}},
          {"serviceDay":1700000000,"scheduledArrival":36600,"typicalDelay":null,"stop":{"gtfsId":"S2","name":"B"}}
        ],"tripGeometry":{"points":"_p~iF~ps|U","length":2}}}}
        """
        let (client, mock) = makeClient { _ in json(body) }
        let result = try await client.routing.trip("T1", serviceDate: "2026-08-21")
        guard case .success(let trip) = result else { return XCTFail("expected success") }
        XCTAssertEqual(mock.requests[0].bodyJSON["id"] as? String, "dc29ebef5bfcbe8c921e4381bfe0a4b9d869cd011fdade6c155f1a21bd3e5c33")
        XCTAssertEqual(trip.mode, .bus)
        XCTAssertEqual(trip.bikesAllowed, .notAllowed)
        XCTAssertEqual(trip.serviceDate, "2023-11-15")
        XCTAssertEqual(trip.routeGtfsId, "1:R12")
        XCTAssertEqual(trip.routeColor, "FF0000")
        XCTAssertEqual(trip.routeTextColor, "FFFFFF")
        XCTAssertEqual(trip.wheelchairAccessible, .notPossible)
        XCTAssertEqual(trip.stops.count, 2)
        XCTAssertEqual(trip.stops[0].scheduledArrivalEpochMs, (1_700_000_000 + 36_000) * 1000)
        XCTAssertEqual(trip.stops[0].wheelchairBoarding, .possible)
        XCTAssertEqual(trip.stops[0].platformCode, "1")
        XCTAssertEqual(trip.stops[0].zoneId, "P")
        XCTAssertEqual(trip.stops[0].typicalDelaySeconds, 30)
        XCTAssertNil(trip.stops[1].typicalDelaySeconds)
        XCTAssertNil(trip.stops[1].platformCode)
        XCTAssertNil(trip.stops[1].zoneId)
        XCTAssertNil(trip.stops[1].wheelchairBoarding)
        XCTAssertEqual(trip.geometry.count, 1)
    }
}
