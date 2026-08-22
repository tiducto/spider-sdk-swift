public struct TripData: Codable, Sendable {
    public let trip: TripTrip?

    public init(
        trip: TripTrip? = nil
    ) {
        self.trip = trip
    }
}
