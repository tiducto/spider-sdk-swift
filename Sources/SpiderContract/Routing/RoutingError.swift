/// Why the router declined the plan: `LOCATION_NOT_FOUND` for an unknown stop id (`inputField` `FROM`, `TO` or `VIA`), `WALKING_BETTER_THAN_TRANSIT` when the origin and destination are close enough that walking beats transit (`inputField` null), or `OUTSIDE_SERVICE_PERIOD` for a date the feed does not cover (`DATE_TIME`). New codes may be added.
public struct RoutingError: Codable, Sendable {
    public let code: RoutingErrorCode
    public let description: String
    /// The request member at fault; null when it is none in particular.
    public let inputField: InputField?

    public init(
        code: RoutingErrorCode,
        description: String,
        inputField: InputField? = nil
    ) {
        self.code = code
        self.description = description
        self.inputField = inputField
    }
}
