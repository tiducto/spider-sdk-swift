public struct Stoptime: Codable, Sendable {
    public let serviceDay: Int?
    public let scheduledDeparture: Int?
    public let realtimeDeparture: Int?
    public let realtime: Bool?
    public let realtimeState: RealtimeState?
    public let headsign: String?
    public let trip: StopDeparturesTrip?

    public init(
        serviceDay: Int? = nil,
        scheduledDeparture: Int? = nil,
        realtimeDeparture: Int? = nil,
        realtime: Bool? = nil,
        realtimeState: RealtimeState? = nil,
        headsign: String? = nil,
        trip: StopDeparturesTrip? = nil
    ) {
        self.serviceDay = serviceDay
        self.scheduledDeparture = scheduledDeparture
        self.realtimeDeparture = realtimeDeparture
        self.realtime = realtime
        self.realtimeState = realtimeState
        self.headsign = headsign
        self.trip = trip
    }
}
