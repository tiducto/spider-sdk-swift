public struct Trip: Codable, Sendable {
    public let gtfsId: String
    public let bikesAllowed: BikesAllowed?

    public init(
        gtfsId: String,
        bikesAllowed: BikesAllowed? = nil
    ) {
        self.gtfsId = gtfsId
        self.bikesAllowed = bikesAllowed
    }
}
