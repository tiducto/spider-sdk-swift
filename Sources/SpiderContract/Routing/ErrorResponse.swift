/// Error body: a stable machine-readable `code` (a state name) and a human-readable `message`.
public struct ErrorResponse: Codable, Sendable {
    /// For bad_request: `<field> is required|invalid|out of range|not allowed`.
    public let message: String
    public let code: String?
    /// The request member a 400 names, as a dot path from the body root (array positions omitted).
    public let field: String?

    public init(
        message: String,
        code: String? = nil,
        field: String? = nil
    ) {
        self.message = message
        self.code = code
        self.field = field
    }
}
