import Foundation

/// The result of every SDK call. Ordinary failures never throw — they surface as `.failure`. The one
/// exception is a major contract mismatch, which throws `SpiderContractMismatchError` out of the call.
public enum SpiderResult<Success> {
    case success(Success)
    case failure(SpiderError)

    /// True for `.success`.
    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    /// The value on success, else nil.
    public var value: Success? {
        if case .success(let v) = self { return v }
        return nil
    }

    /// The error on failure, else nil.
    public var error: SpiderError? {
        if case .failure(let e) = self { return e }
        return nil
    }

    /// The value on success; throws the `SpiderError` on failure. For call sites that prefer `try`.
    public func get() throws -> Success {
        switch self {
        case .success(let v): return v
        case .failure(let e): throw e
        }
    }

    /// Transforms the success value, preserving a failure unchanged.
    public func map<U>(_ transform: (Success) -> U) -> SpiderResult<U> {
        switch self {
        case .success(let v): return .success(transform(v))
        case .failure(let e): return .failure(e)
        }
    }
}
