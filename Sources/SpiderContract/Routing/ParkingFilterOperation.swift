public struct ParkingFilterOperation: Codable, Sendable {
    public let tags: [String]?

    public init(
        tags: [String]? = nil
    ) {
        self.tags = tags
    }
}
