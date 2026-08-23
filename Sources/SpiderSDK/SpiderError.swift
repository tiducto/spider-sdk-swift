import Foundation

/// The stable failure taxonomy shared with the other Spider SDKs. Branch on `code` for programmatic handling.
public enum SpiderErrorCode: String, Sendable {
    case network
    case timeout
    case unauthorized
    case badRequest = "bad_request"
    case notFound = "not_found"
    case server
    case rateLimited = "rate_limited"
    case decoding
    case unknown
}

/// A recoverable failure carried in `SpiderResult.failure`.
public struct SpiderError: Error {
    /// The stable category.
    public let code: SpiderErrorCode
    /// A human-readable description (not for programmatic branching — use `code`).
    public let message: String
    /// The HTTP status, when the failure came from an HTTP response.
    public let httpStatus: Int?
    /// The machine-readable `code` from a server JSON error envelope, when present.
    public let serverCode: String?
    /// For a `badRequest` (a server validation failure — over-cap `searchWindow`, malformed `via`, or a
    /// missing required field), the offending input field when the server names one. Nil otherwise.
    public let field: String?
    /// The underlying error, when one caused this failure.
    public let cause: Error?

    public init(code: SpiderErrorCode, message: String, httpStatus: Int? = nil, serverCode: String? = nil, field: String? = nil, cause: Error? = nil) {
        self.code = code
        self.message = message
        self.httpStatus = httpStatus
        self.serverCode = serverCode
        self.field = field
        self.cause = cause
    }
}

extension SpiderError: CustomStringConvertible {
    public var description: String { "SpiderError(\(code.rawValue): \(message))" }
}

/// Thrown (never returned) when the gateway declares a different MAJOR contract version than this SDK speaks.
/// It escapes the `SpiderResult` channel on purpose: a major mismatch is a hard, programmer-visible failure.
public struct SpiderContractMismatchError: Error, CustomStringConvertible {
    public let expected: String
    public let actual: String

    public init(expected: String, actual: String) {
        self.expected = expected
        self.actual = actual
    }

    public var message: String {
        "Spider contract mismatch: this SDK speaks \(expected) but the gateway declared \(actual)"
    }
    public var description: String { message }
}

// MARK: - Internal transport errors (mapped to SpiderError by `toSpiderError`)

enum TransportErrorKind {
    case http
    case noData
    case upstream
    case badRequest
}

struct TransportError: Error {
    let kind: TransportErrorKind
    let message: String
    let httpStatus: Int?
    let serverCode: String?
    // Set only for `.badRequest`: the offending input field the server named, if any.
    let field: String?

    init(_ kind: TransportErrorKind, _ message: String, httpStatus: Int? = nil, serverCode: String? = nil, field: String? = nil) {
        self.kind = kind
        self.message = message
        self.httpStatus = httpStatus
        self.serverCode = serverCode
        self.field = field
    }
}

struct SpiderDecodingError: Error {
    let message: String
    let cause: Error
}

/// A parsed server error envelope: a stable machine `code` and a human `message`, either possibly absent.
struct ErrorEnvelope {
    let code: String?
    let message: String?
}

func parseErrorEnvelope(_ text: String) -> ErrorEnvelope {
    guard let data = text.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return ErrorEnvelope(code: nil, message: nil)
    }
    return ErrorEnvelope(code: obj["code"] as? String, message: obj["message"] as? String)
}

/// Maps any thrown error into the public `SpiderError` taxonomy. Mirrors the TS SDK's `toSpiderError`.
func toSpiderError(_ error: Error) -> SpiderError {
    if let spider = error as? SpiderError { return spider } // idempotent: an already-mapped error passes through
    if let te = error as? TransportError {
        switch te.kind {
        case .http:
            let status = te.httpStatus ?? 0
            let code: SpiderErrorCode
            switch status {
            case 401, 403: code = .unauthorized
            case 404: code = .notFound
            case 408, 504: code = .timeout
            case 429: code = .rateLimited
            case 500...599: code = .server
            default: code = .unknown
            }
            return SpiderError(code: code, message: te.message, httpStatus: status, serverCode: te.serverCode)
        case .noData:
            return SpiderError(code: .notFound, message: te.message)
        case .badRequest:
            return SpiderError(code: .badRequest, message: te.message, field: te.field)
        case .upstream:
            return SpiderError(code: .server, message: te.message)
        }
    }
    if let de = error as? SpiderDecodingError {
        return SpiderError(code: .decoding, message: de.message, cause: de.cause)
    }
    if isTimeout(error) {
        return SpiderError(code: .timeout, message: error.localizedDescription, cause: error)
    }
    if isConnectionFailure(error) {
        return SpiderError(code: .network, message: error.localizedDescription, cause: error)
    }
    return SpiderError(code: .unknown, message: error.localizedDescription, cause: error)
}

// URLSession surfaces cancellation/timeout and connectivity failures as URLError codes.
private func isTimeout(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    if let urlError = error as? URLError {
        return urlError.code == .timedOut || urlError.code == .cancelled
    }
    return false
}

private func isConnectionFailure(_ error: Error) -> Bool {
    guard let urlError = error as? URLError else { return false }
    switch urlError.code {
    case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost,
         .dnsLookupFailed, .resourceUnavailable, .internationalRoamingOff, .dataNotAllowed:
        return true
    default:
        return false
    }
}
