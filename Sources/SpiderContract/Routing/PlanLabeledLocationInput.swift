/// An origin or destination.
public struct PlanLabeledLocationInput: Codable, Sendable {
    public let location: PlanLocationInput

    public init(
        location: PlanLocationInput
    ) {
        self.location = location
    }
}
