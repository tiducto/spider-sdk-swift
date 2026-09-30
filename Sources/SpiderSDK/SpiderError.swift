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
    /// The persisted routing query behind the call is retired: the API no longer serves it (HTTP 410).
    case queryRetired = "query_retired"
    /// The project has used the searches its plan includes: the API refuses trip planning (plan and plan stream).
    case searchLimitReached = "search_limit_reached"
    /// The project's agreement is not active: the API refuses every call made with the key.
    case agreementInactive = "agreement_inactive"
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
    /// The machine-readable `code` from a server JSON error envelope, when present: e.g. `query_retired` on a
    /// `.queryRetired`, or `persisted_query_rejected` (HTTP 403) when the gateway doesn't know the query id.
    public let serverCode: String?
    /// For a `badRequest` (a missing, out-of-range or invalid value, rejected by the SDK before sending or by the
    /// server), the offending input's wire name when one is named. Nil otherwise.
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
    // The offending input field the server named, if any: from a BAD_REQUEST extension, or from an HTTP error
    // message of the fixed `<field> is …` shape.
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
/// `error` is the gateway's own rejection kind (e.g. `persisted_query_rejected`), which it sends instead of `code`.
struct ErrorEnvelope {
    let code: String?
    let message: String?
    let error: String?
}

func parseErrorEnvelope(_ text: String) -> ErrorEnvelope {
    guard let data = text.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return ErrorEnvelope(code: nil, message: nil, error: nil)
    }
    return ErrorEnvelope(code: obj["code"] as? String, message: obj["message"] as? String, error: obj["error"] as? String)
}

let PERSISTED_QUERY_REJECTED = "persisted_query_rejected"
let QUERY_RETIRED = "query_retired"
let SEARCH_LIMIT_REACHED = "search_limit_reached"
let AGREEMENT_INACTIVE = "agreement_inactive"

// The gateway's plan-limit refusals, keyed by the `error` it names them with, and their message when the body
// carries none.
private let PLAN_LIMIT_MESSAGES = [
    SEARCH_LIMIT_REACHED: "search limit reached",
    AGREEMENT_INACTIVE: "agreement is not active",
]

// A plan-limit refusal as a transport error, whatever the HTTP status (a proxy may rewrite it): the body's
// `error` decides, and the message is the body's own. Nil for any other body, so a plain 403 stays unauthorized.
func planLimitError(status: Int, envelope env: ErrorEnvelope) -> TransportError? {
    guard let code = env.error, let fallback = PLAN_LIMIT_MESSAGES[code] else { return nil }
    return TransportError(.http, env.message ?? fallback, httpStatus: status, serverCode: code)
}

// A routing non-2xx as a transport error. The gateway names its own rejections in `error`: the plan limits
// (`search_limit_reached`, `agreement_inactive`), `query_retired` (HTTP 410, also the fallback when the body is
// unreadable) and `persisted_query_rejected` (403, an id it never had).
func routingHTTPError(_ path: String, status: Int, body: String) -> TransportError {
    let env = parseErrorEnvelope(body)
    if let limit = planLimitError(status: status, envelope: env) { return limit }
    if env.error == QUERY_RETIRED || status == 410 {
        return TransportError(.http, "routing \(path) -> \(status): persisted query is retired", httpStatus: status, serverCode: QUERY_RETIRED)
    }
    let detail = env.message ?? String(body.prefix(300))
    let serverCode = env.error == PERSISTED_QUERY_REJECTED ? PERSISTED_QUERY_REJECTED : env.code
    return TransportError(.http, "routing \(path) -> \(status): \(detail)", httpStatus: status, serverCode: serverCode, field: validationField(detail))
}

private let VALIDATION_PROBLEMS = [" is out of range", " is required", " is invalid"]

// The field a server validation message names, when the message has the fixed `<field> is out of range`,
// `<field> is required` or `<field> is invalid` shape. Nil for any other message.
func validationField(_ message: String) -> String? {
    let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
    for problem in VALIDATION_PROBLEMS where text.hasSuffix(problem) {
        let field = text.dropLast(problem.count)
        guard let first = field.first, first.isASCII, first.isLetter || first == "_",
              field.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }) else { return nil }
        return String(field)
    }
    return nil
}

// The typed failures for an input the SDK rejects before any request is sent. They name only the field, never
// the limit or the value.
func outOfRange(_ field: String) -> SpiderError {
    SpiderError(code: .badRequest, message: "\(field) is out of range", field: field)
}

func invalid(_ field: String) -> SpiderError {
    SpiderError(code: .badRequest, message: "\(field) is invalid", field: field)
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
            case _ where te.serverCode == SEARCH_LIMIT_REACHED: code = .searchLimitReached
            case _ where te.serverCode == AGREEMENT_INACTIVE: code = .agreementInactive
            case _ where te.serverCode == QUERY_RETIRED: code = .queryRetired
            // Realtime and stop search answer an invalid input with a plain 400 naming the field.
            case 400: code = .badRequest
            case 401, 403: code = .unauthorized
            case 404: code = .notFound
            case 408, 504: code = .timeout
            case 429: code = .rateLimited
            case 500...599: code = .server
            default: code = .unknown
            }
            return SpiderError(code: code, message: te.message, httpStatus: status, serverCode: te.serverCode, field: code == .badRequest ? te.field : nil)
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
