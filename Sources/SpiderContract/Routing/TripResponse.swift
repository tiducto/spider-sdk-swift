/// `trip` is null for an id that resolves to no trip.
public struct TripResponse: Codable, Sendable {
    public let trip: TripTimetable?

    public init(
        trip: TripTimetable? = nil
    ) {
        self.trip = trip
    }
}
