/// `trip` is null for an id that resolves to no trip.
public struct TripResponse: Codable, Sendable {
    public let trip: AnyCodable

    public init(
        trip: AnyCodable
    ) {
        self.trip = trip
    }
}
