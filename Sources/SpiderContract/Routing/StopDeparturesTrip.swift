public struct StopDeparturesTrip: Codable, Sendable {
    public let gtfsId: String
    public let bikesAllowed: BikesAllowed
    public let wheelchairAccessible: WheelchairBoarding
    public let route: StopDeparturesRoute

    public init(
        gtfsId: String,
        bikesAllowed: BikesAllowed,
        wheelchairAccessible: WheelchairBoarding,
        route: StopDeparturesRoute
    ) {
        self.gtfsId = gtfsId
        self.bikesAllowed = bikesAllowed
        self.wheelchairAccessible = wheelchairAccessible
        self.route = route
    }
}
