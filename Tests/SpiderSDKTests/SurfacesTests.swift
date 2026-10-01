import XCTest
@testable import SpiderSDK

final class StopsTests: XCTestCase {
    func testSearchBuildsFilterExpressionWithEscapingAndMapsHits() async throws {
        let body = """
        {"hits":[{"gtfsId":"S1","name":"Main","code":"1234","locationType":1,"wheelchairBoarding":2,"modes":["BUS","TRAM","HOVERCRAFT"],"lat":49.1,"lon":16.6,"country":"CZ","city":"Brno"},
                 {"gtfsId":"S2","name":"Side","wheelchairBoarding":0},
                 {"gtfsId":"S3","name":"Odd","wheelchairBoarding":7}],"query":"Main"}
        """
        let (client, mock) = makeClient { _ in json(body) }
        let result = try await client.stops.search(StopFilter(name: "Main", country: "CZ", city: "Br\"no"))
        guard case .success(let stops) = result else { return XCTFail("expected success") }
        XCTAssertEqual(stops.count, 3)
        XCTAssertEqual(stops[0].gtfsId, "S1")
        XCTAssertEqual(stops[0].city, "Brno")
        XCTAssertEqual(stops[0].code, "1234")
        XCTAssertEqual(stops[0].locationType, 1)
        XCTAssertEqual(stops[0].wheelchairBoarding, .notPossible)
        XCTAssertEqual(stops[0].modes, [.bus, .tram, .unknown]) // a mode this SDK doesn't know -> unknown
        // Absent fields stay nil (modes empty); GTFS 0 (no information) maps to nil like routing's NO_INFORMATION.
        XCTAssertNil(stops[1].code)
        XCTAssertNil(stops[1].locationType)
        XCTAssertNil(stops[1].wheelchairBoarding)
        XCTAssertEqual(stops[1].modes, [])
        XCTAssertEqual(stops[2].wheelchairBoarding, .unknown) // a code GTFS doesn't define

        let req = mock.requests[0]
        XCTAssertEqual(req.path, "/stops/search")
        XCTAssertEqual(req.bodyJSON["q"] as? String, "Main")
        // country then city (fixed admin-key order); the quote in "Br\"no" is backslash-escaped.
        XCTAssertEqual(req.bodyJSON["filter"] as? String, #""country" = "CZ" AND "city" = "Br\"no""#)
    }

    func testSearchWithOnlyNameOmitsFilterAndSendsDefaultLimit() async throws {
        let (client, mock) = makeClient { _ in json(#"{"hits":[]}"#) }
        _ = try await client.stops.search(StopFilter(name: "Main"))
        XCTAssertEqual(mock.requests[0].bodyJSON["q"] as? String, "Main")
        XCTAssertNil(mock.requests[0].bodyJSON["filter"]) // omitted when no admin fields
        XCTAssertEqual(mock.requests[0].bodyJSON["limit"] as? Int, 20) // required on the wire, always sent
    }

    func testSearchModesFilterMatchesAnyOfTheModes() async throws {
        let (client, mock) = makeClient { _ in json(#"{"hits":[]}"#) }
        _ = try await client.stops.search(StopFilter(city: "Brno", modes: [.rail, .tram]))
        XCTAssertEqual(mock.requests[0].bodyJSON["filter"] as? String, #""city" = "Brno" AND "modes" IN ["RAIL", "TRAM"]"#)
    }

    func testSearchRejectsLimitOutOfRangeWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json(#"{"hits":[]}"#) }
        for bad in [0, -1, 51] {
            let result = try await client.stops.search(StopFilter(name: "x", limit: bad))
            guard case .failure(let error) = result else { return XCTFail("expected failure for \(bad)") }
            XCTAssertEqual(error.code, .badRequest)
            XCTAssertEqual(error.field, "limit")
            XCTAssertEqual(error.message, "limit is out of range")
        }
        XCTAssertTrue(mock.requests.isEmpty)
        for good in [1, 50] {
            _ = try await client.stops.search(StopFilter(name: "x", limit: good))
        }
        XCTAssertEqual(mock.requests.map { $0.bodyJSON["limit"] as? Int }, [1, 50])
    }

    // The gateway's 400 for an invalid stop-search body is a bad request naming the field.
    func testSearchGateway400IsBadRequest() async throws {
        let (client, _) = makeClient { _ in json(#"{"error":"bad_request","message":"limit is out of range"}"#, status: 400) }
        let result = try await client.stops.search(StopFilter(name: "x"))
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .badRequest)
        XCTAssertEqual(error.httpStatus, 400)
        XCTAssertEqual(error.field, "limit")
        XCTAssertTrue(error.message.contains("limit is out of range"))
    }

    // Only the fixed `<field> is …` shapes name a field; any other 400 message is still a bad request.
    func testSearchGateway400FieldOnlyFromFixedMessageShapes() async throws {
        let cases: [(String, String?)] = [
            ("limit is required", "limit"),
            ("filter is invalid", "filter"),
            ("limit must be an integer", nil),
            ("bad input is out of range", nil),
        ]
        for (message, field) in cases {
            let (client, _) = makeClient { _ in json(#"{"error":"bad_request","message":"\#(message)"}"#, status: 400) }
            guard case .failure(let error) = try await client.stops.search(StopFilter(name: "x")) else {
                return XCTFail("expected failure for \(message)")
            }
            XCTAssertEqual(error.code, .badRequest)
            XCTAssertEqual(error.field, field, message)
        }
    }

    func testSearchSurfacesServerErrorMessage() async throws {
        let (client, _) = makeClient { _ in json(#"{"message":"index missing"}"#, status: 500) }
        let result = try await client.stops.search(StopFilter(name: "x"))
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .server)
        XCTAssertTrue(error.message.contains("index missing"))
    }
}

final class RealtimeTests: XCTestCase {
    func testVehiclesMapsAndConvertsSecondsToMillis() async throws {
        let body = """
        {"vehicles":[{"tripId":"1:T1","vehicleId":"1:V7","latitude":49.1,"longitude":16.6,"bearing":90.0,"speed":10.0,"occupancyStatus":"FEW_SEATS_AVAILABLE","timestamp":1700000000}],"missing":["T9"],"feedTimestamp":1700000000,"staleSeconds":3.5}
        """
        let (client, mock) = makeClient { _ in json(body) }
        let result = try await client.realtime.vehicles(["T1", "T9"])
        guard case .success(let positions) = result else { return XCTFail("expected success") }
        XCTAssertEqual(positions.vehicles.count, 1)
        XCTAssertEqual(positions.vehicles[0].vehicleId, "1:V7") // feed-prefixed ids pass through untouched
        XCTAssertEqual(positions.vehicles[0].timestampEpochMs, 1_700_000_000 * 1000)
        XCTAssertEqual(positions.vehicles[0].occupancy, .fewSeatsAvailable)
        XCTAssertEqual(positions.missing, ["T9"])
        XCTAssertEqual(positions.freshness.feedTimestampEpochMs, 1_700_000_000 * 1000)
        XCTAssertEqual(positions.freshness.staleSeconds, 3.5)
        // CSV query param.
        XCTAssertEqual(mock.requests[0].url?.query, "tripIds=T1,T9")
    }

    func testVehiclesWithNoTripIdsIsEmptySuccessWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json(#"{"vehicles":[],"missing":[]}"#) }
        let result = try await client.realtime.vehicles([])
        guard case .success(let positions) = result else { return XCTFail("expected success") }
        XCTAssertEqual(positions.vehicles, [])
        XCTAssertEqual(positions.missing, [])
        XCTAssertTrue(mock.requests.isEmpty)
    }

    // At most 50 trip ids per request is a fixed platform limit, checked before sending.
    func testVehiclesRejectsMoreThanFiftyTripIdsWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json(#"{"vehicles":[],"missing":[]}"#) }
        let result = try await client.realtime.vehicles((0..<51).map { "T\($0)" })
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .badRequest)
        XCTAssertEqual(error.field, "tripIds")
        XCTAssertEqual(error.message, "tripIds is out of range")
        XCTAssertTrue(mock.requests.isEmpty)
        let fifty = try await client.realtime.vehicles((0..<50).map { "T\($0)" })
        XCTAssertTrue(fifty.isSuccess)
        XCTAssertEqual(mock.requests.count, 1)
    }

    // The realtime service answers an invalid input with a plain-text 400 naming the field.
    func testRealtime400IsBadRequestWithField() async throws {
        let (client, _) = makeClient { _ in json("tripIds is out of range", status: 400) }
        let result = try await client.realtime.vehicles(["T1"])
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .badRequest)
        XCTAssertEqual(error.field, "tripIds")
        XCTAssertTrue(error.message.contains("tripIds is out of range"))

        let (tripClient, _) = makeClient { _ in json("tripId is invalid\n", status: 400) }
        guard case .failure(let byTrip) = try await tripClient.realtime.vehicleForTrip("T1") else { return XCTFail("expected failure") }
        XCTAssertEqual(byTrip.code, .badRequest)
        XCTAssertEqual(byTrip.field, "tripId")

        let (delaysClient, _) = makeClient { _ in json("serviceDate is invalid", status: 400) }
        guard case .failure(let delays) = try await delaysClient.realtime.delays(["T1"], serviceDate: "2026-01-01") else {
            return XCTFail("expected failure")
        }
        XCTAssertEqual(delays.code, .badRequest)
        XCTAssertEqual(delays.field, "serviceDate")
    }

    // A field is named only on a bad request, never on another status whose message happens to match.
    func testNon400ErrorCarriesNoField() async throws {
        let (client, _) = makeClient { _ in json("tripIds is out of range", status: 500) }
        guard case .failure(let error) = try await client.realtime.vehicles(["T1"]) else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .server)
        XCTAssertNil(error.field)
    }

    func testVehicleForTrip404IsSoftNull() async throws {
        let (client, _) = makeClient { _ in json("{}", status: 404) }
        let result = try await client.realtime.vehicleForTrip("T1")
        guard case .success(let update) = result else { return XCTFail("expected success") }
        XCTAssertNil(update.vehicle)
    }

    func testDelaysGroupByServiceDateAndPostGroupedRequest() async throws {
        let delaysBody = """
        {"results":[{"serviceDate":"2026-01-01","delays":[{"tripId":"T1","routeId":"R1","delaySeconds":120,"scheduleRelationship":"SCHEDULED","stopTimeUpdates":[{"stopId":"S1","arrivalDelay":60,"departureDelay":90}]}],"missing":["T2"]}],"feedTimestamp":1700000000,"staleSeconds":1.0}
        """
        let (client, mock) = makeClient { _ in json(delaysBody) }
        let result = try await client.realtime.delays(["T1", "T2"], serviceDate: "2026-01-01")
        guard case .success(let delays) = result else { return XCTFail("expected success") }

        // Grouped domain + per-instance lookup.
        XCTAssertEqual(delays.groups.count, 1)
        XCTAssertEqual(delays.groups[0].serviceDate, "2026-01-01")
        XCTAssertEqual(delays.groups[0].missing, ["T2"])
        let delay = delays.delayFor(tripId: "T1", serviceDate: "2026-01-01")
        XCTAssertEqual(delay?.delaySeconds, 120) // seconds NOT converted
        XCTAssertEqual(delay?.stopTimeUpdates[0].arrivalDelay, 60)
        XCTAssertNil(delays.delayFor(tripId: "T1", serviceDate: "2026-01-02")) // wrong instance → nil

        // Grouped POST request body.
        let req = mock.requests[0]
        XCTAssertEqual(req.path, "/realtime/delays")
        XCTAssertEqual(req.httpMethod, "POST")
        let queries = req.bodyJSON["queries"] as! [[String: Any]]
        XCTAssertEqual(queries[0]["serviceDate"] as? String, "2026-01-01")
        XCTAssertEqual(queries[0]["tripIds"] as? [String], ["T1", "T2"])
    }

    func testDelaysWithNoTripIdsIsEmptySuccessWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json(#"{"results":[]}"#) }
        let empty: [[String: [String]]] = [[:], ["2026-01-01": []], ["2026-01-01": [], "2026-01-02": []]]
        for byDate in empty {
            let result = try await client.realtime.delays(byServiceDate: byDate)
            guard case .success(let delays) = result else { return XCTFail("expected success for \(byDate)") }
            XCTAssertEqual(delays.groups, [])
        }
        let single = try await client.realtime.delays([], serviceDate: "2026-01-01")
        XCTAssertEqual(single.value?.groups, [])
        XCTAssertTrue(mock.requests.isEmpty)
    }

    // The 50-id limit counts trip ids across every service-date group of one request.
    func testDelaysRejectsTripIdCountAcrossGroupsWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json(#"{"results":[]}"#) }
        let ids = { (prefix: String, count: Int) in (0..<count).map { "\(prefix)\($0)" } }
        let result = try await client.realtime.delays(byServiceDate: ["2026-01-01": ids("A", 30), "2026-01-02": ids("B", 21)])
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .badRequest)
        XCTAssertEqual(error.field, "tripIds")
        XCTAssertEqual(error.message, "tripIds is out of range")
        XCTAssertTrue(mock.requests.isEmpty)
        let fifty = try await client.realtime.delays(byServiceDate: ["2026-01-01": ids("A", 25), "2026-01-02": ids("B", 25)])
        XCTAssertTrue(fifty.isSuccess)
        XCTAssertEqual(mock.requests.count, 1)
    }

    func testDelaysRejectsMalformedServiceDateWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json("{}") }
        for bad in ["20260101", "2026-13-01", "2026-02-30", "2026-1-01", ""] {
            let result = try await client.realtime.delays(byServiceDate: ["2026-01-01": ["T1"], bad: ["T2"]])
            guard case .failure(let error) = result else { return XCTFail("expected failure for \(bad)") }
            XCTAssertEqual(error.code, .badRequest)
            XCTAssertEqual(error.field, "serviceDate")
            XCTAssertEqual(error.message, "serviceDate is invalid")
        }
        XCTAssertTrue(mock.requests.isEmpty)
    }
}

final class EnumsAndPolylineTests: XCTestCase {
    // Every enum decodes a value it doesn't know to `.unknown`; the wire's "nothing known" values decode to nil.
    func testEnumMapping() {
        XCTAssertEqual(TransitMode.fromWire("BUS"), .bus)
        XCTAssertEqual(TransitMode.fromWire("SOMETHING_NEW"), .unknown)
        XCTAssertNil(TransitMode.fromWire(nil))
        XCTAssertEqual(WheelchairBoarding.fromWire("POSSIBLE"), .possible)
        XCTAssertEqual(WheelchairBoarding.fromWire("NOT_POSSIBLE"), .notPossible)
        XCTAssertEqual(WheelchairBoarding.fromWire("SOMETHING_NEW"), .unknown)
        XCTAssertNil(WheelchairBoarding.fromWire("NO_INFORMATION"))
        XCTAssertNil(WheelchairBoarding.fromWire(nil))
        XCTAssertEqual(BikesAllowed.fromWire("ALLOWED"), .allowed)
        XCTAssertEqual(BikesAllowed.fromWire("NOT_ALLOWED"), .notAllowed)
        XCTAssertEqual(BikesAllowed.fromWire("SOMETHING_NEW"), .unknown)
        XCTAssertNil(BikesAllowed.fromWire("NO_INFORMATION"))
        XCTAssertNil(BikesAllowed.fromWire(nil))
        XCTAssertNil(OccupancyStatus.fromWire("NO_DATA_AVAILABLE"))
        XCTAssertEqual(OccupancyStatus.fromWire("WEIRD"), .unknown)
        XCTAssertEqual(RealtimeState.fromWire("WEIRD"), .unknown)
        XCTAssertEqual(RoutingErrorCode.fromWire("WEIRD"), .unknown)
        XCTAssertEqual(InputField.fromWire("WEIRD"), .unknown)
        // LOCATION_NOT_FOUND names FROM / TO / VIA; OTP's internal FROM_PLACE is not a wire value.
        XCTAssertEqual(InputField.fromWire("FROM"), .from)
        XCTAssertEqual(InputField.fromWire("TO"), .to)
        XCTAssertEqual(InputField.fromWire("VIA"), .via)
        XCTAssertEqual(InputField.fromWire("FROM_PLACE"), .unknown)
    }

    func testPolylineDecodesGoogleExample() {
        let points = decodePolyline("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
        XCTAssertEqual(points.count, 3)
        XCTAssertEqual(points[0].lat, 38.5, accuracy: 1e-5)
        XCTAssertEqual(points[0].lon, -120.2, accuracy: 1e-5)
        XCTAssertEqual(points[2].lat, 43.252, accuracy: 1e-5)
        XCTAssertEqual(points[2].lon, -126.453, accuracy: 1e-5)
    }

    func testPolylineTruncationTolerant() {
        XCTAssertEqual(decodePolyline("").count, 0)
        XCTAssertEqual(decodePolyline("_p~iF").count, 0) // half a point -> nothing complete
    }

    func testClientExposesContractVersion() {
        let (client, _) = makeClient { _ in json("{}") }
        XCTAssertEqual(client.contractVersion, "1.0")
    }
}
