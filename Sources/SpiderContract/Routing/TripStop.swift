public struct TripStop: Codable, Sendable {
    public let gtfsId: String
    public let name: String
    public let lat: Double?
    public let lon: Double?
    public let wheelchairBoarding: WheelchairBoarding?

    public init(
        gtfsId: String,
        name: String,
        lat: Double? = nil,
        lon: Double? = nil,
        wheelchairBoarding: WheelchairBoarding? = nil
    ) {
        self.gtfsId = gtfsId
        self.name = name
        self.lat = lat
        self.lon = lon
        self.wheelchairBoarding = wheelchairBoarding
    }
}
