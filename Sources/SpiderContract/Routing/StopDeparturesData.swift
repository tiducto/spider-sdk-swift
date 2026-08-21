public struct StopDeparturesData: Codable, Sendable {
    public let asStop: StopDeparturesStop?
    public let asStation: StopDeparturesStop?

    public init(
        asStop: StopDeparturesStop? = nil,
        asStation: StopDeparturesStop? = nil
    ) {
        self.asStop = asStop
        self.asStation = asStation
    }
}
