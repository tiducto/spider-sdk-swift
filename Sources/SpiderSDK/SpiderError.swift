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
    /// The part of the API this SDK version calls is retired: the API no longer serves it (HTTP 410). Upgrade the
    /// SDK.
    case queryRetired = "query_retired"
    /// The project has reached the trip-planning limit its plan includes: the API refuses plan and plan stream.
    case planningLimitReached = "planning_limit_reached"
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
    /// `.queryRetired`, or `bad_request` on a `.badRequest`.
    public let serverCode: String?
    /// For a `badRequest` (a missing, out-of-range, invalid or unknown value, rejected by the SDK before sending or
    /// by the server), the offending input's wire name when one is named, as a dot path from the request body's
    /// root (e.g. `preferences.street.walk.reluctance`). Nil otherwise.
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
    // The offending input field the server named, if any: the body's `field`, or the one its message names.
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

/// A parsed server error envelope: a stable machine `code`, a human `message` and the `field` a 400 names, each
/// possibly absent. `error` is the gateway's own rejection kind (e.g. `planning_limit_reached`).
struct ErrorEnvelope {
    let code: String?
    let message: String?
    let error: String?
    let field: String?
}

func parseErrorEnvelope(_ text: String) -> ErrorEnvelope {
    guard let data = text.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return ErrorEnvelope(code: nil, message: nil, error: nil, field: nil)
    }
    return ErrorEnvelope(
        code: obj["code"] as? String,
        message: obj["message"] as? String,
        error: obj["error"] as? String,
        field: obj["field"] as? String
    )
}

let QUERY_RETIRED = "query_retired"
let PLANNING_LIMIT_REACHED = "planning_limit_reached"
let AGREEMENT_INACTIVE = "agreement_inactive"

// The gateway's plan-limit refusals, keyed by the code it names them with, and their message when the body
// carries none.
private let PLAN_LIMIT_MESSAGES = [
    PLANNING_LIMIT_REACHED: "trip planning limit reached",
    AGREEMENT_INACTIVE: "agreement is not active",
]

// A plan-limit refusal as a transport error, whatever the HTTP status (a proxy may rewrite it): the body's
// `code` (or `error`) decides, and the message is the body's own, trimmed, or the fixed wording when it is
// missing or blank. Nil for any other body, so a plain 403 stays unauthorized.
func planLimitError(status: Int, envelope env: ErrorEnvelope) -> TransportError? {
    guard let code = env.code ?? env.error, let fallback = PLAN_LIMIT_MESSAGES[code] else { return nil }
    let message = env.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return TransportError(.http, message.isEmpty ? fallback : message, httpStatus: status, serverCode: code)
}

// A non-2xx answer: a plan-limit refusal whatever the status, else the message with the body's `field` or the one it names.
func httpFailure(_ call: String, status: Int, body: String, message: String? = nil) -> TransportError {
    let env = parseErrorEnvelope(body)
    if let limit = planLimitError(status: status, envelope: env) { return limit }
    let detail = message ?? env.message ?? String(body.prefix(300))
    return TransportError(.http, "\(call) -> \(status): \(detail)", httpStatus: status, serverCode: env.code, field: env.field ?? validationField(detail))
}

private let VALIDATION_PROBLEMS = [" is out of range", " is required", " is invalid", " is not allowed"]

// The field (a dot path) named by a message of the fixed `<field> is out of range|required|invalid|not allowed` shape.
func validationField(_ message: String) -> String? {
    let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
    for problem in VALIDATION_PROBLEMS where text.hasSuffix(problem) {
        let field = text.dropLast(problem.count)
        guard let first = field.first, first.isASCII, first.isLetter || first == "_",
              field.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == ".") }) else { return nil }
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
            case _ where te.serverCode == PLANNING_LIMIT_REACHED: code = .planningLimitReached
            case _ where te.serverCode == AGREEMENT_INACTIVE: code = .agreementInactive
            case _ where te.serverCode == QUERY_RETIRED: code = .queryRetired
            case 400: code = .badRequest
            case 401, 403: code = .unauthorized
            case 404: code = .notFound
            case 410: code = .queryRetired
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
