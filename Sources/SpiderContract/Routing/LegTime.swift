public struct LegTime: Codable, Sendable {
    public let scheduledTime: String
    public let estimated: RealTimeEstimate?

    public init(
        scheduledTime: String,
        estimated: RealTimeEstimate? = nil
    ) {
        self.scheduledTime = scheduledTime
        self.estimated = estimated
    }
}
