import Foundation
@testable import SpiderSDK

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A recording `HTTPClient` for tests. `handler` decides the response from the request; every request is
/// captured for later inspection. Responses carry the `x-spider-contract-version: 5.0` header by default so
/// the contract check passes.
final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    struct Response {
        var status: Int = 200
        var headers: [String: String] = ["x-spider-contract-version": "5.0"]
        var body: Data
    }

    private let lock = NSLock()
    private var _requests: [URLRequest] = []
    private let handler: @Sendable (URLRequest) -> Response

    var requests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return _requests
    }

    init(handler: @escaping @Sendable (URLRequest) -> Response) {
        self.handler = handler
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.lock(); _requests.append(request); lock.unlock()
        let response = handler(request)
        let http = HTTPURLResponse(url: request.url!, statusCode: response.status, httpVersion: nil, headerFields: response.headers)!
        return (response.body, http)
    }
}

// Helpers to build a client wired to a mock, and to inspect recorded requests.

func makeClient(_ handler: @escaping @Sendable (URLRequest) -> MockHTTPClient.Response) -> (SpiderClient, MockHTTPClient) {
    let mock = MockHTTPClient(handler: handler)
    let client = SpiderClient(baseURL: "https://env.api.example.com", apiKey: "secret-key", options: SpiderClientOptions(httpClient: mock))
    return (client, mock)
}

func json(_ string: String, status: Int = 200, contractVersion: String? = "5.0") -> MockHTTPClient.Response {
    var headers: [String: String] = [:]
    if let contractVersion { headers["x-spider-contract-version"] = contractVersion }
    return MockHTTPClient.Response(status: status, headers: headers, body: Data(string.utf8))
}

extension URLRequest {
    var path: String { url?.path ?? "" }
    var bodyJSON: [String: Any] {
        guard let data = httpBody, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }
}
