public struct StopDeparturesTrip: Codable, Sendable {
    public let gtfsId: String
    public let route: StopDeparturesRoute
    public let bikesAllowed: BikesAllowed?
    public let wheelchairAccessible: WheelchairBoarding?

    public init(
        gtfsId: String,
        route: StopDeparturesRoute,
        bikesAllowed: BikesAllowed? = nil,
        wheelchairAccessible: WheelchairBoarding? = nil
    ) {
        self.gtfsId = gtfsId
        self.route = route
        self.bikesAllowed = bikesAllowed
        self.wheelchairAccessible = wheelchairAccessible
    }
}
