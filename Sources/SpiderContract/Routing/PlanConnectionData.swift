public struct PlanConnectionData: Codable, Sendable {
    public let planConnection: PlanConnection?

    public init(
        planConnection: PlanConnection? = nil
    ) {
        self.planConnection = planConnection
    }
}
