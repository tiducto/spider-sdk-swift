public struct PlanPageInfo: Codable, Sendable {
    public let hasNextPage: Bool
    public let hasPreviousPage: Bool
    public let startCursor: String?
    public let endCursor: String?
    public let searchWindowUsed: String?

    public init(
        hasNextPage: Bool,
        hasPreviousPage: Bool,
        startCursor: String? = nil,
        endCursor: String? = nil,
        searchWindowUsed: String? = nil
    ) {
        self.hasNextPage = hasNextPage
        self.hasPreviousPage = hasPreviousPage
        self.startCursor = startCursor
        self.endCursor = endCursor
        self.searchWindowUsed = searchWindowUsed
    }
}
