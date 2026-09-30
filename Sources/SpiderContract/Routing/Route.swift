public struct Route: Codable, Sendable {
    public let gtfsId: String
    public let shortName: String?
    public let longName: String?
    public let color: String?
    public let textColor: String?

    public init(
        gtfsId: String,
        shortName: String? = nil,
        longName: String? = nil,
        color: String? = nil,
        textColor: String? = nil
    ) {
        self.gtfsId = gtfsId
        self.shortName = shortName
        self.longName = longName
        self.color = color
        self.textColor = textColor
    }
}
