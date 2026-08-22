public struct AlightPreferencesInput: Codable, Sendable {
    public let slack: String?

    public init(
        slack: String? = nil
    ) {
        self.slack = slack
    }
}
