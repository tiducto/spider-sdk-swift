public struct Stop: Codable, Sendable {
    public let gtfsId: String
    public let wheelchairBoarding: WheelchairBoarding?
    public let platformCode: String?
    public let zoneId: String?

    public init(
        gtfsId: String,
        wheelchairBoarding: WheelchairBoarding? = nil,
        platformCode: String? = nil,
        zoneId: String? = nil
    ) {
        self.gtfsId = gtfsId
        self.wheelchairBoarding = wheelchairBoarding
        self.platformCode = platformCode
        self.zoneId = zoneId
    }
}
