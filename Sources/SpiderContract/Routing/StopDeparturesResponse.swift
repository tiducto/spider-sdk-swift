public struct StopDeparturesResponse: Codable, Sendable {
    public let data: StopDeparturesData?
    public let errors: [GraphQLError]?

    public init(
        data: StopDeparturesData? = nil,
        errors: [GraphQLError]? = nil
    ) {
        self.data = data
        self.errors = errors
    }
}
