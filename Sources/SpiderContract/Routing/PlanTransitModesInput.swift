/// Transit modes the search may use.
public struct PlanTransitModesInput: Codable, Sendable {
    /// The modes an itinerary may ride, each with an optional reluctance. Absent means every mode.
    public let transit: [PlanTransitModePreferenceInput]?

    public init(
        transit: [PlanTransitModePreferenceInput]? = nil
    ) {
        self.transit = transit
    }
}
