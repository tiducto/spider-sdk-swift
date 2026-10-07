/// `stop` is the board, or null for an id that resolves to no stop or station.
public struct DeparturesResponse: Codable, Sendable {
    public let stop: DepartureBoard?

    public init(
        stop: DepartureBoard? = nil
    ) {
        self.stop = stop
    }
}
