public struct Place: Codable, Sendable {
    /// The stop's name; `Origin` or `Destination` for a coordinate.
    public let name: String
    /// Null when the place is not a stop, as for an origin or destination coordinate.
    public let stop: AnyCodable

    public init(
        name: String,
        stop: AnyCodable
    ) {
        self.name = name
        self.stop = stop
    }
}
