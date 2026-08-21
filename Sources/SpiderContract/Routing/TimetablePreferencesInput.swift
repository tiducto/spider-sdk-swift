public struct TimetablePreferencesInput: Codable, Sendable {
    public let excludeRealTimeUpdates: Bool?
    public let includePlannedCancellations: Bool?
    public let includeRealTimeCancellations: Bool?

    public init(
        excludeRealTimeUpdates: Bool? = nil,
        includePlannedCancellations: Bool? = nil,
        includeRealTimeCancellations: Bool? = nil
    ) {
        self.excludeRealTimeUpdates = excludeRealTimeUpdates
        self.includePlannedCancellations = includePlannedCancellations
        self.includeRealTimeCancellations = includeRealTimeCancellations
    }
}
