public struct PlanStopLocationInput: Codable, Sendable {
    public let stopLocationId: String

    public init(
        stopLocationId: String
    ) {
        self.stopLocationId = stopLocationId
    }
}
