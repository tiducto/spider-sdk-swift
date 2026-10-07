/// Exactly one of `coordinate`, `stopLocation`; neither or both is a 400 naming `origin.location` or `destination.location`.
public struct PlanLocationInput: Codable, Sendable {
    /// A point; the journey walks between it and the stops.
    public let coordinate: AnyCodable?
    /// A stop or a station.
    public let stopLocation: AnyCodable?

    public init(
        coordinate: AnyCodable? = nil,
        stopLocation: AnyCodable? = nil
    ) {
        self.coordinate = coordinate
        self.stopLocation = stopLocation
    }
}
