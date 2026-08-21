public struct ScooterOptimizationInput: Codable, Sendable {
    public let triangle: TriangleScooterFactorsInput?
    public let type: ScooterOptimizationType?

    public init(
        triangle: TriangleScooterFactorsInput? = nil,
        type: ScooterOptimizationType? = nil
    ) {
        self.triangle = triangle
        self.type = type
    }
}
