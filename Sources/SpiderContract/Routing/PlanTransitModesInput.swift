/// Transit modes the search may use: either the modes it may ride (`transit`) or the modes it leaves out (`exclude`). Both non-empty in one request is a 400 `modes.transit is invalid`.
public struct PlanTransitModesInput: Codable, Sendable {
    /// The modes an itinerary may ride, each with an optional reluctance. Absent or empty means every mode.
    public let transit: [PlanTransitModePreferenceInput]?
    /// The modes no itinerary may ride; every other mode stays usable, including one `TransitMode` gains later. Absent or empty excludes nothing. A value outside `TransitMode` is a 400 `modes.transit.exclude is invalid`. Never with a non-empty `transit`.
    public let exclude: [TransitMode]?

    public init(
        transit: [PlanTransitModePreferenceInput]? = nil,
        exclude: [TransitMode]? = nil
    ) {
        self.transit = transit
        self.exclude = exclude
    }
}
