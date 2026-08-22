/// Standard error body: a stable machine-readable `code` and a human-readable `message`.
public struct ErrorResponse: Codable, Sendable {
    public let message: String
    public let code: String?

    public init(
        message: String,
        code: String? = nil
    ) {
        self.message = message
        self.code = code
    }
}
