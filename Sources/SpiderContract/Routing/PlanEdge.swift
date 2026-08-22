public struct PlanEdge: Codable, Sendable {
    public let cursor: String
    public let node: Itinerary

    public init(
        cursor: String,
        node: Itinerary
    ) {
        self.cursor = cursor
        self.node = node
    }
}
