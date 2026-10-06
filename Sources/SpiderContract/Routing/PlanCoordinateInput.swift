/// A WGS84 point.
public struct PlanCoordinateInput: Codable, Sendable {
    /// Latitude in degrees.
    public let latitude: Double
    /// Longitude in degrees.
    public let longitude: Double

    public init(
        latitude: Double,
        longitude: Double
    ) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
