public struct StopDeparturesTrip: Codable, Sendable {
    public let gtfsId: String
    public let route: StopDeparturesRoute
    public let bikesAllowed: BikesAllowed?

    public init(
        gtfsId: String,
        route: StopDeparturesRoute,
        bikesAllowed: BikesAllowed? = nil
    ) {
        self.gtfsId = gtfsId
        self.route = route
        self.bikesAllowed = bikesAllowed
    }
}
