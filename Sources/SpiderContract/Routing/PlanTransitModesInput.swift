public struct PlanTransitModesInput: Codable, Sendable {
    public let access: [PlanAccessMode]?
    public let egress: [PlanEgressMode]?
    public let transfer: [PlanTransferMode]?
    public let transit: [PlanTransitModePreferenceInput]?

    public init(
        access: [PlanAccessMode]? = nil,
        egress: [PlanEgressMode]? = nil,
        transfer: [PlanTransferMode]? = nil,
        transit: [PlanTransitModePreferenceInput]? = nil
    ) {
        self.access = access
        self.egress = egress
        self.transfer = transfer
        self.transit = transit
    }
}
