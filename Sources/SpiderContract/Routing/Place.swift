public struct Place: Codable, Sendable {
    /// The stop's name; `Origin` or `Destination` for a coordinate.
    public let name: String
    /// The position in the leg's trip of this stop time, as the trip's `stopPosition`. Null unless the leg is a ride.
    public let stopPosition: Int?
    /// Null when the place is not a stop, as for an origin or destination coordinate.
    public let stop: Stop?

    public init(
        name: String,
        stopPosition: Int? = nil,
        stop: Stop? = nil
    ) {
        self.name = name
        self.stopPosition = stopPosition
        self.stop = stop
    }
}
