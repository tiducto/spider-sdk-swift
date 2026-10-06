/// Progress, with the itineraries that became final since the previous `chunk`.
public struct PlanStreamChunkEvent: Codable, Sendable {
    /// Seconds of the window searched so far.
    public let frontier: Int
    /// Itineraries found so far.
    public let found: Int
    /// Itineraries sent so far, this chunk's included.
    public let finalized: Int
    /// Itineraries that became final with this chunk.
    public let results: [Itinerary]

    public init(
        frontier: Int,
        found: Int,
        finalized: Int,
        results: [Itinerary]
    ) {
        self.frontier = frontier
        self.found = found
        self.finalized = finalized
        self.results = results
    }
}
