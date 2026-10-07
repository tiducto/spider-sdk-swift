/// Departures board for one platform (a stop id) or a whole station (a station id), realtime merged in. A trip's final stop, a canceled departure and a departure that does not allow boarding give no row.
public struct DepartureBoard: Codable, Sendable {
    public let gtfsId: String
    public let name: String
    public let stoptimesWithoutPatterns: [StopDeparturesStoptime]
    /// Null on a station board.
    public let wheelchairBoarding: WheelchairBoarding?

    public init(
        gtfsId: String,
        name: String,
        stoptimesWithoutPatterns: [StopDeparturesStoptime],
        wheelchairBoarding: WheelchairBoarding? = nil
    ) {
        self.gtfsId = gtfsId
        self.name = name
        self.stoptimesWithoutPatterns = stoptimesWithoutPatterns
        self.wheelchairBoarding = wheelchairBoarding
    }
}
