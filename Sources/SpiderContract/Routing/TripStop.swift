public struct TripStop: Codable, Sendable {
    public let gtfsId: String
    public let name: String
    public let lat: Double
    public let lon: Double
    public let wheelchairBoarding: WheelchairBoarding
    /// Null when the feed has none.
    public let platformCode: String?
    /// Null when the feed has none.
    public let zoneId: String?

    public init(
        gtfsId: String,
        name: String,
        lat: Double,
        lon: Double,
        wheelchairBoarding: WheelchairBoarding,
        platformCode: String? = nil,
        zoneId: String? = nil
    ) {
        self.gtfsId = gtfsId
        self.name = name
        self.lat = lat
        self.lon = lon
        self.wheelchairBoarding = wheelchairBoarding
        self.platformCode = platformCode
        self.zoneId = zoneId
    }
}
