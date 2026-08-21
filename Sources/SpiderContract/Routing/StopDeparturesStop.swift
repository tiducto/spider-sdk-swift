public struct StopDeparturesStop: Codable, Sendable {
    public let gtfsId: String
    public let name: String
    public let wheelchairBoarding: WheelchairBoarding?
    public let stoptimesWithoutPatterns: [Stoptime]?

    public init(
        gtfsId: String,
        name: String,
        wheelchairBoarding: WheelchairBoarding? = nil,
        stoptimesWithoutPatterns: [Stoptime]? = nil
    ) {
        self.gtfsId = gtfsId
        self.name = name
        self.wheelchairBoarding = wheelchairBoarding
        self.stoptimesWithoutPatterns = stoptimesWithoutPatterns
    }
}
