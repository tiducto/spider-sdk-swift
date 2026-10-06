/// Alighting preferences.
public struct AlightPreferencesInput: Codable, Sendable {
    /// Least time needed to alight, as an ISO-8601 duration: `PT0S` to `PT1H`; rejected, never clamped.
    public let slack: String?

    public init(
        slack: String? = nil
    ) {
        self.slack = slack
    }
}
