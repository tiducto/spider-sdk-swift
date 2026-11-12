import XCTest
@testable import SpiderSDK

final class PlacesTests: XCTestCase {
    private func queryItems(_ request: URLRequest) -> [URLQueryItem] {
        URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }

    func testSearchGetsQueryAndLimitWithDefaultTen() async throws {
        let (client, mock) = makeClient { _ in json(#"{"hits":[],"query":"brno"}"#) }
        let result = try await client.places.search("Hlavní nádraží")
        guard case .success(let hits) = result else { return XCTFail("expected success") }
        XCTAssertEqual(hits, [])
        let req = mock.requests[0]
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertEqual(req.path, "/places/v1/search")
        XCTAssertNil(req.httpBody)
        XCTAssertEqual(queryItems(req), [URLQueryItem(name: "q", value: "Hlavní nádraží"), URLQueryItem(name: "limit", value: "10")])
        XCTAssertEqual(req.value(forHTTPHeaderField: "apikey"), "secret-key")
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-spider-sdk"), "swift/1.9.0")
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-spider-contract-version"), "1.9")
    }

    func testSearchNearSendsLatitudeAndLongitude() async throws {
        let (client, mock) = makeClient { _ in json(#"{"hits":[],"query":"brno"}"#) }
        _ = try await client.places.search("Údolní 53", near: GeoPoint(lat: 49.1951, lng: 16.6068), limit: 5)
        let req = mock.requests[0]
        XCTAssertEqual(queryItems(req), [
            URLQueryItem(name: "q", value: "Údolní 53"),
            URLQueryItem(name: "limit", value: "5"),
            URLQueryItem(name: "latitude", value: "49.1951"),
            URLQueryItem(name: "longitude", value: "16.6068"),
        ])
        // Diacritics and the space are percent-encoded on the wire.
        let raw = req.url!.absoluteString
        XCTAssertTrue(raw.contains("q=%C3%9Adoln%C3%AD%2053"), raw)
    }

    func testSearchNearSendsSmallCoordinatesInPlainDecimal() async throws {
        let (client, mock) = makeClient { _ in json(#"{"hits":[],"query":"brno"}"#) }
        _ = try await client.places.search("Greenwich", near: GeoPoint(lat: 51.4779, lng: -0.00001))
        let items = queryItems(mock.requests[0])
        XCTAssertEqual(items.first { $0.name == "longitude" }?.value, "-0.00001")
    }

    func testSearchMapsHitsWithLabelsDistanceAndCategory() async throws {
        let body = """
        {"hits":[
          {"id":"1:U1234Z1","type":"stop","gtfsId":"1:U1234Z1","name":"Hlavní nádraží","code":"1","wheelchairBoarding":1,"modes":["TRAM","BUS","HOVERCRAFT"],"lat":49.190612,"lon":16.612951,"country":"Česko","region":"Jihomoravský kraj","district":"okres Brno-město","city":"Brno","suburb":"Brno-střed","distance":670},
          {"id":"osm-w29239083","type":"poi","name":"Vaňkovka","lat":49.18904,"lon":16.614627,"category":"mall","city":"Brno","distance":882},
          {"id":"ruian-19153635","type":"address","name":"Údolní 244/53","lat":49.198361,"lon":16.594827,"category":"building"},
          {"id":"ruian-1","type":"street","name":"Údolní","lat":49.1,"lon":16.5,"category":"street"},
          {"id":"ruian-2","type":"place","name":"Brno","lat":49.2,"lon":16.6,"category":"municipality","futureField":{"x":1}},
          {"id":"x-9","type":"ferry_terminal","name":"Something new","lat":49.3,"lon":16.7}
        ],"query":"brno"}
        """
        let (client, _) = makeClient { _ in json(body) }
        let hits = try await client.places.search("brno").get()
        XCTAssertEqual(hits.map(\.type), [.stop, .poi, .address, .unknown, .place, .unknown])
        XCTAssertEqual(hits[0], PlaceHit(
            id: "1:U1234Z1", type: .stop, name: "Hlavní nádraží", lat: 49.190612, lon: 16.612951, category: nil,
            country: "Česko", region: "Jihomoravský kraj", district: "okres Brno-město", city: "Brno",
            suburb: "Brno-střed", distance: 670,
            stop: Stop(
                gtfsId: "1:U1234Z1", name: "Hlavní nádraží", code: "1", wheelchairBoarding: .possible,
                modes: [.tram, .bus, .unknown], lat: 49.190612, lon: 16.612951, country: "Česko",
                region: "Jihomoravský kraj", district: "okres Brno-město", city: "Brno", suburb: "Brno-střed"
            )
        ))
        XCTAssertEqual(hits[1...].map(\.stop), [nil, nil, nil, nil, nil]) // only a stop carries one
        XCTAssertEqual(hits[1].category, "mall")
        XCTAssertEqual(hits[1].distance, 882)
        XCTAssertNil(hits[1].suburb)
        XCTAssertNil(hits[2].distance) // only with a location
        XCTAssertNil(hits[2].city)
        XCTAssertEqual(hits[4].category, "municipality") // unknown keys are ignored
        XCTAssertEqual(hits[5].name, "Something new")
    }

    func testSearchRejectsLimitOutOfRangeWithoutRequest() async throws {
        let (client, mock) = makeClient { _ in json(#"{"hits":[],"query":"brno"}"#) }
        for bad in [0, -1, 21] {
            let result = try await client.places.search("brno", limit: bad)
            guard case .failure(let error) = result else { return XCTFail("expected failure for \(bad)") }
            XCTAssertEqual(error.code, .badRequest)
            XCTAssertEqual(error.field, "limit")
            XCTAssertEqual(error.message, "limit is out of range")
        }
        XCTAssertTrue(mock.requests.isEmpty)
        for good in [1, 20] {
            _ = try await client.places.search("brno", limit: good)
        }
        XCTAssertEqual(mock.requests.map { req in queryItems(req).first { $0.name == "limit" }?.value }, ["1", "20"])
    }

    func testSearch400IsBadRequestWithTheBodyField() async throws {
        let (client, _) = makeClient { _ in
            json(#"{"code":"bad_request","message":"longitude is required","field":"longitude"}"#, status: 400)
        }
        let result = try await client.places.search("brno")
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .badRequest)
        XCTAssertEqual(error.httpStatus, 400)
        XCTAssertEqual(error.serverCode, "bad_request")
        XCTAssertEqual(error.field, "longitude")
        XCTAssertTrue(error.message.contains("longitude is required"), error.message)
    }

    func testSearchErrorEnvelopesMapToTypedErrors() async throws {
        let cases: [(Int, String, SpiderErrorCode)] = [
            (401, "key_invalid", .unauthorized),
            (403, "key_not_allowed", .unauthorized),
            (429, "rate_limited", .rateLimited),
            (503, "upstream_unavailable", .server),
        ]
        for (status, code, expected) in cases {
            let (client, _) = makeClient { _ in json(#"{"code":"\#(code)","message":"refused"}"#, status: status) }
            let result = try await client.places.search("brno")
            guard case .failure(let error) = result else { return XCTFail("expected failure for \(status)") }
            XCTAssertEqual(error.code, expected, "\(status)")
            XCTAssertEqual(error.serverCode, code, "\(status)")
            XCTAssertNil(error.field, "\(status)")
        }
    }

    func testSearchMissingRequiredMemberIsDecodingFailure() async throws {
        let (client, _) = makeClient { _ in json(#"{"hits":[{"id":"a","name":"No type","lat":1,"lon":2}],"query":"brno"}"#) }
        let result = try await client.places.search("brno")
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(error.code, .decoding)
    }
}
