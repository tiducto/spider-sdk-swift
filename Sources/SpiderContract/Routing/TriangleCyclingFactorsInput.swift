public struct TriangleCyclingFactorsInput: Codable, Sendable {
    public let flatness: Double
    public let safety: Double
    public let time: Double

    public init(
        flatness: Double,
        safety: Double,
        time: Double
    ) {
        self.flatness = flatness
        self.safety = safety
        self.time = time
    }
}
