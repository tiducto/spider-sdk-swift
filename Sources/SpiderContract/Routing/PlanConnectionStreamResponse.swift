public struct PlanConnectionStreamResponse: Codable, Sendable {
    public let data: PlanConnectionStreamData?
    public let errors: [GraphQLError]?

    public init(
        data: PlanConnectionStreamData? = nil,
        errors: [GraphQLError]? = nil
    ) {
        self.data = data
        self.errors = errors
    }
}
