public struct StopDeparturesVariables: Codable, Sendable {
    public let id: String
    public let numberOfDepartures: Int
    public let timeRange: Int
    public let startTime: Int?

    public init(
        id: String,
        numberOfDepartures: Int,
        timeRange: Int,
        startTime: Int? = nil
    ) {
        self.id = id
        self.numberOfDepartures = numberOfDepartures
        self.timeRange = timeRange
        self.startTime = startTime
    }
}
