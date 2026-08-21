public struct Stop: Codable, Sendable {
    public let gtfsId: String
    public let wheelchairBoarding: WheelchairBoarding?

    public init(
        gtfsId: String,
        wheelchairBoarding: WheelchairBoarding? = nil
    ) {
        self.gtfsId = gtfsId
        self.wheelchairBoarding = wheelchairBoarding
    }
}
