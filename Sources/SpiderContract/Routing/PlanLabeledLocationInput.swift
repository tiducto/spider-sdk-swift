public struct PlanLabeledLocationInput: Codable, Sendable {
    public let location: PlanLocationInput
    public let label: String?

    public init(
        location: PlanLocationInput,
        label: String? = nil
    ) {
        self.location = location
        self.label = label
    }
}
