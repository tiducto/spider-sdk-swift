public struct Route: Codable, Sendable {
    public let shortName: String?
    public let longName: String?

    public init(
        shortName: String? = nil,
        longName: String? = nil
    ) {
        self.shortName = shortName
        self.longName = longName
    }
}
