public struct GraphQLError: Codable, Sendable {
    public let message: String
    public let path: [String]?

    public init(
        message: String,
        path: [String]? = nil
    ) {
        self.message = message
        self.path = path
    }
}
