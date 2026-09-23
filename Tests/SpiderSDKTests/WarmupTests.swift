import Foundation
import XCTest
@testable import SpiderSDK

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class WarmupTests: XCTestCase {
    func testWarmupGetsPingKeylessAndReturnsElapsed() async throws {
        let (client, mock) = makeClient { _ in json("pong") }
        let elapsed = await client.warmup()
        let req = mock.requests[0]
        XCTAssertEqual(req.path, "/ping")
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertNil(req.value(forHTTPHeaderField: "apikey")) // /ping is keyless
        XCTAssertGreaterThanOrEqual(elapsed, 0)
    }

    func testWarmupSwallows404AndStillReturns() async throws {
        // A 404 (before the gateway /ping route deploys) still warms the connection and must not throw.
        let (client, mock) = makeClient { _ in json("not found", status: 404) }
        let elapsed = await client.warmup()
        XCTAssertEqual(mock.requests[0].path, "/ping")
        XCTAssertGreaterThanOrEqual(elapsed, 0)
    }

    func testWarmupSwallowsTransportError() async throws {
        struct Boom: Error {}
        let mock = ThrowingHTTPClient(error: Boom())
        let client = SpiderClient(baseURL: "https://env.api.example.com", apiKey: "secret-key", options: SpiderClientOptions(httpClient: mock))
        let elapsed = await client.warmup() // must not throw
        XCTAssertGreaterThanOrEqual(elapsed, 0)
    }
}

private final class ThrowingHTTPClient: HTTPClient, @unchecked Sendable {
    let error: Error
    init(error: Error) { self.error = error }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) { throw error }
}
