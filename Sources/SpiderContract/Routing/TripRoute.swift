public struct TripRoute: Codable, Sendable {
    public let gtfsId: String
    public let mode: TransitMode
    /// Null when the feed has none.
    public let shortName: String?
    /// Null when the feed has none.
    public let longName: String?
    /// Hex without `#`; null when the feed has none.
    public let color: String?
    /// Hex without `#`; null when the feed has none.
    public let textColor: String?

    public init(
        gtfsId: String,
        mode: TransitMode,
        shortName: String? = nil,
        longName: String? = nil,
        color: String? = nil,
        textColor: String? = nil
    ) {
        self.gtfsId = gtfsId
        self.mode = mode
        self.shortName = shortName
        self.longName = longName
        self.color = color
        self.textColor = textColor
    }
}
