public struct Route: Codable, Sendable {
    public let gtfsId: String
    /// Null when the feed has none.
    public let shortName: String
    /// Null when the feed has none.
    public let longName: String
    /// Hex without `#`; null when the feed has none.
    public let color: String
    /// Hex without `#`; null when the feed has none.
    public let textColor: String

    public init(
        gtfsId: String,
        shortName: String,
        longName: String,
        color: String,
        textColor: String
    ) {
        self.gtfsId = gtfsId
        self.shortName = shortName
        self.longName = longName
        self.color = color
        self.textColor = textColor
    }
}
