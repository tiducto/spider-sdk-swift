public struct CyclingOptimizationInput: Codable, Sendable {
    public let triangle: TriangleCyclingFactorsInput?
    public let type: CyclingOptimizationType?

    public init(
        triangle: TriangleCyclingFactorsInput? = nil,
        type: CyclingOptimizationType? = nil
    ) {
        self.triangle = triangle
        self.type = type
    }
}
