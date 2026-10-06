public struct StopDeparturesRoute: Codable, Sendable {
    public let gtfsId: String
    public let shortName: String?
    public let longName: String?
    public let mode: TransitMode?
    /// Hex without `#`; null when the feed has none.
    public let color: String?
    /// Hex without `#`; null when the feed has none.
    public let textColor: String?

    public init(
        gtfsId: String,
        shortName: String? = nil,
        longName: String? = nil,
        mode: TransitMode? = nil,
        color: String? = nil,
        textColor: String? = nil
    ) {
        self.gtfsId = gtfsId
        self.shortName = shortName
        self.longName = longName
        self.mode = mode
        self.color = color
        self.textColor = textColor
    }
}
