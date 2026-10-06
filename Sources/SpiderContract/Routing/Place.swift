public struct Place: Codable, Sendable {
    public let name: String?
    /// Null when the place is not a stop, as for an origin or destination coordinate.
    public let stop: Stop?

    public init(
        name: String? = nil,
        stop: Stop? = nil
    ) {
        self.name = name
        self.stop = stop
    }
}
