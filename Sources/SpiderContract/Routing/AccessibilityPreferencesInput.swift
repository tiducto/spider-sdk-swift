public struct AccessibilityPreferencesInput: Codable, Sendable {
    public let wheelchair: WheelchairPreferencesInput?

    public init(
        wheelchair: WheelchairPreferencesInput? = nil
    ) {
        self.wheelchair = wheelchair
    }
}
