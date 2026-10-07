/// Accessibility preferences.
public struct AccessibilityPreferencesInput: Codable, Sendable {
    public let wheelchair: AnyCodable?

    public init(
        wheelchair: AnyCodable? = nil
    ) {
        self.wheelchair = wheelchair
    }
}
