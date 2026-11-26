/// Transit modes the search may use: either the modes it may ride (`transit`, each with its own reluctance) or the modes it leaves out (`exclude`), with per-mode reluctances in `costs`. A non-empty `transit` with a non-empty `exclude` or `costs` is a 400 `modes.transit is invalid`.
public struct PlanTransitModesInput: Codable, Sendable {
    /// The modes an itinerary may ride, each with an optional reluctance. Absent or empty means every mode.
    public let transit: [PlanTransitModePreferenceInput]?
    /// The modes no itinerary may ride; every other mode stays usable, including one `TransitMode` gains later. Absent or empty excludes nothing. A value outside `TransitMode` is a 400 `modes.transit.exclude is invalid`. Never with a non-empty `transit`.
    public let exclude: [TransitMode]?
    /// A reluctance per listed mode that restricts no mode: the cost `transit[].cost.reluctance` gives, for a request that names its modes by `exclude` or names none. A Spider extension: OTP 2.10 takes a mode's reluctance only in its allow-list. A mode not listed keeps reluctance 1, and a listed mode that `exclude` names stays excluded. Absent or empty changes no cost. A mode listed twice is a 400 `modes.transit.costs is invalid`. Never with a non-empty `transit`, which carries its modes' reluctances itself.
    public let costs: [TransitModeCostInput]?

    public init(
        transit: [PlanTransitModePreferenceInput]? = nil,
        exclude: [TransitMode]? = nil,
        costs: [TransitModeCostInput]? = nil
    ) {
        self.transit = transit
        self.exclude = exclude
        self.costs = costs
    }
}
