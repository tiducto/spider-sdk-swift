public struct BoardPreferencesInput: Codable, Sendable {
    public let slack: String?
    public let waitReluctance: Double?

    public init(
        slack: String? = nil,
        waitReluctance: Double? = nil
    ) {
        self.slack = slack
        self.waitReluctance = waitReluctance
    }
}
