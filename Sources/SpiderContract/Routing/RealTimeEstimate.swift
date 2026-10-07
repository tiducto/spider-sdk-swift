public struct RealTimeEstimate: Codable, Sendable {
    public let time: String
    /// The difference from the schedule, as an ISO-8601 duration such as `PT2M`; negative when early, such as `-PT1M`.
    public let delay: String

    public init(
        time: String,
        delay: String
    ) {
        self.time = time
        self.delay = delay
    }
}
