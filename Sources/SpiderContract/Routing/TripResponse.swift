public struct TripResponse: Codable, Sendable {
    public let data: TripData?
    public let errors: [GraphQLError]?

    public init(
        data: TripData? = nil,
        errors: [GraphQLError]? = nil
    ) {
        self.data = data
        self.errors = errors
    }
}
