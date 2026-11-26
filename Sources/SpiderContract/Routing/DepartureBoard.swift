/// Departures for one stop (a stop id) or a whole station (a station id), realtime merged in. A trip's final stop, a canceled departure and a departure that does not allow boarding give no row.
public struct DepartureBoard: Codable, Sendable {
    public let gtfsId: String
    public let name: String
    public let stoptimesWithoutPatterns: [StopDeparturesStoptime]
    /// Null for a station's departures.
    public let wheelchairBoarding: WheelchairBoarding?
    /// The station the stop belongs to, as OTP's `Stop.parentStation`; its `gtfsId` asks for the whole station's departures. Null for a station's departures and for a stop without one.
    public let parentStation: ParentStation?

    public init(
        gtfsId: String,
        name: String,
        stoptimesWithoutPatterns: [StopDeparturesStoptime],
        wheelchairBoarding: WheelchairBoarding? = nil,
        parentStation: ParentStation? = nil
    ) {
        self.gtfsId = gtfsId
        self.name = name
        self.stoptimesWithoutPatterns = stoptimesWithoutPatterns
        self.wheelchairBoarding = wheelchairBoarding
        self.parentStation = parentStation
    }
}
