public struct PlanVisitViaLocationInput: Codable, Sendable {
    public let coordinate: PlanCoordinateInput?
    public let label: String?
    public let minimumWaitTime: String?
    public let stopLocationIds: [String]?

    public init(
        coordinate: PlanCoordinateInput? = nil,
        label: String? = nil,
        minimumWaitTime: String? = nil,
        stopLocationIds: [String]? = nil
    ) {
        self.coordinate = coordinate
        self.label = label
        self.minimumWaitTime = minimumWaitTime
        self.stopLocationIds = stopLocationIds
    }
}
