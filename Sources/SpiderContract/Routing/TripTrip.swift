public struct TripTrip: Codable, Sendable {
    public let gtfsId: String
    public let route: TripRoute
    public let directionId: String?
    public let tripHeadsign: String?
    public let bikesAllowed: BikesAllowed?
    public let stoptimesForDate: [TripStoptime]?
    public let tripGeometry: TripGeometry?

    public init(
        gtfsId: String,
        route: TripRoute,
        directionId: String? = nil,
        tripHeadsign: String? = nil,
        bikesAllowed: BikesAllowed? = nil,
        stoptimesForDate: [TripStoptime]? = nil,
        tripGeometry: TripGeometry? = nil
    ) {
        self.gtfsId = gtfsId
        self.route = route
        self.directionId = directionId
        self.tripHeadsign = tripHeadsign
        self.bikesAllowed = bikesAllowed
        self.stoptimesForDate = stoptimesForDate
        self.tripGeometry = tripGeometry
    }
}
