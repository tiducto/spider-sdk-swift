/// One trip on one service date: its stops and times, realtime merged in. On a date without realtime, the rows carry the schedule alone.
public struct TripTimetable: Codable, Sendable {
    public let gtfsId: String
    public let route: TripRoute
    public let directionId: String?
    public let tripHeadsign: String?
    public let bikesAllowed: BikesAllowed?
    public let wheelchairAccessible: WheelchairBoarding?
    public let stoptimesForDate: [Stoptime]?
    /// The trip's path; null when the feed has no shapes.
    public let tripGeometry: TripGeometry?

    public init(
        gtfsId: String,
        route: TripRoute,
        directionId: String? = nil,
        tripHeadsign: String? = nil,
        bikesAllowed: BikesAllowed? = nil,
        wheelchairAccessible: WheelchairBoarding? = nil,
        stoptimesForDate: [Stoptime]? = nil,
        tripGeometry: TripGeometry? = nil
    ) {
        self.gtfsId = gtfsId
        self.route = route
        self.directionId = directionId
        self.tripHeadsign = tripHeadsign
        self.bikesAllowed = bikesAllowed
        self.wheelchairAccessible = wheelchairAccessible
        self.stoptimesForDate = stoptimesForDate
        self.tripGeometry = tripGeometry
    }
}
