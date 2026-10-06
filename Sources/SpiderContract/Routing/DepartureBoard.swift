/// Departures board for one platform (a stop id) or a whole station (a station id), realtime merged in. A trip's final stop gives no row, since nobody boards there.
public struct DepartureBoard: Codable, Sendable {
    public let gtfsId: String
    public let name: String
    /// Null on a station board.
    public let wheelchairBoarding: WheelchairBoarding?
    public let stoptimesWithoutPatterns: [StopDeparturesStoptime]?

    public init(
        gtfsId: String,
        name: String,
        wheelchairBoarding: WheelchairBoarding? = nil,
        stoptimesWithoutPatterns: [StopDeparturesStoptime]? = nil
    ) {
        self.gtfsId = gtfsId
        self.name = name
        self.wheelchairBoarding = wheelchairBoarding
        self.stoptimesWithoutPatterns = stoptimesWithoutPatterns
    }
}
