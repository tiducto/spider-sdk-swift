public struct StopDeparturesRoute: Codable, Sendable {
    public let shortName: String?
    public let longName: String?
    public let mode: TransitMode?

    public init(
        shortName: String? = nil,
        longName: String? = nil,
        mode: TransitMode? = nil
    ) {
        self.shortName = shortName
        self.longName = longName
        self.mode = mode
    }
}
