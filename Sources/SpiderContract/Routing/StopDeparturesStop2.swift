public struct StopDeparturesStop2: Codable, Sendable {
    public let gtfsId: String
    public let name: String
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
