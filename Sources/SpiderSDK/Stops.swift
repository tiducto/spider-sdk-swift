import Foundation

/// A stop returned by search. A station's platforms are folded into it, so the station is returned instead.
public struct Stop: Sendable, Equatable {
    public let gtfsId: String
    public let name: String
    /// The short public code riders know the stop by (GTFS `stop_code`), when the feed has one.
    public let code: String?
    /// GTFS `location_type`: `0` a stop or platform, `1` a station. Nil means a stop.
    public let locationType: Int?
    /// Whether a rider in a wheelchair can board here (GTFS `wheelchair_boarding`). Nil = no information; a code
    /// GTFS doesn't define is `.unknown`.
    public let wheelchairBoarding: WheelchairBoarding?
    /// The modes of the routes serving the stop (a station's cover all its platforms), each once. Empty when no
    /// route serves it. A mode this SDK doesn't know is `.unknown`.
    public let modes: [TransitMode]
    public let lat: Double?
    public let lon: Double?
    public let country: String?
    public let region: String?
    public let district: String?
    public let city: String?
    public let suburb: String?
}

/// A WGS84 point. `lng` mirrors the transit-industry `lon`, but the input side reads as lat/lng.
public struct GeoPoint: Sendable, Equatable {
    public let lat: Double
    public let lng: Double
    public init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }
}

/// A WGS84 bounding box: south-west corner (`min*`) to north-east corner (`max*`).
public struct GeoBoundingBox: Sendable, Equatable {
    public let minLat: Double
    public let minLng: Double
    public let maxLat: Double
    public let maxLng: Double
    public init(minLat: Double, minLng: Double, maxLat: Double, maxLng: Double) {
        self.minLat = minLat
        self.minLng = minLng
        self.maxLat = maxLat
        self.maxLng = maxLng
    }
}

/// Search criteria. `name` is free text matched against a stop's name, its code, its town (`city`) and the
/// district within the town (`suburb`); the admin fields narrow it by administrative area, `modes` by the modes
/// serving the stop, and the geo fields by location. `radiusMeters` and `sortByDistance` both require `near`.
public struct StopFilter: Sendable {
    public var name: String?
    public var country: String?
    public var region: String?
    public var district: String?
    public var city: String?
    public var suburb: String?
    /// Restrict to stops served by at least one of these modes. Empty (the default) means any mode.
    public var modes: [TransitMode]
    /// Geographic anchor for `radiusMeters` and `sortByDistance`.
    public var near: GeoPoint?
    /// Restrict to stops within this many metres of `near`. Requires `near`.
    public var radiusMeters: Double?
    /// Restrict to stops inside this box. Independent of `near`.
    public var bbox: GeoBoundingBox?
    /// Sort results by distance from `near`, nearest first. Requires `near`.
    public var sortByDistance: Bool
    /// The most hits to return, from 1 to 50 (default 20). Outside that range the search fails as `.badRequest`
    /// (field `limit`) without a request.
    public var limit: Int

    public init(
        name: String? = nil,
        country: String? = nil,
        region: String? = nil,
        district: String? = nil,
        city: String? = nil,
        suburb: String? = nil,
        modes: [TransitMode] = [],
        near: GeoPoint? = nil,
        radiusMeters: Double? = nil,
        bbox: GeoBoundingBox? = nil,
        sortByDistance: Bool = false,
        limit: Int = 20
    ) {
        self.name = name
        self.country = country
        self.region = region
        self.district = district
        self.city = city
        self.suburb = suburb
        self.modes = modes
        self.near = near
        self.radiusMeters = radiusMeters
        self.bbox = bbox
        self.sortByDistance = sortByDistance
        self.limit = limit
    }
}

private let MAX_STOP_SEARCH_LIMIT = 50

/// The stops surface: text + administrative-area stop search.
public final class SpiderStops {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    /// Searches stops by free text, administrative area, and/or geography.
    public func search(_ filter: StopFilter) async throws -> SpiderResult<[Stop]> {
        do {
            let body = try buildStopSearchRequest(filter)
            let response: StopSearchResponse = try await transport.postJson("/stops/search", body, errorMessage: extractStopError)
            return .success(response.hits.map(toStop))
        } catch {
            return .failure(toSpiderError(error))
        }
    }

    /// Looks up a single stop by its GTFS id. Returns the stop, or nil when no stop matches; throws a
    /// `SpiderError` on a transport failure.
    public func byId(_ gtfsId: String) async throws -> Stop? {
        do {
            let body = StopSearchRequest(q: "", filter: "\"gtfsId\" = \"\(escapeFilter(gtfsId))\"", sort: nil, limit: 1)
            let response: StopSearchResponse = try await transport.postJson("/stops/search", body, errorMessage: extractStopError)
            return response.hits.first.map(toStop)
        } catch {
            throw toSpiderError(error)
        }
    }

    /// Stops around a point, nearest first. Pass `radiusMeters` to bound the search.
    public func near(_ lat: Double, _ lng: Double, radiusMeters: Double? = nil, limit: Int = 20) async throws -> SpiderResult<[Stop]> {
        try await search(StopFilter(near: GeoPoint(lat: lat, lng: lng), radiusMeters: radiusMeters, sortByDistance: true, limit: limit))
    }

    /// Stops inside a bounding box.
    public func within(_ bbox: GeoBoundingBox, limit: Int = 20) async throws -> SpiderResult<[Stop]> {
        try await search(StopFilter(bbox: bbox, limit: limit))
    }
}

// Builds the wire request, validating the limit and that the geo options that need an anchor have one, and
// adding the distance sort when requested.
private func buildStopSearchRequest(_ filter: StopFilter) throws -> StopSearchRequest {
    guard (1...MAX_STOP_SEARCH_LIMIT).contains(filter.limit) else { throw outOfRange("limit") }
    if filter.radiusMeters != nil && filter.near == nil {
        throw SpiderError(code: .unknown, message: "stops.search: `radiusMeters` requires `near`")
    }
    if filter.sortByDistance && filter.near == nil {
        throw SpiderError(code: .unknown, message: "stops.search: `sortByDistance` requires `near`")
    }
    var sort: [String]?
    if filter.sortByDistance, let near = filter.near {
        sort = ["_geoPoint(\(near.lat), \(near.lng)):asc"]
    }
    return StopSearchRequest(q: filter.name ?? "", filter: buildFilterExpression(filter), sort: sort, limit: filter.limit)
}

// The admin keys, in the fixed order they compose into the filter expression, followed by the geo clauses.
private func buildFilterExpression(_ filter: StopFilter) -> String? {
    let pairs: [(String, String?)] = [
        ("country", filter.country),
        ("region", filter.region),
        ("district", filter.district),
        ("city", filter.city),
        ("suburb", filter.suburb),
    ]
    var clauses: [String] = []
    for (key, value) in pairs {
        guard let value, !value.isEmpty else { continue }
        clauses.append("\"\(escapeFilter(key))\" = \"\(escapeFilter(value))\"")
    }
    if !filter.modes.isEmpty {
        let values = filter.modes.map { "\"\(escapeFilter($0.rawValue))\"" }.joined(separator: ", ")
        clauses.append("\"modes\" IN [\(values)]")
    }
    if let radius = filter.radiusMeters, let near = filter.near {
        clauses.append("_geoRadius(\(near.lat), \(near.lng), \(radius))")
    }
    if let bbox = filter.bbox {
        clauses.append("_geoBoundingBox([\(bbox.maxLat), \(bbox.maxLng)], [\(bbox.minLat), \(bbox.minLng)])")
    }
    return clauses.isEmpty ? nil : clauses.joined(separator: " AND ")
}

// Escape backslashes then double-quotes (order matters) for a stops search index filter literal.
private func escapeFilter(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
}

private func extractStopError(_ text: String) -> String {
    if let data = text.data(using: .utf8),
       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let message = obj["message"] as? String {
        return message
    }
    return String(text.prefix(300))
}

private func toStop(_ hit: StopHit) -> Stop {
    Stop(
        gtfsId: hit.gtfsId, name: hit.name, code: hit.code, locationType: hit.locationType,
        wheelchairBoarding: wheelchairBoarding(gtfs: hit.wheelchairBoarding),
        modes: (hit.modes ?? []).map { TransitMode(rawValue: $0) ?? .unknown }, lat: hit.lat, lon: hit.lon,
        country: hit.country, region: hit.region, district: hit.district, city: hit.city, suburb: hit.suburb
    )
}

// GTFS `wheelchair_boarding` codes onto the routing enum: 0 or absent is no information, 1 possible, 2 not
// possible, and a code GTFS doesn't define is `.unknown`.
private func wheelchairBoarding(gtfs code: Int?) -> WheelchairBoarding? {
    switch code {
    case nil, 0: return nil
    case 1: return .possible
    case 2: return .notPossible
    default: return .unknown
    }
}

// MARK: - wire types (hand-written, mirroring the TS SDK; not generated)

private struct StopSearchRequest: Encodable {
    let q: String
    let filter: String?
    let sort: [String]?
    let limit: Int
}

private struct StopSearchResponse: Decodable {
    let hits: [StopHit]
    let query: String?
}

private struct StopHit: Decodable {
    let gtfsId: String
    let name: String
    let code: String?
    let locationType: Int?
    let wheelchairBoarding: Int?
    let modes: [String]?
    let lat: Double?
    let lon: Double?
    let country: String?
    let region: String?
    let district: String?
    let city: String?
    let suburb: String?
}
