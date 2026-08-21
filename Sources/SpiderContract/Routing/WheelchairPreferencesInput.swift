public struct WheelchairPreferencesInput: Codable, Sendable {
    public let enabled: Bool?

    public init(
        enabled: Bool? = nil
    ) {
        self.enabled = enabled
    }
}
