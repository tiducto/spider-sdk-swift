/// Exactly one of `routes`, `agencies`.
public struct TransitFilterSelectInput: Codable, Sendable {
    /// Feed-prefixed route ids (`<feedId>:<routeId>`).
    public let routes: [String]?
    /// Feed-prefixed agency ids (`<feedId>:<agencyId>`).
    public let agencies: [String]?

    public init(
        routes: [String]? = nil,
        agencies: [String]? = nil
    ) {
        self.routes = routes
        self.agencies = agencies
    }
}
