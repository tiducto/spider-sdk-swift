public struct Geometry: Codable, Sendable {
    public let points: String?

    public init(
        points: String? = nil
    ) {
        self.points = points
    }
}
