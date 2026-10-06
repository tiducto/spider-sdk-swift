/// Boarding preferences.
public struct BoardPreferencesInput: Codable, Sendable {
    /// How much worse waiting at a stop is than riding for the same time, a multiplier from 0.1 to 100000; rejected, never clamped.
    public let waitReluctance: Double?
    /// Least time at the stop before boarding, as an ISO-8601 duration: `PT0S` to `PT1H`; rejected, never clamped.
    public let slack: String?

    public init(
        waitReluctance: Double? = nil,
        slack: String? = nil
    ) {
        self.waitReluctance = waitReluctance
        self.slack = slack
    }
}
