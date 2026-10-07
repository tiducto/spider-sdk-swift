public struct Geometry: Codable, Sendable {
    /// Encoded polyline (precision 1e5).
    public let points: String

    public init(
        points: String
    ) {
        self.points = points
    }
}
