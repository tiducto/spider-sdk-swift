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

// The persisted-query wire body: { id, variables }. The SDK never sends raw GraphQL.
private struct PersistedRequest<V: Encodable>: Encodable {
    let id: String
    let variables: V
}

private struct GraphQLEnvelope<D: Decodable>: Decodable {
    let data: D?
    let errors: [GraphQLEnvelopeError]?
}

private struct GraphQLEnvelopeError: Decodable {
    let message: String
    // Present on validation failures the gateway/router stamp; code == "BAD_REQUEST" + the offending field.
    let extensions: GraphQLErrorExtensions?
}

private struct GraphQLErrorExtensions: Decodable {
    let code: String?
    let field: String?
}

struct RawResponse {
    let ok: Bool
    let status: Int
    let data: Data
    var text: String { String(data: data, encoding: .utf8) ?? "" }
}

/// Translates SDK calls into HTTP against the gateway: builds identity headers, applies the persisted-query
/// body shape, checks the contract-version response header, and runs the retry/backoff loop. Internal —
/// consumers reach it only through the surface classes on `SpiderClient`.
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

    private func request(url: URL, method: String, body: Data?, json: Bool) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = config.timeout
        req.setValue(apiKey, forHTTPHeaderField: "apikey")
        req.setValue(CONTRACT_VERSION, forHTTPHeaderField: CONTRACT_HEADER)
        req.setValue(SDK_IDENTITY, forHTTPHeaderField: SDK_HEADER)
        if json { req.setValue("application/json", forHTTPHeaderField: "content-type") }
        req.httpBody = body
        return req
    }

    // MARK: persisted-query POST

    func graphql<V: Encodable, D: Decodable>(_ op: PersistedOp, _ variables: V, as: D.Type = D.self) async throws -> D {
        guard let url = URL(string: "\(baseURL)/routing/\(op.path)") else {
            throw TransportError(.upstream, "invalid URL for routing/\(op.path)")
        }
        let body = try JSONEncoder().encode(PersistedRequest(id: op.id, variables: variables))
        let req = request(url: url, method: "POST", body: body, json: true)
        let (data, response) = try await send(req)
        try checkContract(response.value(forHTTPHeaderField: CONTRACT_HEADER))
        if !(200..<300).contains(response.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            let env = parseErrorEnvelope(text)
            let detail = env.message ?? String(text.prefix(300))
            throw TransportError(.http, "routing \(op.path) -> \(response.statusCode): \(detail)", httpStatus: response.statusCode, serverCode: env.code)
        }
        let envelope: GraphQLEnvelope<D> = try decode(from: data, where: "routing \(op.path)")
        if let errors = envelope.errors, !errors.isEmpty {
            // A BAD_REQUEST extension maps to typed badRequest; anything else stays a generic upstream.
            if let bad = errors.first(where: { $0.extensions?.code == "BAD_REQUEST" }) {
                throw TransportError(.badRequest, bad.message, field: bad.extensions?.field)
            }
            let joined = errors.map { $0.message }.joined(separator: ", ")
            throw TransportError(.upstream, "routing \(op.path) errors: \(joined)")
        }
        guard let payload = envelope.data else {
            throw TransportError(.noData, "routing \(op.path) returned no data")
        }
        return payload
    }

    // MARK: REST

    func postJson<B: Encodable, D: Decodable>(_ path: String, _ body: B, errorMessage: ((String) -> String)? = nil, as: D.Type = D.self) async throws -> D {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw TransportError(.upstream, "invalid URL for \(path)")
        }
        let data = try JSONEncoder().encode(body)
        let req = request(url: url, method: "POST", body: data, json: true)
        let (respData, response) = try await send(req)
        try checkContract(response.value(forHTTPHeaderField: CONTRACT_HEADER))
        if !(200..<300).contains(response.statusCode) {
            let text = String(data: respData, encoding: .utf8) ?? ""
            let env = parseErrorEnvelope(text)
            let message = errorMessage?(text) ?? env.message ?? String(text.prefix(300))
            throw TransportError(.http, "POST \(path) -> \(response.statusCode): \(message)", httpStatus: response.statusCode, serverCode: env.code)
        }
        return try decode(from: respData, where: "POST \(path)")
    }

    func getJson<D: Decodable>(_ path: String, query: [(String, String)] = [], as: D.Type = D.self) async throws -> D {
        let raw = try await getRaw(path, query: query)
        if !raw.ok {
            let env = parseErrorEnvelope(raw.text)
            let detail = env.message ?? String(raw.text.prefix(300))
            throw TransportError(.http, "GET \(path) -> \(raw.status): \(detail)", httpStatus: raw.status, serverCode: env.code)
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
        try checkContract(response.value(forHTTPHeaderField: CONTRACT_HEADER))
        return RawResponse(ok: (200..<300).contains(response.statusCode), status: response.statusCode, data: data)
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
