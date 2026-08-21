public struct RoutingError: Codable, Sendable {
    public let code: RoutingErrorCode
    public let description: String
    public let inputField: InputField?

    public init(
        code: RoutingErrorCode,
        description: String,
        inputField: InputField? = nil
    ) {
        self.code = code
        self.description = description
        self.inputField = inputField
    }
}
