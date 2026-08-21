import XCTest
@testable import SpiderSDK

final class StopsTests: XCTestCase {
    func testSearchBuildsFilterExpressionWithEscapingAndMapsHits() async throws {
        let body = """
        {"hits":[{"gtfsId":"S1","name":"Main","lat":49.1,"lon":16.6,"country":"CZ","city":"Brno"}],"query":"Main"}
        """
        let (client, mock) = makeClient { _ in json(body) }
        let result = try await client.stops.search(StopFilter(name: "Main", country: "CZ", city: "Br\"no"))
        guard case .success(let stops) = result else { return XCTFail("expected success") }
        XCTAssertEqual(stops.count, 1)
        XCTAssertEqual(stops[0].gtfsId, "S1")
        XCTAssertEqual(stops[0].city, "Brno")

        let req = mock.requests[0]
        XCTAssertEqual(req.path, "/stops/search")
        XCTAssertEqual(req.bodyJSON["q"] as? String, "Main")
        // country then city (fixed admin-key order); the quote in "Br\"no" is backslash-escaped.
        XCTAssertEqual(req.bodyJSON["filter"] as? String, #""country" = "CZ" AND "city" = "Br\"no""#)
    }

    func testSearchWithOnlyNameOmitsFilter() async throws {
        let (client, mock) = makeClient { _ in json(#"{"hits":[]}"#) }
        _ = try await client.stops.search(StopFilter(name: "Main"))
        XCTAssertEqual(mock.requests[0].bodyJSON["q"] as? String, "Main")
        XCTAssertNil(mock.requests[0].bodyJSON["filter"]) // omitted when no admin fields
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
        {"vehicles":[{"tripId":"T1","latitude":49.1,"longitude":16.6,"bearing":90.0,"speed":10.0,"occupancyStatus":"FEW_SEATS_AVAILABLE","timestamp":1700000000}],"missing":["T9"],"feedTimestamp":1700000000,"staleSeconds":3.5}
        """
        let (client, mock) = makeClient { _ in json(body) }
        let result = try await client.realtime.vehicles(["T1", "T9"])
        guard case .success(let positions) = result else { return XCTFail("expected success") }
        XCTAssertEqual(positions.vehicles.count, 1)
        XCTAssertEqual(positions.vehicles[0].timestampEpochMs, 1_700_000_000 * 1000)
        XCTAssertEqual(positions.vehicles[0].occupancy, .fewSeatsAvailable)
        XCTAssertEqual(positions.missing, ["T9"])
        XCTAssertEqual(positions.freshness.feedTimestampEpochMs, 1_700_000_000 * 1000)
        XCTAssertEqual(positions.freshness.staleSeconds, 3.5)
        // CSV query param.
        XCTAssertEqual(mock.requests[0].url?.query, "tripIds=T1,T9")
    }

    func testVehiclesEmptyShortCircuitsWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json("{}") }
        let result = try await client.realtime.vehicles([])
        guard case .success(let positions) = result else { return XCTFail("expected success") }
        XCTAssertTrue(positions.vehicles.isEmpty)
        XCTAssertTrue(mock.requests.isEmpty) // no network call
    }

    func testVehicleForTrip404IsSoftNull() async throws {
        let (client, _) = makeClient { _ in json("{}", status: 404) }
        let result = try await client.realtime.vehicleForTrip("T1")
        guard case .success(let update) = result else { return XCTFail("expected success") }
        XCTAssertNil(update.vehicle)
    }

    func testDelaysAndAlertsMap() async throws {
        let delaysBody = """
        {"delays":[{"tripId":"T1","routeId":"R1","delaySeconds":120,"scheduleRelationship":"SCHEDULED","stopTimeUpdates":[{"stopId":"S1","arrivalDelay":60,"departureDelay":90}]}],"missing":[],"feedTimestamp":1700000000,"staleSeconds":1.0}
        """
        let (client, _) = makeClient { _ in json(delaysBody) }
        let result = try await client.realtime.delays(["T1"])
        guard case .success(let delays) = result else { return XCTFail("expected success") }
        XCTAssertEqual(delays.delays[0].delaySeconds, 120) // seconds NOT converted
        XCTAssertEqual(delays.delays[0].stopTimeUpdates[0].arrivalDelay, 60)
    }
}

final class EnumsAndPolylineTests: XCTestCase {
    func testOpenAndClosedEnumMapping() {
        XCTAssertEqual(TransitMode.fromWire("BUS"), .bus)
        XCTAssertEqual(TransitMode.fromWire("SOMETHING_NEW"), .unknown) // open -> unknown
        XCTAssertNil(TransitMode.fromWire(nil))
        XCTAssertEqual(WheelchairBoarding.fromWire("POSSIBLE"), .possible)
        XCTAssertNil(WheelchairBoarding.fromWire("NO_INFORMATION")) // closed -> nil
        XCTAssertEqual(BikesAllowed.fromWire("NOT_ALLOWED"), .notAllowed)
        XCTAssertNil(OccupancyStatus.fromWire("NO_DATA_AVAILABLE")) // normalized to nil
        XCTAssertEqual(OccupancyStatus.fromWire("WEIRD"), .unknown)
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
        XCTAssertEqual(client.contractVersion, "5.0")
    }
}
