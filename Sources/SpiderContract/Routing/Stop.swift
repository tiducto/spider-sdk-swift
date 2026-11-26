public struct Stop: Codable, Sendable {
    public let gtfsId: String
    public let wheelchairBoarding: WheelchairBoarding
    /// Null when the feed has none.
    public let platformCode: String?
    /// Null when the feed has none.
    public let zoneId: String?
    /// The station this stop belongs to, as OTP's `Stop.parentStation`; null when the stop has none.
    public let parentStation: ParentStation?

    public init(
        gtfsId: String,
        wheelchairBoarding: WheelchairBoarding,
        platformCode: String? = nil,
        zoneId: String? = nil,
        parentStation: ParentStation? = nil
    ) {
        self.gtfsId = gtfsId
        self.wheelchairBoarding = wheelchairBoarding
        self.platformCode = platformCode
        self.zoneId = zoneId
        self.parentStation = parentStation
    }
}
