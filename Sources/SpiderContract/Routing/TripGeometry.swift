public struct TripGeometry: Codable, Sendable {
    public let points: String?
    public let length: Int?

    public init(
        points: String? = nil,
        length: Int? = nil
    ) {
        self.points = points
        self.length = length
    }
}
