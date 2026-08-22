public struct PlanDateTimeInput: Codable, Sendable {
    public let earliestDeparture: String?
    public let latestArrival: String?

    public init(
        earliestDeparture: String? = nil,
        latestArrival: String? = nil
    ) {
        self.earliestDeparture = earliestDeparture
        self.latestArrival = latestArrival
    }
}
