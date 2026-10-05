public struct PlanConnectionVariables: Codable, Sendable {
    public let dateTime: PlanDateTimeInput
    public let origin: PlanLabeledLocationInput
    public let destination: PlanLabeledLocationInput
    public let searchWindow: String
    public let via: [PlanViaLocationInput]?
    public let modes: PlanModesInput?
    public let preferences: PlanPreferencesInput?
    /// Delay-aware planning level; omitted plans on the timetable.
    public let reliability: Reliability?
    public let before: String?
    public let after: String?

    public init(
        dateTime: PlanDateTimeInput,
        origin: PlanLabeledLocationInput,
        destination: PlanLabeledLocationInput,
        searchWindow: String,
        via: [PlanViaLocationInput]? = nil,
        modes: PlanModesInput? = nil,
        preferences: PlanPreferencesInput? = nil,
        reliability: Reliability? = nil,
        before: String? = nil,
        after: String? = nil
    ) {
        self.dateTime = dateTime
        self.origin = origin
        self.destination = destination
        self.searchWindow = searchWindow
        self.via = via
        self.modes = modes
        self.preferences = preferences
        self.reliability = reliability
        self.before = before
        self.after = after
    }
}
