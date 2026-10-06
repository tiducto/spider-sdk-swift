public struct TripGeometry: Codable, Sendable {
    /// Encoded polyline (precision 1e5).
    public let points: String?
    /// Number of points.
    public let length: Int?

    public init(
        points: String? = nil,
        length: Int? = nil
    ) {
        self.points = points
        self.length = length
    }
}
