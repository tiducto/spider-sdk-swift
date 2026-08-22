public struct PlanConnectionVariables: Codable, Sendable {
    public let dateTime: PlanDateTimeInput
    public let origin: PlanLabeledLocationInput
    public let destination: PlanLabeledLocationInput
    public let via: [PlanViaLocationInput]?
    public let modes: PlanModesInput?
    public let preferences: PlanPreferencesInput?
    public let searchWindow: String?
    public let first: Int?
    public let last: Int?
    public let before: String?
    public let after: String?

    public init(
        dateTime: PlanDateTimeInput,
        origin: PlanLabeledLocationInput,
        destination: PlanLabeledLocationInput,
        via: [PlanViaLocationInput]? = nil,
        modes: PlanModesInput? = nil,
        preferences: PlanPreferencesInput? = nil,
        searchWindow: String? = nil,
        first: Int? = nil,
        last: Int? = nil,
        before: String? = nil,
        after: String? = nil
    ) {
        self.dateTime = dateTime
        self.origin = origin
        self.destination = destination
        self.via = via
        self.modes = modes
        self.preferences = preferences
        self.searchWindow = searchWindow
        self.first = first
        self.last = last
        self.before = before
        self.after = after
    }
}
