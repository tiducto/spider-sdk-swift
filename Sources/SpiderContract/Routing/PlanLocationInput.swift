/// Exactly one of `coordinate`, `stopLocation`.
public struct PlanLocationInput: Codable, Sendable {
    /// A point; the journey walks between it and the stops.
    public let coordinate: PlanCoordinateInput?
    /// A stop or a station.
    public let stopLocation: PlanStopLocationInput?

    public init(
        coordinate: PlanCoordinateInput? = nil,
        stopLocation: PlanStopLocationInput? = nil
    ) {
        self.coordinate = coordinate
        self.stopLocation = stopLocation
    }
}
