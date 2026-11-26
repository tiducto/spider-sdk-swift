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
          "from":{"name":"A","stopPosition":2,"stop":{"gtfsId":"S1","wheelchairBoarding":"POSSIBLE","platformCode":"3","zoneId":"P"}},
          "to":{"name":"B","stopPosition":5,"stop":{"gtfsId":"S2","wheelchairBoarding":"NOT_POSSIBLE","platformCode":"B","zoneId":"0"}},
          "mode":"BUS","route":{"gtfsId":"1:R12","shortName":"12","longName":"Line 12","color":"FF0000","textColor":"FFFFFF"},"headsign":"Downtown",
          "realtimeState":"SCHEDULED","realTime":false,"serviceDate":"2026-08-21","distance":1500.0,"duration":900,
          "trip":{"gtfsId":"T1","bikesAllowed":"ALLOWED"},"typicalArrivalDelay":90,"interlineWithPreviousLeg":true,"pickupType":"COORDINATE_WITH_DRIVER","dropoffType":"CALL_AGENCY",
          "legGeometry":{"points":"_izlhA~rlgdF_{geC~ywl@_kwzCn`{nI"}
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
        XCTAssertEqual(leg.fromStopPosition, 2)
        XCTAssertEqual(leg.toStopPosition, 5)
        XCTAssertEqual(leg.pickupType, .coordinateWithDriver)
        XCTAssertEqual(leg.dropoffType, .callAgency)
        XCTAssertEqual(route.pageInfo, RoutePageInfo(startCursor: "c0", endCursor: "c1", hasNextPage: true, hasPreviousPage: true, searchWindowUsed: "PT60M"))
        XCTAssertEqual(route.searchDateTime, "2026-08-21T10:00:00Z")

        let req = mock.requests[0]
        XCTAssertEqual(req.path, "/routing/v1/plan")
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.value(forHTTPHeaderField: "apikey"), "secret-key")
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-spider-contract-version"), "1.11")
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-spider-sdk"), "swift/1.11.0")
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
        XCTAssertNil(body["reliability"])
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

    // Excluded modes go out as modes.transit.exclude, WALK and UNKNOWN dropped like the allow-list's.
    func testPlanSendsExcludedTransitModes() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        _ = try await client.routing.plan(PlanOptions(
            origin: .stop("S1"),
            destination: .stop("S2"),
            departAt: Date(timeIntervalSince1970: 1_791_612_000),
            excludedTransitModes: [.tram, .walk, .unknown, .rail]
        ))
        let expected: [String: Any] = [
            "dateTime": ["earliestDeparture": "2026-10-10T06:00:00Z"],
            "origin": ["location": ["stopLocation": ["stopLocationId": "S1"]]],
            "destination": ["location": ["stopLocation": ["stopLocationId": "S2"]]],
            "modes": ["transit": ["exclude": ["TRAM", "RAIL"]]],
            "searchWindow": "PT60M",
        ]
        XCTAssertEqual(mock.requests[0].bodyJSON as NSDictionary, expected as NSDictionary)
    }

    // Empty, or only modes that drop out, is no filter: `modes` is omitted. An allow-list of only WALK drops out
    // too, so it doesn't clash with an exclusion.
    func testPlanExcludedTransitModesWithoutWireModesAreNoFilter() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        _ = try await client.routing.plan(PlanOptions(origin: .stop("S1"), destination: .stop("S2"), excludedTransitModes: []))
        _ = try await client.routing.plan(PlanOptions(origin: .stop("S1"), destination: .stop("S2"), excludedTransitModes: [.walk, .unknown]))
        _ = try await client.routing.plan(PlanOptions(
            origin: .stop("S1"), destination: .stop("S2"), allowedTransitModes: [.walk], excludedTransitModes: [.tram]
        ))
        XCTAssertEqual(mock.requests.count, 3)
        XCTAssertNil(mock.requests[0].bodyJSON["modes"])
        XCTAssertNil(mock.requests[1].bodyJSON["modes"])
        XCTAssertEqual(mock.requests[2].bodyJSON["modes"] as? NSDictionary, ["transit": ["exclude": ["TRAM"]]] as NSDictionary)
    }

    func testPlanKeepsExcludedTransitModesWhenPaging() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        let result = try await client.routing.plan(PlanOptions(origin: .stop("S1"), destination: .stop("S2"), excludedTransitModes: [.bus]))
        guard case .success(let route) = result else { return XCTFail("expected success") }
        _ = try await client.routing.planNext(route)
        _ = try await client.routing.planPrevious(route)
        XCTAssertEqual(mock.requests.count, 3)
        for request in mock.requests {
            XCTAssertEqual(request.bodyJSON["modes"] as? NSDictionary, ["transit": ["exclude": ["BUS"]]] as NSDictionary)
        }
    }

    func testPlanRejectsAllowedAndExcludedModesWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        let result = try await client.routing.plan(PlanOptions(
            origin: .stop("S1"), destination: .stop("S2"), allowedTransitModes: [.bus], excludedTransitModes: [.tram]
        ))
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .badRequest)
        XCTAssertEqual(error.field, "modes.transit")
        XCTAssertEqual(error.message, "modes.transit is invalid")
        XCTAssertNil(error.httpStatus)
        XCTAssertTrue(mock.requests.isEmpty)
    }

    private let fullPreferences = RoutePreferences(
        walkSpeed: 1.2,
        walkReluctance: 4.5,
        boardCost: 600,
        transferCost: 300,
        transferSlackSeconds: 120,
        waitReluctance: 0.5,
        boardSlackSeconds: 30,
        alightSlackSeconds: 3_600,
        excludedRoutes: ["1:L4", "1:L9"],
        excludedAgencies: ["1:DPMB"]
    )

    private let fullPreferencesWire: [String: Any] = [
        "street": ["walk": ["speed": 1.2, "reluctance": 4.5, "boardCost": 600]],
        "transit": [
            "transfer": ["cost": 300, "slack": "PT120S", "maximumTransfers": 3],
            "board": ["waitReluctance": 0.5, "slack": "PT30S"],
            "alight": ["slack": "PT3600S"],
            "filters": [["exclude": [["routes": ["1:L4", "1:L9"]], ["agencies": ["1:DPMB"]]]]],
        ],
        "accessibility": ["wheelchair": ["enabled": true]],
    ]

    func testPlanWithoutOrWithEmptyPreferencesSendsTodaysBody() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        func options(_ preferences: RoutePreferences?, transitOnly: Bool = false) -> PlanOptions {
            PlanOptions(
                origin: .stop("S1"), destination: .stop("S2"), departAt: Date(timeIntervalSince1970: 1_791_612_000),
                maxTransfers: 1, wheelchairAccessible: true, preferences: preferences, transitOnly: transitOnly
            )
        }
        for preferences in [nil, RoutePreferences(), RoutePreferences(excludedRoutes: [], excludedAgencies: [])] {
            _ = try await client.routing.plan(options(preferences))
        }
        _ = try await client.routing.plan(options(nil, transitOnly: false))
        let expected: [String: Any] = [
            "dateTime": ["earliestDeparture": "2026-10-10T06:00:00Z"],
            "origin": ["location": ["stopLocation": ["stopLocationId": "S1"]]],
            "destination": ["location": ["stopLocation": ["stopLocationId": "S2"]]],
            "preferences": [
                "transit": ["transfer": ["maximumTransfers": 2]],
                "accessibility": ["wheelchair": ["enabled": true]],
            ],
            "searchWindow": "PT60M",
        ]
        XCTAssertEqual(mock.requests.count, 4)
        for request in mock.requests {
            XCTAssertEqual(request.bodyJSON as NSDictionary, expected as NSDictionary)
        }
        _ = try await client.routing.plan(PlanOptions(origin: .stop("S1"), destination: .stop("S2"), preferences: RoutePreferences()))
        XCTAssertNil(mock.requests[4].bodyJSON["preferences"])
        XCTAssertNil(mock.requests[4].bodyJSON["modes"])
    }

    func testPlanSendsEveryPreferenceAtItsContractPathBesideTransfersAndWheelchair() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        _ = try await client.routing.plan(PlanOptions(
            origin: .stop("S1"), destination: .stop("S2"), maxTransfers: 2, wheelchairAccessible: true,
            preferences: fullPreferences
        ))
        XCTAssertEqual(mock.requests[0].bodyJSON["preferences"] as? NSDictionary, fullPreferencesWire as NSDictionary)
    }

    func testPlanSendsASinglePreferenceOnItsOwnBranch() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        let cases: [(RoutePreferences, [String: Any])] = [
            (RoutePreferences(transferSlackSeconds: 0), ["transit": ["transfer": ["slack": "PT0S"]]]),
            (RoutePreferences(walkSpeed: 0.1), ["street": ["walk": ["speed": 0.1]]]),
            (RoutePreferences(boardSlackSeconds: 90), ["transit": ["board": ["slack": "PT90S"]]]),
            (RoutePreferences(alightSlackSeconds: 15), ["transit": ["alight": ["slack": "PT15S"]]]),
            (
                RoutePreferences(excludedRoutes: [], excludedAgencies: ["1:A"]),
                ["transit": ["filters": [["exclude": [["agencies": ["1:A"]]]]]]]
            ),
        ]
        for (index, (preferences, expected)) in cases.enumerated() {
            _ = try await client.routing.plan(PlanOptions(origin: .stop("S1"), destination: .stop("S2"), preferences: preferences))
            XCTAssertEqual(mock.requests[index].bodyJSON["preferences"] as? NSDictionary, expected as NSDictionary, "\(preferences)")
        }
    }

    func testPlanRejectsPreferencesOutOfRangeWithTheirPathWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        let outOfRange: [(RoutePreferences, String)] = [
            (RoutePreferences(walkSpeed: 0.09), "preferences.street.walk.speed"),
            (RoutePreferences(walkSpeed: .infinity), "preferences.street.walk.speed"),
            (RoutePreferences(walkSpeed: .nan), "preferences.street.walk.speed"),
            (RoutePreferences(walkReluctance: 0.09), "preferences.street.walk.reluctance"),
            (RoutePreferences(walkReluctance: 100_001), "preferences.street.walk.reluctance"),
            (RoutePreferences(boardCost: -1), "preferences.street.walk.boardCost"),
            (RoutePreferences(transferCost: 1_000_001), "preferences.transit.transfer.cost"),
            (RoutePreferences(transferSlackSeconds: -1), "preferences.transit.transfer.slack"),
            (RoutePreferences(waitReluctance: 0), "preferences.transit.board.waitReluctance"),
            (RoutePreferences(boardSlackSeconds: 3_660), "preferences.transit.board.slack"),
            (RoutePreferences(alightSlackSeconds: 3_601), "preferences.transit.alight.slack"),
        ]
        for (preferences, field) in outOfRange {
            let result = try await client.routing.plan(PlanOptions(origin: .stop("S1"), destination: .stop("S2"), preferences: preferences))
            guard case .failure(let error) = result else { return XCTFail("expected failure for \(preferences)") }
            XCTAssertEqual(error.code, .badRequest)
            XCTAssertEqual(error.field, field)
            XCTAssertEqual(error.message, "\(field) is out of range")
            XCTAssertNil(error.httpStatus)
        }
        XCTAssertTrue(mock.requests.isEmpty)
    }

    func testPlanAcceptsPreferencesAtTheirBounds() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        for preferences in [
            RoutePreferences(walkSpeed: 0.1, walkReluctance: 0.1, boardCost: 0, transferCost: 0, transferSlackSeconds: 0, waitReluctance: 0.1, boardSlackSeconds: 0, alightSlackSeconds: 0),
            RoutePreferences(walkSpeed: 1_000, walkReluctance: 100_000, boardCost: 1_000_000, transferCost: 1_000_000, transferSlackSeconds: 3_600, waitReluctance: 100_000, boardSlackSeconds: 3_600, alightSlackSeconds: 3_600),
        ] {
            let result = try await client.routing.plan(PlanOptions(origin: .stop("S1"), destination: .stop("S2"), preferences: preferences))
            XCTAssertTrue(result.isSuccess, "\(preferences)")
        }
        XCTAssertEqual(mock.requests.count, 2)
    }

    func testPlanSendsTransitOnlyAloneAndBesideAModeFilter() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        _ = try await client.routing.plan(PlanOptions(origin: .stop("S1"), destination: .stop("S2"), transitOnly: true))
        _ = try await client.routing.plan(PlanOptions(
            origin: .stop("S1"), destination: .stop("S2"), excludedTransitModes: [.tram], transitOnly: true
        ))
        _ = try await client.routing.plan(PlanOptions(
            origin: .stop("S1"), destination: .stop("S2"), allowedTransitModes: [.bus], transitOnly: true
        ))
        _ = try await client.routing.plan(PlanOptions(
            origin: .stop("S1"), destination: .stop("S2"), excludedTransitModes: [.tram], transitOnly: false
        ))
        let modes = mock.requests.map { $0.bodyJSON["modes"] as? NSDictionary }
        XCTAssertEqual(modes[0], ["transitOnly": true] as NSDictionary)
        XCTAssertEqual(modes[1], ["transitOnly": true, "transit": ["exclude": ["TRAM"]]] as NSDictionary)
        XCTAssertEqual(modes[2], ["transitOnly": true, "transit": ["transit": [["mode": "BUS"]]]] as NSDictionary)
        XCTAssertEqual(modes[3], ["transit": ["exclude": ["TRAM"]]] as NSDictionary)
    }

    func testPlanKeepsPreferencesAndTransitOnlyWhenPaging() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        let preferences = RoutePreferences(walkSpeed: 1.0, transferSlackSeconds: 180, excludedRoutes: ["1:L4"])
        let result = try await client.routing.plan(PlanOptions(
            origin: .stop("S1"), destination: .stop("S2"), preferences: preferences, transitOnly: true
        ))
        guard case .success(let route) = result else { return XCTFail("expected success") }
        _ = try await client.routing.planNext(route)
        _ = try await client.routing.planPrevious(route)
        _ = try await client.routing.planNext(route, numberOfItineraries: 2)
        _ = try await client.routing.planPrevious(route, numberOfItineraries: 2)
        let expected: [String: Any] = [
            "street": ["walk": ["speed": 1.0]],
            "transit": ["transfer": ["slack": "PT180S"], "filters": [["exclude": [["routes": ["1:L4"]]]]]],
        ]
        XCTAssertEqual(mock.requests.count, 5)
        for request in mock.requests {
            XCTAssertEqual(request.bodyJSON["preferences"] as? NSDictionary, expected as NSDictionary)
            XCTAssertEqual(request.bodyJSON["modes"] as? NSDictionary, ["transitOnly": true] as NSDictionary)
        }
    }

    func testPlanNumberOfItinerariesIsFirstOrLastByDirectionAndKeptWhenPaging() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        guard case .success(let sized) = try await client.routing.plan(
            PlanOptions(origin: .stop("S1"), destination: .stop("S2")), numberOfItineraries: 3
        ) else { return XCTFail("expected success") }
        _ = try await client.routing.planNext(sized)
        _ = try await client.routing.planPrevious(sized)
        guard case .success(let next)? = try await client.routing.planNext(sized, numberOfItineraries: 1) else {
            return XCTFail("expected a next page")
        }
        _ = try await client.routing.planPrevious(sized, numberOfItineraries: nil)
        _ = try await client.routing.planNext(next)
        _ = try await client.routing.planPrevious(next)
        _ = try await client.routing.plan(PlanOptions(origin: .stop("S1"), destination: .stop("S2")))

        let counts = mock.requests.map { [$0.bodyJSON["first"] as? Int, $0.bodyJSON["last"] as? Int] }
        XCTAssertEqual(counts, [[3, nil], [3, nil], [nil, 3], [1, nil], [nil, nil], [1, nil], [nil, 1], [nil, nil]])
        XCTAssertEqual(
            mock.requests.map { $0.bodyJSON["after"] as? String },
            [nil, "c1", nil, "c1", nil, "c1", nil, nil]
        )
        XCTAssertEqual(
            mock.requests.map { $0.bodyJSON["before"] as? String },
            [nil, nil, "c0", nil, "c0", nil, "c0", nil]
        )
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

    func testPlanSendsMixedViaKindsInOrder() async throws {
        let (client, mock) = makeClient { _ in json(self.planBody) }
        let result = try await client.routing.plan(PlanOptions(
            origin: .stop("S1"), destination: .stop("S2"),
            via: [.passThrough("1:P1"), .visit(.stop("1:V"), minimumWaitSeconds: 120), .passThrough("1:P2", "1:P3")]
        ))
        XCTAssertTrue(result.isSuccess)
        let expected: [[String: Any]] = [
            ["passThrough": ["stopLocationIds": ["1:P1"]]],
            ["visit": ["stopLocationIds": ["1:V"], "minimumWaitTime": "PT120S"]],
            ["passThrough": ["stopLocationIds": ["1:P2", "1:P3"]]],
        ]
        XCTAssertEqual(mock.requests[0].bodyJSON["via"] as! NSArray, expected as NSArray)
    }

    func testPlanDecodesEveryRoutingErrorCode() async throws {
        let body = """
        {"itineraries":[],"pageInfo":{"startCursor":null,"endCursor":null,"hasNextPage":false,"hasPreviousPage":false,"searchWindowUsed":null},
         "routingErrors":[
           {"code":"LOCATION_NOT_FOUND","description":"Origin is unknown","inputField":"FROM"},
           {"code":"NO_DIRECT_MODE_CONNECTION","description":"No walk","inputField":null},
           {"code":"NO_STOPS_IN_RANGE","description":"No stops","inputField":"TO"},
           {"code":"NO_TRANSIT_CONNECTION","description":"Not connected","inputField":null},
           {"code":"NO_TRANSIT_CONNECTION_IN_SEARCH_WINDOW","description":"Nothing in the window","inputField":"DATE_TIME"},
           {"code":"OUTSIDE_BOUNDS","description":"Outside the area","inputField":"TO"},
           {"code":"OUTSIDE_SERVICE_PERIOD","description":"Outside the feed","inputField":"DATE_TIME"},
           {"code":"WALKING_BETTER_THAN_TRANSIT","description":"Walk","inputField":null}
         ],
         "searchDateTime":"2026-10-07T08:00:00+02:00"}
        """
        let (client, _) = makeClient { _ in json(body) }
        guard case .success(let route) = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B"))) else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(route.routingErrors.map(\.code), [
            .locationNotFound, .noDirectModeConnection, .noStopsInRange, .noTransitConnection,
            .noTransitConnectionInSearchWindow, .outsideBounds, .outsideServicePeriod, .walkingBetterThanTransit,
        ])
        XCTAssertEqual(route.routingErrors.map(\.inputField), [.from, nil, .to, nil, .dateTime, .to, .dateTime, nil])
        XCTAssertEqual(RoutingErrorCode.allCases.count, 9)
    }

    // Wire values this SDK doesn't know decode to `.unknown`; an unknown via stop is a VIA routing error.
    func testPlanMapsUnknownEnumValuesAndViaLocationNotFound() async throws {
        let body = """
        {
          "itineraries":[{"start":"2026-08-21T10:00:00Z","end":"2026-08-21T10:01:00Z","duration":60,"waitingTime":0,"numberOfTransfers":0,"legs":[{
            "start":{"scheduledTime":"2026-08-21T10:00:00Z","estimated":null},"end":{"scheduledTime":"2026-08-21T10:01:00Z","estimated":null},
            "from":{"name":"A","stop":null},"to":{"name":"B","stop":null},"mode":"HOVERCRAFT","realtimeState":"TELEPORTED","realTime":false,
            "typicalArrivalDelay":null,"serviceDate":null,"route":null,"headsign":null,"trip":null,
            "distance":80.0,"duration":60,"interlineWithPreviousLeg":false,"pickupType":"BY_DRONE","dropoffType":"SCHEDULED","legGeometry":{"points":""}
          }]}],
          "pageInfo":{"hasNextPage":false,"hasPreviousPage":false,"startCursor":null,"endCursor":null,"searchWindowUsed":null},
          "routingErrors":[
            {"code":"LOCATION_NOT_FOUND","inputField":"VIA","description":"Via stop not found"},
            {"code":"SOMETHING_NEW","inputField":"SOMEWHERE_NEW","description":"New"}
          ],
          "searchDateTime":"2026-08-21T10:00:00Z"
        }
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
        XCTAssertEqual(leg.pickupType, .unknown)
        XCTAssertEqual(leg.dropoffType, .scheduled)
        // A leg with no route or stops (a walk) has no display fields, no typical delay and no interline.
        XCTAssertNil(leg.typicalArrivalDelaySeconds)
        XCTAssertFalse(leg.interlineWithPreviousLeg)
        XCTAssertNil(leg.serviceDate)
        XCTAssertNil(leg.tripGtfsId)
        XCTAssertNil(leg.fromGtfsId)
        XCTAssertNil(leg.routeGtfsId)
        XCTAssertNil(leg.routeColor)
        XCTAssertNil(leg.routeTextColor)
        XCTAssertNil(leg.fromPlatformCode)
        XCTAssertNil(leg.toPlatformCode)
        XCTAssertNil(leg.fromZoneId)
        XCTAssertNil(leg.toZoneId)
    }

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

    func testPlanResponseHasNoDataEnvelope() async throws {
        let enveloped = #"{"data":{"planConnection":{"edges":[],"pageInfo":{"hasNextPage":false,"hasPreviousPage":false},"routingErrors":[]}}}"#
        let (client, _) = makeClient { _ in json(enveloped) }
        guard case .failure(let error) = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B"))) else {
            return XCTFail("expected failure")
        }
        XCTAssertEqual(error.code, .decoding)
    }

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

    func testPlanNextPagesForwardWithAfter() async throws {
        let page2 = """
        {"itineraries":[],"pageInfo":{"hasNextPage":false,"hasPreviousPage":true,"startCursor":"c2","endCursor":"c2","searchWindowUsed":"PT60M"},"routingErrors":[],"searchDateTime":"2026-08-21T11:00:00Z"}
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
        let none = try await client.routing.planNext(next)
        XCTAssertNil(none)
        XCTAssertEqual(mock.requests.count, 2)
    }

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
          {"serviceDay":1700000000,"serviceDate":"2023-11-14","scheduledDeparture":36000,"realtimeDeparture":36060,"realtime":true,"realtimeState":"UPDATED","typicalDelay":45,"stopPosition":7,"pickupType":"COORDINATE_WITH_DRIVER","dropoffType":"NONE","headsign":"Airport","stop":{"gtfsId":"S:P2","platformCode":"2"},"trip":{"gtfsId":"T1","bikesAllowed":"ALLOWED","wheelchairAccessible":"POSSIBLE","route":{"gtfsId":"1:R12","shortName":"12","longName":"Line 12","mode":"BUS","color":"00A0E0","textColor":"000000"}}},
          {"serviceDay":1700000000,"serviceDate":"2023-11-14","scheduledDeparture":36300,"realtimeDeparture":36300,"realtime":false,"realtimeState":"SCHEDULED","typicalDelay":null,"pickupType":"SCHEDULED","dropoffType":"SCHEDULED","headsign":"main square","stop":{"gtfsId":"S:P1","platformCode":null},"trip":{"gtfsId":"T2","bikesAllowed":"NO_INFORMATION","wheelchairAccessible":"NO_INFORMATION","route":{"gtfsId":"1:R5","shortName":"5","longName":null,"mode":"TRAM","color":null,"textColor":null}}}
        ]}}
        """
        let (client, mock) = makeClient { _ in json(body) }
        let result = try await client.routing.departures("S", numberOfDepartures: 10)
        guard case .success(let departures) = result else { return XCTFail("expected success") }
        XCTAssertEqual(departures.map(\.tripGtfsId), ["T1", "T2"])
        let d = departures[0]
        // Read from the wire as given, not derived from serviceDay.
        XCTAssertEqual(d.serviceDate, "2023-11-14")
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
        XCTAssertEqual(bare.stopGtfsId, "S:P1")
        XCTAssertEqual(bare.realtimeTimeEpochMs, bare.scheduledTimeEpochMs)
        XCTAssertNil(bare.platformCode)
        XCTAssertNil(bare.wheelchairAccessible)
        XCTAssertNil(bare.typicalDelaySeconds)
        XCTAssertEqual(d.stopPosition, 7)
        XCTAssertNil(bare.stopPosition)
        XCTAssertEqual(d.pickupType, .coordinateWithDriver)
        XCTAssertEqual(d.dropoffType, .notPossible)
        XCTAssertEqual(bare.pickupType, .scheduled)
        XCTAssertEqual(bare.dropoffType, .scheduled)
        XCTAssertEqual(mock.requests[0].path, "/routing/v1/departures")
        XCTAssertEqual(mock.requests[0].bodyJSON["numberOfDepartures"] as? Int, 10)
        XCTAssertNil(mock.requests[0].bodyJSON["reliability"])
    }

    func testDeparturesSendsReliabilityWhenSet() async throws {
        let (client, mock) = makeClient { _ in json(#"{"stop":{"gtfsId":"S","name":"S","stoptimesWithoutPatterns":[]}}"#) }
        _ = try await client.routing.departures("S", reliability: .verySafe)
        XCTAssertEqual(mock.requests[0].bodyJSON["reliability"] as? String, "VERY_SAFE")
    }

    // excludeModes goes out only when a real transit mode is excluded; WALK and UNKNOWN drop out.
    func testDeparturesSendsExcludedModes() async throws {
        let (client, mock) = makeClient { _ in json(#"{"stop":{"gtfsId":"S","name":"S","stoptimesWithoutPatterns":[]}}"#) }
        _ = try await client.routing.departures("S", excludedModes: [.tram, .walk, .unknown, .bus])
        XCTAssertEqual(
            mock.requests[0].bodyJSON as NSDictionary,
            ["id": "S", "numberOfDepartures": 30, "timeRange": 86_400, "excludeModes": ["TRAM", "BUS"]] as NSDictionary
        )
        _ = try await client.routing.departures("S", excludedModes: [])
        _ = try await client.routing.departures("S", excludedModes: [.walk, .unknown])
        XCTAssertNil(mock.requests[1].bodyJSON["excludeModes"])
        XCTAssertNil(mock.requests[2].bodyJSON["excludeModes"])
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

    func testPlanLegMapsVehicleAndNullVehicle() async throws {
        let vehicle = #""vehicle":{"id":"1:V7","label":"7104","wheelchairAccessible":"POSSIBLE","airConditioning":true,"wifi":false,"cardPayment":null}"#
        let unknown = #""vehicle":{"id":null,"label":null,"wheelchairAccessible":"NO_INFORMATION","airConditioning":null,"wifi":null,"cardPayment":null}"#
        let body = planBody
            .replacingOccurrences(of: #""pickupType":"COORDINATE_WITH_DRIVER""#, with: vehicle + #","pickupType":"COORDINATE_WITH_DRIVER""#)
        let (client, _) = makeClient { _ in json(body) }
        guard case .success(let plan) = try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B"))),
              let leg = plan.edges.first?.itinerary.legs.first else { return XCTFail("expected a leg") }
        XCTAssertEqual(leg.vehicle, SpiderSDK.TripVehicle(
            id: "1:V7", label: "7104", wheelchairAccessible: .possible, airConditioning: true, wifi: false, cardPayment: nil
        ))

        let unknownBody = planBody
            .replacingOccurrences(of: #""pickupType":"COORDINATE_WITH_DRIVER""#, with: unknown + #","pickupType":"COORDINATE_WITH_DRIVER""#)
        let (unknownClient, _) = makeClient { _ in json(unknownBody) }
        guard case .success(let unknownPlan) = try await unknownClient.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B"))),
              let unknownLeg = unknownPlan.edges.first?.itinerary.legs.first else { return XCTFail("expected a leg") }
        XCTAssertEqual(unknownLeg.vehicle, SpiderSDK.TripVehicle(
            id: nil, label: nil, wheelchairAccessible: nil, airConditioning: nil, wifi: nil, cardPayment: nil
        ))

        let nullBody = planBody
            .replacingOccurrences(of: #""pickupType":"COORDINATE_WITH_DRIVER""#, with: #""vehicle":null,"pickupType":"COORDINATE_WITH_DRIVER""#)
        let (nullClient, _) = makeClient { _ in json(nullBody) }
        guard case .success(let nullPlan) = try await nullClient.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B"))),
              let nullLeg = nullPlan.edges.first?.itinerary.legs.first else { return XCTFail("expected a leg") }
        XCTAssertNil(nullLeg.vehicle)
    }

    func testDeparturesAndTripMapVehicle() async throws {
        let departures = """
        {"stop":{"gtfsId":"S","name":"S","stoptimesWithoutPatterns":[
          {"serviceDay":1700000000,"serviceDate":"2023-11-14","scheduledDeparture":36000,"realtimeDeparture":36060,"realtime":true,"realtimeState":"UPDATED","pickupType":"SCHEDULED","dropoffType":"SCHEDULED","stop":{"gtfsId":"S:P2"},"trip":{"gtfsId":"T1","bikesAllowed":"ALLOWED","wheelchairAccessible":"NO_INFORMATION","route":{"gtfsId":"1:R12","mode":"BUS"}},"vehicle":{"id":"1:V7","label":null,"wheelchairAccessible":"NOT_POSSIBLE","airConditioning":false,"wifi":true,"cardPayment":true}},
          {"serviceDay":1700000000,"serviceDate":"2023-11-14","scheduledDeparture":36300,"realtimeDeparture":36300,"realtime":false,"realtimeState":"SCHEDULED","pickupType":"SCHEDULED","dropoffType":"SCHEDULED","stop":{"gtfsId":"S:P1"},"trip":{"gtfsId":"T2","bikesAllowed":"NO_INFORMATION","wheelchairAccessible":"POSSIBLE","route":{"gtfsId":"1:R5","mode":"TRAM"}},"vehicle":null}
        ]}}
        """
        let (client, _) = makeClient { _ in json(departures) }
        guard case .success(let board) = try await client.routing.departures("S") else { return XCTFail("expected success") }
        XCTAssertEqual(board[0].vehicle, SpiderSDK.TripVehicle(
            id: "1:V7", label: nil, wheelchairAccessible: .notPossible, airConditioning: false, wifi: true, cardPayment: true
        ))
        XCTAssertNil(board[0].wheelchairAccessible)
        XCTAssertNil(board[1].vehicle)

        let trip = """
        {"trip":{"gtfsId":"T1","bikesAllowed":"NOT_ALLOWED","wheelchairAccessible":"POSSIBLE","route":{"gtfsId":"1:R12","mode":"BUS"},"stoptimesForDate":[],"vehicle":{"id":"1:V9","label":"9","wheelchairAccessible":"NO_INFORMATION","airConditioning":true,"wifi":null,"cardPayment":false}}}
        """
        let (tripClient, _) = makeClient { _ in json(trip) }
        guard case .success(let details) = try await tripClient.routing.trip("T1", serviceDate: "2026-08-21") else { return XCTFail("expected success") }
        XCTAssertEqual(details.vehicle, SpiderSDK.TripVehicle(
            id: "1:V9", label: "9", wheelchairAccessible: nil, airConditioning: true, wifi: nil, cardPayment: false
        ))
        XCTAssertEqual(details.wheelchairAccessible, .possible)

        let (nullClient, _) = makeClient { _ in json(trip.replacingOccurrences(of: #""vehicle":{"id":"1:V9","label":"9","wheelchairAccessible":"NO_INFORMATION","airConditioning":true,"wifi":null,"cardPayment":false}"#, with: #""vehicle":null"#)) }
        guard case .success(let bare) = try await nullClient.routing.trip("T1", serviceDate: "2026-08-21") else { return XCTFail("expected success") }
        XCTAssertNil(bare.vehicle)
    }

    func testTripRejectsMalformedServiceDateWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json("{}") }
        for bad in ["", "20260921", "2026-09-31", "21-09-2026", "2026-09-21T00:00:00Z"] {
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
          {"serviceDay":1700000000,"scheduledArrival":36000,"scheduledDeparture":36030,"realtimeArrival":36050,"realtimeDeparture":36080,"realtime":true,"realtimeState":"UPDATED","typicalDelay":30,"stopPosition":3,"geometryIndex":2,"pickupType":"SCHEDULED","dropoffType":"COORDINATE_WITH_DRIVER","stop":{"gtfsId":"S1","name":"A","lat":49.19,"lon":16.61,"wheelchairBoarding":"POSSIBLE","platformCode":"1","zoneId":"P"}},
          {"serviceDay":1700000000,"scheduledArrival":36600,"scheduledDeparture":36600,"realtimeArrival":36600,"realtimeDeparture":36600,"realtime":false,"realtimeState":"SCHEDULED","typicalDelay":null,"stopPosition":5,"pickupType":null,"dropoffType":null,"stop":{"gtfsId":"S2","name":"B","lat":49.2,"lon":16.62,"wheelchairBoarding":"NO_INFORMATION","platformCode":null,"zoneId":null}}
        ],"tripGeometry":{"points":"_izlhA~rlgdF_{geC~ywl@_kwzCn`{nI","length":3}}}
        """
        let (client, mock) = makeClient { _ in json(body) }
        let result = try await client.routing.trip("T1", serviceDate: "2026-08-21")
        guard case .success(let trip) = result else { return XCTFail("expected success") }
        XCTAssertEqual(mock.requests[0].path, "/routing/v1/trip")
        XCTAssertEqual(mock.requests[0].httpMethod, "POST")
        XCTAssertEqual(mock.requests[0].bodyJSON as NSDictionary, ["id": "T1", "serviceDate": "2026-08-21"] as NSDictionary)
        XCTAssertEqual(trip.mode, .bus)
        XCTAssertEqual(trip.bikesAllowed, .notAllowed)
        // The requested date, not one derived from the stop times' serviceDay.
        XCTAssertEqual(trip.serviceDate, "2026-08-21")
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
        XCTAssertEqual(trip.geometry.count, 3)
        XCTAssertEqual(trip.stops.map(\.stopPosition), [3, 5])
        XCTAssertEqual(trip.geometry[trip.stops[0].geometryIndex!], LatLon(lat: 43.252, lon: -126.453))
        XCTAssertNil(trip.stops[1].geometryIndex)
        XCTAssertEqual(trip.stops[0].pickupType, .scheduled)
        XCTAssertEqual(trip.stops[0].dropoffType, .coordinateWithDriver)
        XCTAssertNil(trip.stops[1].pickupType)
        XCTAssertNil(trip.stops[1].dropoffType)
    }

    func testTripSendsReliabilityOnlyWhenSetAndUnknownTripIsNotFound() async throws {
        let (client, mock) = makeClient { _ in json(#"{"trip":null}"#) }
        let error = try await client.routing.trip("1:NOPE", serviceDate: "2026-08-21").error
        XCTAssertEqual(mock.requests[0].bodyJSON as NSDictionary, ["id": "1:NOPE", "serviceDate": "2026-08-21"] as NSDictionary)
        XCTAssertEqual(error?.code, .notFound)
        _ = try await client.routing.trip("1:NOPE", serviceDate: "2026-08-21", reliability: .safe)
        XCTAssertEqual(
            mock.requests[1].bodyJSON as NSDictionary,
            ["id": "1:NOPE", "serviceDate": "2026-08-21", "reliability": "SAFE"] as NSDictionary
        )
    }

    func testTripSendsStartTimeOnlyWhenSet() async throws {
        let (client, mock) = makeClient { _ in json(#"{"trip":null}"#) }
        _ = try await client.routing.trip("1:F1", serviceDate: "2026-08-21", startTime: "8:10:00")
        XCTAssertEqual(
            mock.requests[0].bodyJSON as NSDictionary,
            ["id": "1:F1", "serviceDate": "2026-08-21", "startTime": "8:10:00"] as NSDictionary
        )
        _ = try await client.routing.trip("1:F1", serviceDate: "2026-08-21", reliability: .standard, startTime: "25:40:00")
        XCTAssertEqual(
            mock.requests[1].bodyJSON as NSDictionary,
            ["id": "1:F1", "serviceDate": "2026-08-21", "startTime": "25:40:00", "reliability": "STANDARD"] as NSDictionary
        )
        _ = try await client.routing.trip("1:F1", serviceDate: "2026-08-21")
        _ = try await client.routing.trip("1:F1", serviceDate: "2026-08-21", startTime: "")
        XCTAssertEqual(mock.requests.count, 4)
        XCTAssertNil(mock.requests[2].bodyJSON["startTime"])
        XCTAssertNil(mock.requests[3].bodyJSON["startTime"])
    }

    func testTripAndEstimatedDelaysRejectMalformedStartTimeWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json("{}") }
        for bad in [" ", "7:0:00", "123:00:00", "08:00", "08:00:60"] {
            for error in [
                try await client.routing.trip("1:F1", serviceDate: "2026-08-21", startTime: bad).error,
                try await client.routing.estimatedDelays("1:F1", serviceDate: "2026-08-21", stopPosition: 0, startTime: bad).error,
            ] {
                XCTAssertEqual(error?.code, .badRequest, bad)
                XCTAssertEqual(error?.field, "startTime")
                XCTAssertEqual(error?.message, "startTime is invalid")
            }
        }
        XCTAssertTrue(mock.requests.isEmpty)
    }

    func testEstimatedDelaysSendsStartTimeOnlyWhenSet() async throws {
        let (client, mock) = makeClient { _ in json(#"{"estimatedDelays":null}"#) }
        let result = try await client.routing.estimatedDelays("1:F1", serviceDate: "2026-08-21", stopPosition: 2, startTime: "08:10:00")
        guard case .success(let delays) = result else { return XCTFail("expected success") }
        XCTAssertNil(delays)
        XCTAssertEqual(mock.requests[0].url?.query, "tripId=1:F1&serviceDate=2026-08-21&stopPosition=2&startTime=08:10:00")
        _ = try await client.routing.estimatedDelays("1:F1", serviceDate: "2026-08-21", stopPosition: 2)
        _ = try await client.routing.estimatedDelays("1:F1", serviceDate: "2026-08-21", stopPosition: 2, startTime: "")
        XCTAssertEqual(mock.requests[1].url?.query, "tripId=1:F1&serviceDate=2026-08-21&stopPosition=2")
        XCTAssertEqual(mock.requests[2].url?.query, "tripId=1:F1&serviceDate=2026-08-21&stopPosition=2")
    }

    func testEstimatedDelaysGetsByQueryAndMapsByLevel() async throws {
        // Entries out of order: mapped by `reliability`, not position.
        let body = #"{"estimatedDelays":[{"reliability":"VERY_SAFE","delay":240},{"reliability":"STANDARD","delay":0},{"reliability":"SAFE","delay":90}]}"#
        let (client, mock) = makeClient { _ in json(body) }
        let result = try await client.routing.estimatedDelays("1:T 1", serviceDate: "2026-08-21", stopPosition: 3)
        guard case .success(let delays?) = result else { return XCTFail("expected delays") }
        XCTAssertEqual(delays, EstimatedDelays(standardSeconds: 0, safeSeconds: 90, verySafeSeconds: 240))
        let req = mock.requests[0]
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertEqual(req.url?.absoluteString, "https://env.api.example.com/routing/v1/estimated-delays?tripId=1:T%201&serviceDate=2026-08-21&stopPosition=3")
        XCTAssertEqual(req.value(forHTTPHeaderField: "apikey"), "secret-key")
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-spider-contract-version"), "1.11")
        XCTAssertNotNil(req.value(forHTTPHeaderField: "x-spider-sdk"))
        XCTAssertNil(req.value(forHTTPHeaderField: "if-none-match"))
    }

    func testEstimatedDelaysNullIsSuccess() async throws {
        let (client, _) = makeClient { _ in json(#"{"estimatedDelays":null}"#) }
        let result = try await client.routing.estimatedDelays("1:NOPE", serviceDate: "2026-08-21", stopPosition: 0)
        guard case .success(let delays) = result else { return XCTFail("expected success") }
        XCTAssertNil(delays)
    }

    func testEstimatedDelaysMissingOrUnknownLevelIsDecodingFailure() async throws {
        for entries in [
            #"[{"reliability":"STANDARD","delay":0},{"reliability":"SAFE","delay":90}]"#,
            #"[{"reliability":"STANDARD","delay":0},{"reliability":"SAFE","delay":90},{"reliability":"P99","delay":300}]"#,
        ] {
            let (client, _) = makeClient { _ in json(#"{"estimatedDelays":\#(entries)}"#) }
            let result = try await client.routing.estimatedDelays("1:T1", serviceDate: "2026-08-21", stopPosition: 0)
            XCTAssertEqual(result.error?.code, .decoding, entries)
        }
    }

    func testEstimatedDelaysRejectsMalformedServiceDateWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json("{}") }
        for bad in ["", "20260821", "2026-02-30"] {
            let error = try await client.routing.estimatedDelays("1:T1", serviceDate: bad, stopPosition: 0).error
            XCTAssertEqual(error?.code, .badRequest)
            XCTAssertEqual(error?.field, "serviceDate")
            XCTAssertEqual(error?.message, "serviceDate is invalid")
        }
        XCTAssertTrue(mock.requests.isEmpty)
    }

    func testEstimatedDelays400IsBadRequestWithField() async throws {
        let (client, _) = makeClient { _ in
            json(#"{"code":"bad_request","message":"stopPosition is invalid","field":"stopPosition"}"#, status: 400)
        }
        let error = try await client.routing.estimatedDelays("1:T1", serviceDate: "2026-08-21", stopPosition: -1).error
        XCTAssertEqual(error?.code, .badRequest)
        XCTAssertEqual(error?.field, "stopPosition")
    }
}
