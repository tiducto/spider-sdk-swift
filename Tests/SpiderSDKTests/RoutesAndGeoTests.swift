import XCTest
@testable import SpiderSDK

final class StopsGeoTests: XCTestCase {
    func testNearSetsDistanceSortAndGeoRadius() async throws {
        let (client, mock) = makeClient { _ in json(#"{"hits":[]}"#) }
        _ = try await client.stops.near(49.2, 16.6, radiusMeters: 300)
        let req = mock.requests[0]
        XCTAssertEqual(req.path, "/stops/search")
        XCTAssertEqual(req.bodyJSON["sort"] as? [String], ["_geoPoint(49.2, 16.6):asc"])
        XCTAssertEqual(req.bodyJSON["filter"] as? String, "_geoRadius(49.2, 16.6, 300.0)")
    }

    func testWithinBuildsBoundingBoxFilter() async throws {
        let (client, mock) = makeClient { _ in json(#"{"hits":[]}"#) }
        _ = try await client.stops.within(GeoBoundingBox(minLat: 49.1, minLng: 16.5, maxLat: 49.3, maxLng: 16.7))
        XCTAssertEqual(mock.requests[0].bodyJSON["filter"] as? String, "_geoBoundingBox([49.3, 16.7], [49.1, 16.5])")
    }

    func testStopByIdBuildsGtfsIdFilterAndReturnsHit() async throws {
        let body = #"{"hits":[{"gtfsId":"U123Z1","name":"Main","city":"Brno"}]}"#
        let (client, mock) = makeClient { _ in json(body) }
        let stop = try await client.stops.byId("U123Z1")
        XCTAssertEqual(stop?.gtfsId, "U123Z1")
        XCTAssertEqual(stop?.city, "Brno")
        XCTAssertEqual(mock.requests[0].bodyJSON["filter"] as? String, #""gtfsId" = "U123Z1""#)
        XCTAssertEqual(mock.requests[0].bodyJSON["limit"] as? Int, 1)
    }

    func testStopByIdReturnsNilWhenNoHit() async throws {
        let (client, _) = makeClient { _ in json(#"{"hits":[]}"#) }
        let stop = try await client.stops.byId("nope")
        XCTAssertNil(stop)
    }

    func testRadiusWithoutAnchorFailsWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json(#"{"hits":[]}"#) }
        let result = try await client.stops.search(StopFilter(radiusMeters: 300))
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertTrue(error.message.contains("`near`"))
        XCTAssertTrue(mock.requests.isEmpty) // validation short-circuits before any network call
    }
}
