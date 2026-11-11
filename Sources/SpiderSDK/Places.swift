import Foundation

/// What a place search hit is. Unrecognized values map to `.unknown`, so a kind added later never fails a search;
/// skip the hits whose kind you don't handle.
public enum PlaceType: String, Sendable, CaseIterable {
    /// A stop. Its `PlaceHit.id` is the feed-prefixed stop id routing takes, e.g. `Location.stop(hit.id)`.
    case stop
    /// A single address (a building with a house number).
    case address
    /// A municipality.
    case place
    /// A point of interest: a university, a hospital, a shopping centre, …
    case poi
    case unknown

    static func fromWire(_ raw: String) -> PlaceType {
        PlaceType(rawValue: raw) ?? .unknown
    }
}

/// One place search hit: a stop, an address, a municipality or a point of interest.
public struct PlaceHit: Sendable, Equatable {
    /// For a `.stop`, the feed-prefixed stop id (`<feedId>:<id>`) routing takes. For any other type an opaque id,
    /// stable across searches.
    public let id: String
    public let type: PlaceType
    /// Display name; a stop's is the operator's own.
    public let name: String
    public let lat: Double
    public let lon: Double
    /// What kind of place it is: for a `.poi` e.g. `university`, `hospital`, `mall`; `municipality` for a `.place`;
    /// `building` (or `recreational`) for an `.address`. Nil for a stop. New values may be added.
    public let category: String?
    /// The administrative areas the place lies in, labelled the same way as a `Stop`'s.
    public let country: String?
    public let region: String?
    public let district: String?
    public let city: String?
    public let suburb: String?
    /// Metres from the search location; present only when the search was given one.
    public let distance: Int?
    /// For a `.stop`, the stop as stop search returns it (code, wheelchair boarding, modes included); nil otherwise.
    public let stop: Stop?
}

private let MAX_PLACE_SEARCH_LIMIT = 20

/// The places surface: search over stops, addresses, municipalities and points of interest in the environment's
/// service area.
public final class SpiderPlaces {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    /// Searches places by free text, best match first.
    ///
    /// Abbreviated and spelled-out forms find each other, and text without diacritics matches text with them. A
    /// query with a house number (any digit, e.g. `Údolní 53`) lists individual addresses; without one, it lists
    /// stops, municipalities and points of interest, and no addresses. Pass `near` to rank the nearer of equally
    /// good matches first and to get each hit's `distance`.
    ///
    /// - Parameters:
    ///   - query: The search text, 2 to 100 characters after trimming whitespace.
    ///   - near: An optional location to rank by and measure `distance` from.
    ///   - limit: The most hits to return, from 1 to 20 (default 10). Outside that range the search fails as
    ///     `.badRequest` (field `limit`) without a request.
    public func search(_ query: String, near: GeoPoint? = nil, limit: Int = 10) async throws -> SpiderResult<[PlaceHit]> {
        guard (1...MAX_PLACE_SEARCH_LIMIT).contains(limit) else { return .failure(outOfRange("limit")) }
        var params: [(String, String)] = [("q", query), ("limit", String(limit))]
        if let near {
            params.append(("latitude", queryNumber(near.lat)))
            params.append(("longitude", queryNumber(near.lng)))
        }
        do {
            let response: PlaceSearchResponse = try await transport.getJson("/places/v1/search", query: params)
            return .success(response.hits.map(toPlaceHit))
        } catch {
            return .failure(toSpiderError(error))
        }
    }
}

// A coordinate in plain decimal notation. Swift's `description` is locale-invariant and shortest-round-trip, but
// switches to exponent form for small magnitudes, which the API doesn't take as a decimal.
private func queryNumber(_ value: Double) -> String {
    let text = String(value)
    guard text.contains("e") else { return text }
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = false
    formatter.maximumFractionDigits = 12
    return formatter.string(from: NSNumber(value: value)) ?? "0"
}

private func toPlaceHit(_ hit: PlaceHitWire) -> PlaceHit {
    PlaceHit(
        id: hit.id, type: PlaceType.fromWire(hit.type), name: hit.name, lat: hit.lat, lon: hit.lon,
        category: hit.category, country: hit.country, region: hit.region, district: hit.district,
        city: hit.city, suburb: hit.suburb, distance: hit.distance, stop: stopOf(hit)
    )
}

// A stop hit carries its stop search hit's members under the same names; other types carry no `gtfsId`.
private func stopOf(_ hit: PlaceHitWire) -> Stop? {
    guard hit.type == PlaceType.stop.rawValue, let gtfsId = hit.gtfsId else { return nil }
    return toStop(StopHit(
        gtfsId: gtfsId, name: hit.name, code: hit.code, wheelchairBoarding: hit.wheelchairBoarding,
        modes: hit.modes, lat: hit.lat, lon: hit.lon, country: hit.country, region: hit.region,
        district: hit.district, city: hit.city, suburb: hit.suburb
    ))
}

// MARK: - wire types (hand-written; not generated)

private struct PlaceSearchResponse: Decodable {
    let hits: [PlaceHitWire]
    let query: String?
}

private struct PlaceHitWire: Decodable {
    let id: String
    let type: String
    let gtfsId: String?
    let name: String
    let code: String?
    let wheelchairBoarding: Int?
    let modes: [String]?
    let lat: Double
    let lon: Double
    let category: String?
    let country: String?
    let region: String?
    let district: String?
    let city: String?
    let suburb: String?
    let distance: Int?
}
