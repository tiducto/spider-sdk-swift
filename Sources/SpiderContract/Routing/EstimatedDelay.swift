public struct EstimatedDelay: Codable, Sendable {
    public let reliability: Reliability
    /// Seconds: the level's percentile of the trip's recorded delay at this stop on the service date's day type, from the environment's realtime history; never below 0.
    public let delay: Int

    public init(
        reliability: Reliability,
        delay: Int
    ) {
        self.reliability = reliability
        self.delay = delay
    }
}
