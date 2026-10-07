/// One trip on one service date: its stops and times, realtime merged in. On a date without realtime the rows carry the schedule alone, and on a date the trip does not run they carry its schedule on that date.
public struct TripTimetable: Codable, Sendable {
    public let gtfsId: String
    public let bikesAllowed: BikesAllowed
    public let wheelchairAccessible: WheelchairBoarding
    public let route: TripRoute
    public let stoptimesForDate: [Stoptime]
    /// `0` or `1`, as the feed gives it; null when it gives none.
    public let directionId: String?
    /// Null when the feed has none.
    public let tripHeadsign: String?
    /// The trip's path; null when the feed has no shapes.
    public let tripGeometry: TripGeometry?

    public init(
        gtfsId: String,
        bikesAllowed: BikesAllowed,
        wheelchairAccessible: WheelchairBoarding,
        route: TripRoute,
        stoptimesForDate: [Stoptime],
        directionId: String? = nil,
        tripHeadsign: String? = nil,
        tripGeometry: TripGeometry? = nil
    ) {
        self.gtfsId = gtfsId
        self.bikesAllowed = bikesAllowed
        self.wheelchairAccessible = wheelchairAccessible
        self.route = route
        self.stoptimesForDate = stoptimesForDate
        self.directionId = directionId
        self.tripHeadsign = tripHeadsign
        self.tripGeometry = tripGeometry
    }
}
