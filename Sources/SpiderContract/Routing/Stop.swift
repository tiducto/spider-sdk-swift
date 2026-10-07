public struct Stop: Codable, Sendable {
    public let gtfsId: String
    public let wheelchairBoarding: WheelchairBoarding
    /// Null when the feed has none.
    public let platformCode: String
    /// Null when the feed has none.
    public let zoneId: String

    public init(
        gtfsId: String,
        wheelchairBoarding: WheelchairBoarding,
        platformCode: String,
        zoneId: String
    ) {
        self.gtfsId = gtfsId
        self.wheelchairBoarding = wheelchairBoarding
        self.platformCode = platformCode
        self.zoneId = zoneId
    }
}
