/// A WGS84 point.
public struct PlanCoordinateInput: Codable, Sendable {
    /// Latitude in degrees, -90 to 90; rejected, never clamped.
    public let latitude: Double
    /// Longitude in degrees, -180 to 180; rejected, never clamped.
    public let longitude: Double

    public init(
        latitude: Double,
        longitude: Double
    ) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
