public struct TripGeometry: Codable, Sendable {
    /// Encoded polyline (precision 1e6).
    public let points: String
    /// Number of points.
    public let length: Int

    public init(
        points: String,
        length: Int
    ) {
        self.points = points
        self.length = length
    }
}
