public struct PlanPassThroughViaLocationInput: Codable, Sendable {
    public let stopLocationIds: [String]
    public let label: String?

    public init(
        stopLocationIds: [String],
        label: String? = nil
    ) {
        self.stopLocationIds = stopLocationIds
        self.label = label
    }
}
