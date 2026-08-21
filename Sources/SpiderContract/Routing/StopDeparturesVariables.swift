public struct StopDeparturesVariables: Codable, Sendable {
    public let id: String
    public let numberOfDepartures: Int?
    public let startTime: Int?
    public let timeRange: Int?

    public init(
        id: String,
        numberOfDepartures: Int? = nil,
        startTime: Int? = nil,
        timeRange: Int? = nil
    ) {
        self.id = id
        self.numberOfDepartures = numberOfDepartures
        self.startTime = startTime
        self.timeRange = timeRange
    }
}
