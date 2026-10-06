import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The HTTP boundary the SDK depends on. The production implementation is `URLSessionHTTPClient`; tests inject
/// their own conforming type. Extracted as a protocol (no `open` classes) so substitution needs no subclassing.
public protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Default `HTTPClient` backed by `URLSession`.
public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}

struct RetryConfig {
    let maxAttempts: Int
}

struct TransportConfig {
    let httpClient: HTTPClient
    let timeout: TimeInterval // seconds; applied as URLRequest.timeoutInterval
    let retry: RetryConfig?
}

struct RawResponse {
    let ok: Bool
    let status: Int
    let data: Data
    var text: String { String(data: data, encoding: .utf8) ?? "" }
}

/// Translates SDK calls into HTTP against the gateway: builds identity headers, encodes JSON bodies, and runs
/// the retry/backoff loop. Internal — consumers reach it only through the surface classes on `SpiderClient`.
final class Transport {
    private let baseURL: String
    private let apiKey: String
    private let config: TransportConfig

    init(baseURL: String, apiKey: String, config: TransportConfig) {
        var trimmed = baseURL
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        self.baseURL = trimmed
        self.apiKey = apiKey
        self.config = config
    }

    // MARK: request building

    /// The one place the Transport stamps the client `apikey`. The key is invariant for a client's whole
    /// life, so every `URLRequest` the Transport builds — real contract calls and the warm-up probe alike —
    /// funnels through here and gets the shared auth header exactly once. Contract/sdk headers are added on
    /// top only for real calls (see `request`); the warm-up carries just this shared stamp.
    private func makeRequest(url: URL, method: String) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = config.timeout
        req.setValue(apiKey, forHTTPHeaderField: "apikey")
        return req
    }

    private func request(url: URL, method: String, body: Data?, json: Bool) -> URLRequest {
        var req = makeRequest(url: url, method: method)
        req.setValue(CONTRACT_VERSION, forHTTPHeaderField: CONTRACT_HEADER)
        req.setValue(SDK_IDENTITY, forHTTPHeaderField: SDK_HEADER)
        if json { req.setValue("application/json", forHTTPHeaderField: "content-type") }
        req.httpBody = body
        return req
    }

    // MARK: SSE

    // A batch POST plus `accept: text/event-stream`; streamed through `URLSession.bytes`, so it skips `send`/retry.
    func streamingRequest<B: Encodable>(_ path: String, _ body: B) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw TransportError(.upstream, "invalid URL for \(path)")
        }
        var req = request(url: url, method: "POST", body: try JSONEncoder().encode(body), json: true)
        req.setValue("text/event-stream", forHTTPHeaderField: "accept")
        return req
    }

    // MARK: REST

    func postJson<B: Encodable, D: Decodable>(_ path: String, _ body: B, errorMessage: ((String) -> String)? = nil, as: D.Type = D.self) async throws -> D {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw TransportError(.upstream, "invalid URL for \(path)")
        }
        let data = try JSONEncoder().encode(body)
        let req = request(url: url, method: "POST", body: data, json: true)
        let (respData, response) = try await send(req)
        if !(200..<300).contains(response.statusCode) {
            let text = String(data: respData, encoding: .utf8) ?? ""
            throw httpFailure("POST \(path)", status: response.statusCode, body: text, message: errorMessage?(text))
        }
        return try decode(from: respData, where: "POST \(path)")
    }

    func getJson<D: Decodable>(_ path: String, query: [(String, String)] = [], as: D.Type = D.self) async throws -> D {
        let raw = try await getRaw(path, query: query)
        if !raw.ok {
            throw httpFailure("GET \(path)", status: raw.status, body: raw.text)
        }
        return try decode(from: raw.data, where: "GET \(path)")
    }

    func getRaw(_ path: String, query: [(String, String)] = []) async throws -> RawResponse {
        guard var comps = URLComponents(string: "\(baseURL)\(path)") else {
            throw TransportError(.upstream, "invalid URL for \(path)")
        }
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        }
        guard let url = comps.url else {
            throw TransportError(.upstream, "invalid URL for \(path)")
        }
        let req = request(url: url, method: "GET", body: nil, json: false)
        let (data, response) = try await send(req)
        return RawResponse(ok: (200..<300).contains(response.statusCode), status: response.statusCode, data: data)
    }

    // MARK: warm-up

    /// Best-effort probe of `GET {baseURL}/ping` to open the TLS connection real calls reuse.
    /// Authenticated with the client apikey (like every real call) via the Transport's shared
    /// request-builder, but sends none of the contract headers — `/ping` is not contract-gated. Never
    /// throws: a transport error or any non-2xx status (including a 401/404 before the keyed gateway route
    /// deploys) still warms the connection. Returns the elapsed wall-clock time in seconds.
    func warmup() async -> TimeInterval {
        let start = Date()
        if let url = URL(string: "\(baseURL)/ping") {
            // apikey comes from the Transport's shared request-builder; no contract/sdk headers here.
            let req = makeRequest(url: url, method: "GET")
            // No retry: a single fire-and-forget probe whose only job is the connection.
            do {
                _ = try await config.httpClient.send(req)
            } catch {
                // Swallowed on purpose — a failed probe still opened (or attempted) the connection.
            }
        }
        return Date().timeIntervalSince(start)
    }

    // MARK: retry + backoff

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let maxAttempts = config.retry?.maxAttempts ?? 1
        var attempt = 1
        while true {
            do {
                let (data, response) = try await config.httpClient.send(request)
                if attempt < maxAttempts, response.statusCode == 429 || response.statusCode >= 500 {
                    try await retryDelay(attempt: attempt, response: response)
                    attempt += 1
                    continue
                }
                return (data, response)
            } catch {
                if attempt < maxAttempts {
                    try await retryDelay(attempt: attempt, response: nil)
                    attempt += 1
                    continue
                }
                throw error
            }
        }
    }

    private func retryDelay(attempt: Int, response: HTTPURLResponse?) async throws {
        let baseMs: Double
        if let header = response?.value(forHTTPHeaderField: "retry-after"), let seconds = Double(header), seconds >= 0 {
            baseMs = seconds * 1000
        } else {
            baseMs = min(1000 * pow(2.0, Double(attempt - 1)), 10000)
        }
        let jitter = baseMs * 0.25 * Double.random(in: 0..<1)
        try await Task.sleep(nanoseconds: UInt64((baseMs + jitter) * 1_000_000))
    }
}

// Decodes JSON, wrapping any failure in a `SpiderDecodingError` carrying context.
func decode<T: Decodable>(from data: Data, where context: String) throws -> T {
    do {
        return try JSONDecoder().decode(T.self, from: data)
    } catch {
        throw SpiderDecodingError(message: "failed to decode \(context)", cause: error)
    }
}
