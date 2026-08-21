public struct TransitFilterSelectInput: Codable, Sendable {
    public let agencies: [String]?
    public let routes: [String]?

    public init(
        agencies: [String]? = nil,
        routes: [String]? = nil
    ) {
        self.agencies = agencies
        self.routes = routes
    }
}
