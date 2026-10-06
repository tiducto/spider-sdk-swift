/// A stop or a station.
public struct PlanStopLocationInput: Codable, Sendable {
    /// Feed-prefixed id of a stop or station (`<feedId>:<id>`).
    public let stopLocationId: String

    public init(
        stopLocationId: String
    ) {
        self.stopLocationId = stopLocationId
    }
}
