public struct TripRoute: Codable, Sendable {
    public let gtfsId: String
    /// Null when the feed has none.
    public let shortName: String
    /// Null when the feed has none.
    public let longName: String
    public let mode: TransitMode
    /// Hex without `#`; null when the feed has none.
    public let color: String
    /// Hex without `#`; null when the feed has none.
    public let textColor: String

    public init(
        gtfsId: String,
        shortName: String,
        longName: String,
        mode: TransitMode,
        color: String,
        textColor: String
    ) {
        self.gtfsId = gtfsId
        self.shortName = shortName
        self.longName = longName
        self.mode = mode
        self.color = color
        self.textColor = textColor
    }
}
