import XCTest
@testable import SpiderSDK

final class RoutingTests: XCTestCase {
    private let planBody = """
    {
      "itineraries":[{
        "start":"2026-08-21T10:00:00Z","end":"2026-08-21T10:30:00Z","duration":1800,"waitingTime":120,"numberOfTransfers":1,
        "legs":[{
          "start":{"scheduledTime":"2026-08-21T10:00:00Z"},
          "end":{"scheduledTime":"2026-08-21T10:15:00Z"},
          "from":{"name":"A","stop":{"gtfsId":"S1","wheelchairBoarding":"POSSIBLE","platformCode":"3","zoneId":"P"}},
          "to":{"name":"B","stop":{"gtfsId":"S2","wheelchairBoarding":"NOT_POSSIBLE","platformCode":"B","zoneId":"0"}},
          "mode":"BUS","route":{"gtfsId":"1:R12","shortName":"12","longName":"Line 12","color":"FF0000","textColor":"FFFFFF"},"headsign":"Downtown",
          "distance":1500.0,"duration":900.0,
          "trip":{"gtfsId":"T1","bikesAllowed":"ALLOWED"},"typicalArrivalDelay":90,"interlineWithPreviousLeg":true,
          "legGeometry":{"points":"_p~iF~ps|U_ulLnnqC_mqNvxq`@"}
        }]
      }],
      "pageInfo":{"hasNextPage":true,"hasPreviousPage":true,"startCursor":"c0","endCursor":"c1","searchWindowUsed":"PT60M"},
      "routingErrors":[],"searchDateTime":"2026-08-21T10:00:00Z"
    }
    """

    func testPlanPostsRestBodyWithHeadersAndMapsRoute() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        let result = try await client.routing.plan(PlanOptions(
            origin: .coordinate(49.19, 16.61),
            destination: .coordinate(49.22, 16.52)
        ))
        guard case .success(let route) = result else { return XCTFail("expected success") }

        // Mapped route: one edge per itinerary.
        XCTAssertEqual(route.edges.count, 1)
        let itinerary = route.edges[0].itinerary
        XCTAssertEqual(itinerary.durationSeconds, 1800)
        XCTAssertEqual(itinerary.waitingTimeSeconds, 120)
        XCTAssertEqual(itinerary.numberOfTransfers, 1)
        let leg = itinerary.legs[0]
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
        XCTAssertEqual(route.pageInfo, RoutePageInfo(startCursor: "c0", endCursor: "c1", hasNextPage: true, hasPreviousPage: true, searchWindowUsed: "PT60M"))
        XCTAssertEqual(route.searchDateTime, "2026-08-21T10:00:00Z")

        // Request: URL, method, headers, and the bare REST body.
        let req = mock.requests[0]
        XCTAssertEqual(req.path, "/routing/v1/plan")
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.value(forHTTPHeaderField: "apikey"), "secret-key")
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-spider-contract-version"), "1.2")
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-spider-sdk"), "swift/2.0.0")
        XCTAssertEqual(req.value(forHTTPHeaderField: "content-type"), "application/json")
        let body = req.bodyJSON
        XCTAssertNil(body["id"])
        XCTAssertNil(body["variables"])
        XCTAssertNil(body["first"])
        XCTAssertNil(body["last"])
        XCTAssertEqual(body["searchWindow"] as? String, "PT60M")
        let dateTime = body["dateTime"] as! [String: Any]
        XCTAssertNotNil(dateTime["earliestDeparture"])
        XCTAssertNil(dateTime["latestArrival"])
        let origin = ((body["origin"] as! [String: Any])["location"] as! [String: Any])["coordinate"] as! [String: Any]
        XCTAssertEqual(origin["latitude"] as? Double, 49.19)
    }

    // Pins the whole plan body for a request that sets every option the SDK maps, so a regen can't silently
    // rename, nest or drop a member.
    func testPlanBodyIsThePinnedRestShape() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        _ = try await client.routing.plan(PlanOptions(
            origin: .coordinate(49.1908, 16.6128),
            destination: .stop("1:U1376"),
            departAt: Date(timeIntervalSince1970: 1_791_612_000),
            via: [.visit(.stop("1:U1234"), minimumWaitSeconds: 300), .passThrough("1:V1", "1:V2")],
            allowedTransitModes: [.bus, .tram],
            maxTransfers: 3,
            searchWindowMinutes: 120,
            wheelchairAccessible: true,
            reliability: .safe
        ))
        let expected: [String: Any] = [
            "dateTime": ["earliestDeparture": "2026-10-10T06:00:00Z"],
            "origin": ["location": ["coordinate": ["latitude": 49.1908, "longitude": 16.6128]]],
            "destination": ["location": ["stopLocation": ["stopLocationId": "1:U1376"]]],
            "via": [
                ["visit": ["stopLocationIds": ["1:U1234"], "minimumWaitTime": "PT300S"]],
                ["passThrough": ["stopLocationIds": ["1:V1", "1:V2"]]],
            ],
            "modes": ["transit": ["transit": [["mode": "BUS"], ["mode": "TRAM"]]]],
            "preferences": [
                "transit": ["transfer": ["maximumTransfers": 4]],
                "accessibility": ["wheelchair": ["enabled": true]],
            ],
            "searchWindow": "PT120M",
            "reliability": "SAFE",
        ]
        XCTAssertEqual(mock.requests[0].bodyJSON as NSDictionary, expected as NSDictionary)
    }

    @available(*, deprecated, message: "Pins the deprecated fields.")
    func testDeprecatedFieldsKeepTheirFixedValues() async throws {
        let (client, _) = makeClient { _ in json(self.planBody) }
        guard case .success(let route) = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B"))) else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(route.edges.map(\.cursor), ["NoCursor"])
        XCTAssertNil(route.edges[0].itinerary.accessibilityScore)
        XCTAssertNil(route.edges[0].itinerary.legs[0].accessibilityScore)
    }

    func testPlanNoFiltersOmitsModesAndPreferences() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        _ = try await client.routing.plan(PlanOptions(origin: .stop("S1"), destination: .stop("S2")))
        let body = mock.requests[0].bodyJSON
        // Null-omission: nil optionals must not appear as keys (matches the "omit nulls" wire convention).
        XCTAssertNil(body["modes"])
        XCTAssertNil(body["preferences"])
        XCTAssertNil(body["via"])
        XCTAssertNil(body["reliability"]) // no reliability = plan on the timetable
        XCTAssertNil(body["before"])
        XCTAssertNil(body["after"])
        XCTAssertEqual(body["searchWindow"] as? String, "PT60M")
        // stop origin -> stopLocation input
        let loc = (body["origin"] as! [String: Any])["location"] as! [String: Any]
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
        let body = mock.requests[0].bodyJSON
        XCTAssertEqual(body["searchWindow"] as? String, "PT30M")
        let transit = ((body["modes"] as! [String: Any])["transit"] as! [String: Any])["transit"] as! [[String: Any]]
        XCTAssertEqual(transit.map { $0["mode"] as? String }, ["BUS", "TRAM"])
        let prefs = body["preferences"] as! [String: Any]
        let maxTransfers = ((prefs["transit"] as! [String: Any])["transfer"] as! [String: Any])["maximumTransfers"] as? Int
        XCTAssertEqual(maxTransfers, 3)
        let enabled = ((prefs["accessibility"] as! [String: Any])["wheelchair"] as! [String: Any])["enabled"] as? Bool
        XCTAssertEqual(enabled, true)
    }

    // The window is sent as given: the server, not the SDK, rejects a window outside the environment's range.
    func testPlanSendsSearchWindowUnclamped() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        _ = try await client.routing.plan(PlanOptions(origin: .stop("S1"), destination: .stop("S2"), searchWindowMinutes: 0))
        XCTAssertEqual(mock.requests[0].bodyJSON["searchWindow"] as? String, "PT0M")
    }

    // Reliability goes out as its wire name and rides along when paging.
    func testPlanSendsReliabilityAndKeepsItWhenPaging() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        let result = try await client.routing.plan(PlanOptions(origin: .stop("S1"), destination: .stop("S2"), reliability: .verySafe))
        guard case .success(let route) = result else { return XCTFail("expected success") }
        _ = try await client.routing.planNext(route)
        _ = try await client.routing.planPrevious(route)
        XCTAssertEqual(mock.requests.count, 3)
        for request in mock.requests {
            XCTAssertEqual(request.bodyJSON["reliability"] as? String, "VERY_SAFE")
        }
        XCTAssertEqual(Reliability.allCases.map(\.rawValue), ["STANDARD", "SAFE", "VERY_SAFE"])
    }

    // Stop ids per via location (1-10) and a visit's wait (0-1 h) are fixed platform limits, checked before sending.
    func testPlanRejectsViaOutsideFixedLimitsWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        let eleven = (1...11).map { "1:V\($0)" }
        let wait = "via.visit.minimumWaitTime"
        let invalid: [(ViaLocation, String)] = [
            (.passThrough(stopIds: []), "via"),
            (.passThrough(stopIds: eleven), "via"),
            (.visit(.stop("1:V"), minimumWaitSeconds: -1), wait),
            (.visit(.stop("1:V"), minimumWaitSeconds: 3_601), wait),
            (.visit(.coordinate(49.2, 16.6), minimumWaitSeconds: 3_601), wait),
        ]
        for (via, field) in invalid {
            let result = try await client.routing.plan(PlanOptions(origin: .stop("S1"), destination: .stop("S2"), via: [via]))
            guard case .failure(let error) = result else { return XCTFail("expected failure for \(via)") }
            XCTAssertEqual(error.code, .badRequest)
            XCTAssertEqual(error.field, field)
            XCTAssertEqual(error.message, "\(field) is out of range")
        }
        XCTAssertTrue(mock.requests.isEmpty)
    }

    // A visit to a coordinate has no wire form: it fails as the server's own `via is invalid`, before sending.
    func testPlanRejectsCoordinateVisitWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        for via in [
            [ViaLocation.visit(.coordinate(49.2, 16.6))],
            [.passThrough("1:V"), .visit(.coordinate(49.2, 16.6), minimumWaitSeconds: 300)],
        ] {
            let result = try await client.routing.plan(PlanOptions(origin: .stop("S1"), destination: .stop("S2"), via: via))
            guard case .failure(let error) = result else { return XCTFail("expected failure for \(via)") }
            XCTAssertEqual(error.code, .badRequest)
            XCTAssertEqual(error.code.rawValue, "bad_request")
            XCTAssertEqual(error.field, "via")
            XCTAssertEqual(error.message, "via is invalid")
            XCTAssertNil(error.httpStatus)
        }
        XCTAssertTrue(mock.requests.isEmpty)
    }

    func testPlanSendsViaAtItsFixedLimits() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        let ten = (1...10).map { "1:V\($0)" }
        let result = try await client.routing.plan(PlanOptions(
            origin: .stop("S1"), destination: .stop("S2"),
            via: [.passThrough(stopIds: ten), .visit(.stop("1:W"), minimumWaitSeconds: 3_600), .visit(.stop("1:X"))]
        ))
        XCTAssertTrue(result.isSuccess)
        let via = mock.requests[0].bodyJSON["via"] as! [[String: Any]]
        XCTAssertEqual((via[0]["passThrough"] as! [String: Any])["stopLocationIds"] as? [String], ten)
        XCTAssertEqual(via[1]["visit"] as! NSDictionary, ["stopLocationIds": ["1:W"], "minimumWaitTime": "PT3600S"] as NSDictionary)
        XCTAssertEqual(via[2]["visit"] as! NSDictionary, ["stopLocationIds": ["1:X"]] as NSDictionary)
    }

    // Wire values this SDK doesn't know decode to `.unknown`; an unknown via stop is a VIA routing error.
    func testPlanMapsUnknownEnumValuesAndViaLocationNotFound() async throws {
        let body = """
        {
          "itineraries":[{"duration":60,"numberOfTransfers":0,"legs":[{
            "start":{"scheduledTime":"2026-08-21T10:00:00Z"},"end":{"scheduledTime":"2026-08-21T10:01:00Z"},
            "from":{"name":"A"},"to":{"name":"B"},"mode":"HOVERCRAFT","realtimeState":"TELEPORTED"
          }]}],
          "pageInfo":{"hasNextPage":false,"hasPreviousPage":false},
          "routingErrors":[
            {"code":"LOCATION_NOT_FOUND","inputField":"VIA","description":"Via stop not found"},
            {"code":"SOMETHING_NEW","inputField":"SOMEWHERE_NEW","description":"New"}
          ]
        }
        """
        let (client, _) = makeClient { _ in json(body) }
        guard case .success(let route) = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B"))) else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(route.routingErrors.map(\.code), [.locationNotFound, .unknown])
        XCTAssertEqual(route.routingErrors.map(\.inputField), [.via, .unknown])
        XCTAssertNil(route.searchDateTime)
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

    // A declined plan is a 200 with no itineraries and the reason in `routingErrors`, not a failure.
    func testDeclinedPlanIsASuccessWithRoutingErrors() async throws {
        let body = """
        {"itineraries":[],"pageInfo":{"startCursor":null,"endCursor":null,"hasNextPage":false,"hasPreviousPage":false,"searchWindowUsed":null},
         "routingErrors":[{"code":"OUTSIDE_SERVICE_PERIOD","description":"Outside the feed","inputField":"DATE_TIME"}],
         "searchDateTime":"2026-10-07T08:00:00+02:00"}
        """
        let (client, _) = makeClient { _ in json(body) }
        guard case .success(let route) = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B"))) else {
            return XCTFail("expected success")
        }
        XCTAssertTrue(route.edges.isEmpty)
        XCTAssertEqual(route.routingErrors, [RoutingError(code: .outsideServicePeriod, description: "Outside the feed", inputField: .dateTime)])
        XCTAssertFalse(route.pageInfo.hasNextPage)
        XCTAssertNil(route.pageInfo.searchWindowUsed)
    }

    // The body is the payload itself: a GraphQL `data` envelope is not the routing response.
    func testPlanResponseHasNoDataEnvelope() async throws {
        let enveloped = #"{"data":{"planConnection":{"edges":[],"pageInfo":{"hasNextPage":false,"hasPreviousPage":false},"routingErrors":[]}}}"#
        let (client, _) = makeClient { _ in json(enveloped) }
        guard case .failure(let error) = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B"))) else {
            return XCTFail("expected failure")
        }
        XCTAssertEqual(error.code, .decoding)
    }

    // A routing 400 names the field in the body's `field`, a dot path from the body root.
    func testRouting400IsBadRequestWithTheBodyField() async throws {
        let body = #"{"code":"bad_request","message":"preferences.transit.transfer.maximumTransfers is out of range","field":"preferences.transit.transfer.maximumTransfers"}"#
        let (client, _) = makeClient { _ in json(body, status: 400) }
        let result = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B")))
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .badRequest)
        XCTAssertEqual(error.httpStatus, 400)
        XCTAssertEqual(error.serverCode, "bad_request")
        XCTAssertEqual(error.field, "preferences.transit.transfer.maximumTransfers")
        XCTAssertTrue(error.message.contains("preferences.transit.transfer.maximumTransfers is out of range"))
    }

    // The body's `field` wins over the message; without one, a message of the fixed `<field> is …` shape (dot paths
    // and `not allowed` included) names it; any other message names none.
    func testRouting400FieldFromBodyOrFixedMessageShape() async throws {
        let cases: [(String, String?)] = [
            (#"{"code":"bad_request","message":"after is invalid","field":"after"}"#, "after"),
            (#"{"code":"bad_request","message":"something odd","field":"via"}"#, "via"),
            (#"{"code":"bad_request","message":"via.visit.coordinate is not allowed"}"#, "via.visit.coordinate"),
            (#"{"code":"bad_request","message":"modes.transit.transit.mode is invalid"}"#, "modes.transit.transit.mode"),
            (#"{"code":"bad_request","message":"searchWindow is required"}"#, "searchWindow"),
            (#"{"code":"bad_request","message":"body is invalid"}"#, "body"),
            (#"{"code":"bad_request","message":"bad input is not allowed"}"#, nil),
            (#"{"code":"bad_request","message":"searchWindow exceeds the maximum"}"#, nil),
        ]
        for (body, field) in cases {
            let (client, _) = makeClient { _ in json(body, status: 400) }
            guard case .failure(let error) = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B"))) else {
                return XCTFail("expected failure for \(body)")
            }
            XCTAssertEqual(error.code, .badRequest, body)
            XCTAssertEqual(error.field, field, body)
        }
    }

    // A field is named only on a bad request.
    func testFieldIsNilOutsideBadRequest() async throws {
        let (client, _) = makeClient { _ in json(#"{"code":"boom","message":"via is invalid","field":"via"}"#, status: 500) }
        guard case .failure(let error) = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B"))) else {
            return XCTFail("expected failure")
        }
        XCTAssertEqual(error.code, .server)
        XCTAssertNil(error.field)
    }

    func testPlanArriveBySetsLatestArrival() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        _ = try await client.routing.plan(PlanOptions(
            origin: .stop("S1"), destination: .stop("S2"),
            arriveBy: Date(timeIntervalSince1970: 1_700_000_000)
        ))
        let dateTime = mock.requests[0].bodyJSON["dateTime"] as! [String: Any]
        XCTAssertNotNil(dateTime["latestArrival"])
        XCTAssertNil(dateTime["earliestDeparture"])
    }

    // The next page is the same body plus `after`; never `before`, `first` or `last`.
    func testPlanNextPagesForwardWithAfter() async throws {
        let page2 = """
        {"itineraries":[],"pageInfo":{"hasNextPage":false,"hasPreviousPage":true,"startCursor":"c2","endCursor":"c2","searchWindowUsed":"PT60M"},"routingErrors":[],"searchDateTime":null}
        """
        let (client, mock) = makeClient { req in
            json(req.bodyJSON["after"] as? String == "c1" ? page2 : self.planBody)
        }
        guard case .success(let first) = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B"))) else {
            return XCTFail("expected success")
        }
        guard case .success(let next)? = try await client.routing.planNext(first) else { return XCTFail("expected a next page") }
        XCTAssertEqual(next.pageInfo.startCursor, "c2")
        XCTAssertEqual(mock.requests[1].path, "/routing/v1/plan")
        var body = mock.requests[1].bodyJSON
        XCTAssertEqual(body.removeValue(forKey: "after") as? String, "c1")
        XCTAssertEqual(body as NSDictionary, mock.requests[0].bodyJSON as NSDictionary)
        // The last page has no next.
        let none = try await client.routing.planNext(next)
        XCTAssertNil(none)
        XCTAssertEqual(mock.requests.count, 2)
    }

    // The previous page is the same body plus `before`; never `after`, `first` or `last`.
    func testPlanPreviousPagesBackwardWithBefore() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        guard case .success(let first) = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B"))) else {
            return XCTFail("expected success")
        }
        let previous = try await client.routing.planPrevious(first)
        XCTAssertNotNil(previous)
        var body = mock.requests[1].bodyJSON
        XCTAssertEqual(body.removeValue(forKey: "before") as? String, "c0")
        XCTAssertEqual(body as NSDictionary, mock.requests[0].bodyJSON as NSDictionary)
    }

    func testHttpErrorBecomesFailureWithMappedCode() async throws {
        let (client, _) = makeClient { _ in json("{\"code\":\"boom\",\"message\":\"nope\"}", status: 503) }
        let result = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B")))
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .server)
        XCTAssertEqual(error.httpStatus, 503)
        XCTAssertEqual(error.serverCode, "boom")
    }

    // The contract-version response header is informational: a gateway declaring another major still answers.
    func testOtherContractMajorOnResponseIsIgnored() async throws {
        let (client, _) = makeClient { _ in json(self.planBody, contractVersion: "4.0") }
        let result = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B")))
        guard case .success(let route) = result else { return XCTFail("expected success") }
        XCTAssertEqual(route.edges.count, 1)
    }

    // A 410 means the part of the API this SDK version calls is retired, on every routing call; the message is the
    // server's, stating the state.
    func testRetiredAnswerMapsToQueryRetired() async throws {
        let body = #"{"code":"query_retired","message":"persisted queries are retired"}"#
        let (client, _) = makeClient { _ in json(body, status: 410) }
        let results: [SpiderError?] = [
            try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B"))).error,
            try await client.routing.departures("S").error,
            try await client.routing.trip("T").error,
        ]
        for error in results {
            guard let error else { return XCTFail("expected failure") }
            XCTAssertEqual(error.code, .queryRetired)
            XCTAssertEqual(error.code.rawValue, "query_retired")
            XCTAssertEqual(error.httpStatus, 410)
            XCTAssertEqual(error.serverCode, "query_retired")
            XCTAssertTrue(error.message.contains("persisted queries are retired"))
            for action in ["update", "upgrade", "retry"] {
                XCTAssertFalse(error.message.lowercased().contains(action))
            }
        }
    }

    // The status decides: a 410 without a readable body, or on another surface, is retired too.
    func testBare410IsQueryRetired() async throws {
        let (client, _) = makeClient { _ in json("", status: 410) }
        let departures = try await client.routing.departures("S").error
        XCTAssertEqual(departures?.code, .queryRetired)
        XCTAssertEqual(departures?.httpStatus, 410)
        let search = try await client.stops.search(StopFilter(name: "x")).error
        XCTAssertEqual(search?.code, .queryRetired)
        let alerts = try await client.realtime.alerts().error
        XCTAssertEqual(alerts?.code, .queryRetired)
    }

    // A 403 without a plan-limit code (a key not accepted here) stays a key problem.
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
        {"stop":{"gtfsId":"S","name":"Main Square","wheelchairBoarding":"POSSIBLE","stoptimesWithoutPatterns":[
          {"serviceDay":1700000000,"scheduledDeparture":36000,"realtimeDeparture":36060,"realtime":true,"realtimeState":"UPDATED","typicalDelay":45,"headsign":"Airport","stop":{"gtfsId":"S:P2","platformCode":"2"},"trip":{"gtfsId":"T1","bikesAllowed":"ALLOWED","wheelchairAccessible":"POSSIBLE","route":{"gtfsId":"1:R12","shortName":"12","longName":"Line 12","mode":"BUS","color":"00A0E0","textColor":"000000"}}},
          {"serviceDay":1700000000,"scheduledDeparture":36300,"realtime":false,"headsign":"main square","trip":{"gtfsId":"T2","wheelchairAccessible":"NO_INFORMATION","route":{"gtfsId":"1:R5","shortName":"5","mode":"TRAM"}}}
        ]}}
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
        XCTAssertEqual(mock.requests[0].path, "/routing/v1/departures")
        XCTAssertEqual(mock.requests[0].bodyJSON["numberOfDepartures"] as? Int, 10)
    }

    // Both limited inputs are required on the wire, so the SDK always sends them: 30 departures within 24 h.
    func testDeparturesAlwaysSendsCountAndTimeRange() async throws {
        let (client, mock) = makeClient { _ in json(#"{"stop":{"gtfsId":"S","name":"S","stoptimesWithoutPatterns":[]}}"#) }
        _ = try await client.routing.departures("S")
        XCTAssertEqual(mock.requests[0].httpMethod, "POST")
        XCTAssertEqual(mock.requests[0].bodyJSON as NSDictionary, ["id": "S", "numberOfDepartures": 30, "timeRange": 86_400] as NSDictionary)

        _ = try await client.routing.departures("S", startTime: Date(timeIntervalSince1970: 1_791_612_000.9), timeRangeSeconds: 1)
        XCTAssertEqual(
            mock.requests[1].bodyJSON as NSDictionary,
            ["id": "S", "numberOfDepartures": 30, "timeRange": 1, "startTime": 1_791_612_000] as NSDictionary
        )
    }

    // An id that is neither a stop nor a station is a 200 with a null board: not found.
    func testDeparturesUnknownStopIsNotFound() async throws {
        let (client, _) = makeClient { _ in json(#"{"stop":null}"#) }
        let error = try await client.routing.departures("1:NOPE").error
        XCTAssertEqual(error?.code, .notFound)
        XCTAssertNil(error?.httpStatus)
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
        {"stop":{"gtfsId":"S","name":"S","stoptimesWithoutPatterns":[
          {"serviceDay":1790546400,"scheduledDeparture":88800,"headsign":"Depot","trip":{"gtfsId":"N1","route":{"gtfsId":"1:N90","shortName":"N90","mode":"BUS"}}}
        ]}}
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
        {"trip":{"gtfsId":"T1","directionId":"0","tripHeadsign":"Airport","bikesAllowed":"NOT_ALLOWED","wheelchairAccessible":"NOT_POSSIBLE","route":{"gtfsId":"1:R12","shortName":"12","longName":"Line 12","mode":"BUS","color":"FF0000","textColor":"FFFFFF"},"stoptimesForDate":[
          {"serviceDay":1700000000,"scheduledArrival":36000,"scheduledDeparture":36030,"realtimeArrival":36050,"realtimeDeparture":36080,"realtime":true,"typicalDelay":30,"stop":{"gtfsId":"S1","name":"A","lat":49.19,"lon":16.61,"wheelchairBoarding":"POSSIBLE","platformCode":"1","zoneId":"P"}},
          {"serviceDay":1700000000,"scheduledArrival":36600,"typicalDelay":null,"stop":{"gtfsId":"S2","name":"B"}}
        ],"tripGeometry":{"points":"_p~iF~ps|U","length":2}}}
        """
        let (client, mock) = makeClient { _ in json(body) }
        let result = try await client.routing.trip("T1", serviceDate: "2026-08-21")
        guard case .success(let trip) = result else { return XCTFail("expected success") }
        XCTAssertEqual(mock.requests[0].path, "/routing/v1/trip")
        XCTAssertEqual(mock.requests[0].httpMethod, "POST")
        XCTAssertEqual(mock.requests[0].bodyJSON as NSDictionary, ["id": "T1", "serviceDate": "2026-08-21"] as NSDictionary)
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

    // Without a service date the body carries only the id; an unknown trip is a 200 with null: not found.
    func testTripWithoutServiceDateAndUnknownTrip() async throws {
        let (client, mock) = makeClient { _ in json(#"{"trip":null}"#) }
        let error = try await client.routing.trip("1:NOPE").error
        XCTAssertEqual(mock.requests[0].bodyJSON as NSDictionary, ["id": "1:NOPE"] as NSDictionary)
        XCTAssertEqual(error?.code, .notFound)
    }
}
