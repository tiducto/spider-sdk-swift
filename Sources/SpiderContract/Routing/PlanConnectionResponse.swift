public struct PlanConnectionResponse: Codable, Sendable {
    public let data: PlanConnectionData?
    public let errors: [GraphQLError]?

    public init(
        data: PlanConnectionData? = nil,
        errors: [GraphQLError]? = nil
    ) {
        self.data = data
        self.errors = errors
    }
}
