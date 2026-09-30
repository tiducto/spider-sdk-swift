public struct StopDeparturesData: Codable, Sendable {
    public let asStop: StopDeparturesStop2?
    public let asStation: StopDeparturesStop2?

    public init(
        asStop: StopDeparturesStop2? = nil,
        asStation: StopDeparturesStop2? = nil
    ) {
        self.asStop = asStop
        self.asStation = asStation
    }
}
