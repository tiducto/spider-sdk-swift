/// Departures board for one platform (a stop id) or a whole station (a station id), realtime merged in. A trip's final stop, a canceled departure and a departure that does not allow boarding give no row.
public struct DepartureBoard: Codable, Sendable {
    public let gtfsId: String
    public let name: String
    /// Null on a station board.
    public let wheelchairBoarding: AnyCodable
    public let stoptimesWithoutPatterns: [StopDeparturesStoptime]

    public init(
        gtfsId: String,
        name: String,
        wheelchairBoarding: AnyCodable,
        stoptimesWithoutPatterns: [StopDeparturesStoptime]
    ) {
        self.gtfsId = gtfsId
        self.name = name
        self.wheelchairBoarding = wheelchairBoarding
        self.stoptimesWithoutPatterns = stoptimesWithoutPatterns
    }
}
