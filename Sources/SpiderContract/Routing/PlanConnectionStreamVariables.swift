public struct PlanConnectionStreamVariables: Codable, Sendable {
    public let dateTime: PlanDateTimeInput
    public let origin: PlanLabeledLocationInput
    public let destination: PlanLabeledLocationInput
    public let via: [PlanViaLocationInput]?
    public let modes: PlanModesInput?
    public let preferences: PlanPreferencesInput?
    public let targetResults: Int?
    public let maxWindow: String?
    public let before: String?
    public let after: String?

    public init(
        dateTime: PlanDateTimeInput,
        origin: PlanLabeledLocationInput,
        destination: PlanLabeledLocationInput,
        via: [PlanViaLocationInput]? = nil,
        modes: PlanModesInput? = nil,
        preferences: PlanPreferencesInput? = nil,
        targetResults: Int? = nil,
        maxWindow: String? = nil,
        before: String? = nil,
        after: String? = nil
    ) {
        self.dateTime = dateTime
        self.origin = origin
        self.destination = destination
        self.via = via
        self.modes = modes
        self.preferences = preferences
        self.targetResults = targetResults
        self.maxWindow = maxWindow
        self.before = before
        self.after = after
    }
}
