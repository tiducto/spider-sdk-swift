/// `trip` is null for an unknown id.
public struct TripResponse: Codable, Sendable {
    public let trip: TripTimetable?

    public init(
        trip: TripTimetable? = nil
    ) {
        self.trip = trip
    }
}
