public struct PlanConnection: Codable, Sendable {
    public let pageInfo: PlanPageInfo
    public let routingErrors: [RoutingError]
    public let edges: [PlanEdge]?
    public let searchDateTime: String?

    public init(
        pageInfo: PlanPageInfo,
        routingErrors: [RoutingError],
        edges: [PlanEdge]? = nil,
        searchDateTime: String? = nil
    ) {
        self.pageInfo = pageInfo
        self.routingErrors = routingErrors
        self.edges = edges
        self.searchDateTime = searchDateTime
    }
}
