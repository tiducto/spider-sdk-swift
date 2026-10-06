/// Wheelchair preferences.
public struct WheelchairPreferencesInput: Codable, Sendable {
    /// Consider wheelchair accessibility in routing. The feed's accessibility data limits what this guarantees.
    public let enabled: Bool?

    public init(
        enabled: Bool? = nil
    ) {
        self.enabled = enabled
    }
}
