/// Exactly one of `earliestDeparture`, `latestArrival`. Both are RFC 3339 date-times with an offset, e.g. `2026-10-07T08:00:00+02:00`.
public struct PlanDateTimeInput: Codable, Sendable {
    /// Depart at or after this time.
    public let earliestDeparture: String?
    /// Arrive at or before this time.
    public let latestArrival: String?

    public init(
        earliestDeparture: String? = nil,
        latestArrival: String? = nil
    ) {
        self.earliestDeparture = earliestDeparture
        self.latestArrival = latestArrival
    }
}
