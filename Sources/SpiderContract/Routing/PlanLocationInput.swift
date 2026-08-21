public struct PlanLocationInput: Codable, Sendable {
    public let coordinate: PlanCoordinateInput?
    public let stopLocation: PlanStopLocationInput?

    public init(
        coordinate: PlanCoordinateInput? = nil,
        stopLocation: PlanStopLocationInput? = nil
    ) {
        self.coordinate = coordinate
        self.stopLocation = stopLocation
    }
}
