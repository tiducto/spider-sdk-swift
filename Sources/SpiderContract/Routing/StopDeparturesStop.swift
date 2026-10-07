public struct StopDeparturesStop: Codable, Sendable {
    public let gtfsId: String
    /// Null when the feed has none.
    public let platformCode: String?

    public init(
        gtfsId: String,
        platformCode: String? = nil
    ) {
        self.gtfsId = gtfsId
        self.platformCode = platformCode
    }
}
