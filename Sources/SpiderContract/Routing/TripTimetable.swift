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
    /// The vehicle running the trip run answered (the requested `serviceDate`, and `startTime` for a frequency-based trip), as the realtime trip update names it. A Spider extension: OTP 2.10 has no vehicle on a trip. Null until a vehicle is matched to the run. Its `wheelchairAccessible` is the vehicle's realtime access, separate from this trip's `wheelchairAccessible`, which stays the timetable's.
    public let vehicle: TripVehicle?

    public init(
        gtfsId: String,
        bikesAllowed: BikesAllowed,
        wheelchairAccessible: WheelchairBoarding,
        route: TripRoute,
        stoptimesForDate: [Stoptime],
        directionId: String? = nil,
        tripHeadsign: String? = nil,
        tripGeometry: TripGeometry? = nil,
        vehicle: TripVehicle? = nil
    ) {
        self.gtfsId = gtfsId
        self.bikesAllowed = bikesAllowed
        self.wheelchairAccessible = wheelchairAccessible
        self.route = route
        self.stoptimesForDate = stoptimesForDate
        self.directionId = directionId
        self.tripHeadsign = tripHeadsign
        self.tripGeometry = tripGeometry
        self.vehicle = vehicle
    }
}
