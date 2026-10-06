import Foundation

// MARK: - Public realtime models

/// How fresh a realtime feed is. Timestamps are epoch milliseconds; `staleSeconds` is age in seconds.
public struct FeedFreshness: Sendable, Equatable {
    public let feedTimestampEpochMs: Int64?
    public let staleSeconds: Double?
}

/// A vehicle's live position. GTFS-RT producers populate wildly different subsets, so every field is optional.
/// `tripId`, `routeId`, `stopId` and `vehicleId` are feed-prefixed (`<feedId>:<id>`), like routing's ids.
public struct LiveVehicle: Sendable, Equatable {
    public let tripId: String?
    public let routeId: String?
    public let vehicleId: String?
    public let label: String?
    public let latitude: Double?
    public let longitude: Double?
    public let bearing: Double?
    public let speed: Double?
    public let stopId: String?
    public let currentStatus: String?
    public let occupancy: OccupancyStatus?
    public let timestampEpochMs: Int64?
}

/// A single trip's live vehicle plus feed freshness (`vehicle` nil = none currently reporting).
public struct LiveVehicleUpdate: Sendable, Equatable {
    public let vehicle: LiveVehicle?
    public let freshness: FeedFreshness
}

/// Live positions for a set of trips, plus the trip ids that had no live vehicle.
public struct VehiclePositions: Sendable, Equatable {
    public let vehicles: [LiveVehicle]
    public let missing: [String]
    public let freshness: FeedFreshness
}

/// One stop's realtime deviation within a trip.
public struct StopTimeUpdate: Sendable, Equatable {
    public let stopId: String?
    public let stopSequence: Int?
    public let arrivalDelay: Int?
    public let departureDelay: Int?
    public let scheduleRelationship: String?
}

/// A trip's live schedule deviation. Delay values are in seconds.
public struct TripDelay: Sendable, Equatable {
    public let tripId: String?
    public let routeId: String?
    public let delaySeconds: Int?
    public let scheduleRelationship: String?
    public let stopTimeUpdates: [StopTimeUpdate]
}

/// Delays for one GTFS service date: those the feed reported, and the `missing` trip ids it didn't. The same
/// `tripId` on two dates is two distinct instances, so `missing` is per group, not global.
public struct ServiceDateDelays: Sendable, Equatable {
    public let serviceDate: String
    public let delays: [TripDelay]
    public let missing: [String]
}

/// Result of `SpiderRealtime.delays`: delays grouped by service date, plus feed freshness. Look up a single
/// instance with `delayFor(tripId:serviceDate:)`.
public struct TripDelays: Sendable, Equatable {
    public let groups: [ServiceDateDelays]
    public let freshness: FeedFreshness

    /// The delay for the (`tripId`, `serviceDate`) instance, if the feed reported one.
    public func delayFor(tripId: String, serviceDate: String) -> TripDelay? {
        groups.first { $0.serviceDate == serviceDate }?.delays.first { $0.tripId == tripId }
    }
}

/// A time window an alert is active for. Epoch milliseconds.
public struct AlertActivePeriod: Sendable, Equatable {
    public let startEpochMs: Int64?
    public let endEpochMs: Int64?
}

/// What an alert applies to.
public struct AlertInformedEntity: Sendable, Equatable {
    public let agencyId: String?
    public let routeId: String?
    public let tripId: String?
    public let stopId: String?
}

/// A service alert. Text is already resolved to one language by the gateway; cause/effect/severity are raw
/// GTFS-RT strings passed through unchanged.
public struct ServiceAlert: Sendable, Equatable {
    public let id: String?
    public let cause: String?
    public let effect: String?
    public let severityLevel: String?
    public let headerText: String?
    public let descriptionText: String?
    public let url: String?
    public let activePeriods: [AlertActivePeriod]
    public let informedEntities: [AlertInformedEntity]
}

/// All active alerts for the environment plus feed freshness.
public struct ServiceAlerts: Sendable, Equatable {
    public let alerts: [ServiceAlert]
    public let freshness: FeedFreshness
}

private let EMPTY_FRESHNESS = FeedFreshness(feedTimestampEpochMs: nil, staleSeconds: nil)
private let EMPTY_POSITIONS = VehiclePositions(vehicles: [], missing: [], freshness: EMPTY_FRESHNESS)
private let EMPTY_DELAYS = TripDelays(groups: [], freshness: EMPTY_FRESHNESS)
private let MAX_TRIP_IDS = 50

/// The realtime surface: live vehicle positions, schedule deviations, and service alerts. Poll-based —
/// see the `poll*` methods for change-detecting streams.
public final class SpiderRealtime {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    /// Live positions for the given trips, up to 50 per call. No trip ids return an empty result without a
    /// request; more than 50 fail as `.badRequest` (field `tripIds`) without a request.
    public func vehicles(_ tripIds: [String]) async throws -> SpiderResult<VehiclePositions> {
        guard !tripIds.isEmpty else { return .success(EMPTY_POSITIONS) }
        guard tripIds.count <= MAX_TRIP_IDS else { return .failure(outOfRange("tripIds")) }
        do {
            let dto: VehiclesResponse = try await transport.getJson("/realtime/v1/vehicles", query: [("tripIds", tripIds.joined(separator: ","))])
            let positions = VehiclePositions(
                vehicles: (dto.vehicles ?? []).map(mapVehicle),
                missing: dto.missing ?? [],
                freshness: mapFreshness(dto.feedTimestamp, dto.staleSeconds)
            )
            return .success(positions)
        } catch {
            return .failure(toSpiderError(error))
        }
    }

    /// The live vehicle for a single trip. A 404 is a normal "no vehicle currently reporting", not an error.
    public func vehicleForTrip(_ tripId: String) async throws -> SpiderResult<LiveVehicleUpdate> {
        do {
            let encoded = tripId.addingPercentEncoding(withAllowedCharacters: pathSegmentAllowed) ?? tripId
            let path = "/realtime/v1/vehicles/by-trip/\(encoded)"
            let raw = try await transport.getRaw(path)
            if !raw.ok, let limit = planLimitError(status: raw.status, envelope: parseErrorEnvelope(raw.text)) {
                throw limit
            }
            if raw.status == 404 {
                return .success(LiveVehicleUpdate(vehicle: nil, freshness: EMPTY_FRESHNESS))
            }
            if !raw.ok {
                let detail = String(raw.text.prefix(300))
                throw TransportError(.http, "GET \(path) -> \(raw.status): \(detail)", httpStatus: raw.status, field: validationField(detail))
            }
            let dto: VehicleByTripResponse = try decode(from: raw.data, where: "GET /realtime/v1/vehicles/by-trip")
            return .success(LiveVehicleUpdate(
                vehicle: dto.vehicle.map(mapVehicle),
                freshness: mapFreshness(dto.feedTimestamp, dto.staleSeconds)
            ))
        } catch {
            return .failure(toSpiderError(error))
        }
    }

    /// Live delays, resolved per `(tripId, serviceDate)` instance: group trip ids by the GTFS service date
    /// (`YYYY-MM-DD`) they run on — pass each leg's, departure's or trip's `serviceDate` through. Up to 50 trip
    /// ids per call, counted across all dates; no trip ids return an empty result without a request. A malformed
    /// date (field `serviceDate`) or more than 50 trip ids (field `tripIds`) fail as `.badRequest` without a
    /// request.
    public func delays(byServiceDate: [String: [String]]) async throws -> SpiderResult<TripDelays> {
        if byServiceDate.keys.contains(where: { !isServiceDate($0) }) {
            return .failure(invalid("serviceDate"))
        }
        let tripIdCount = byServiceDate.values.reduce(0) { $0 + $1.count }
        guard tripIdCount > 0 else { return .success(EMPTY_DELAYS) }
        guard tripIdCount <= MAX_TRIP_IDS else { return .failure(outOfRange("tripIds")) }
        do {
            let body = DelaysRequest(queries: byServiceDate.map { DelayQuery(serviceDate: $0.key, tripIds: $0.value) })
            let dto: DelaysResponse = try await transport.postJson("/realtime/v1/delays", body)
            let delays = TripDelays(
                groups: (dto.results ?? []).map(mapDelayGroup),
                freshness: mapFreshness(dto.feedTimestamp, dto.staleSeconds)
            )
            return .success(delays)
        } catch {
            return .failure(toSpiderError(error))
        }
    }

    /// Live delays for `tripIds` all on one `serviceDate` (`YYYY-MM-DD`) — the common single-day case.
    public func delays(_ tripIds: [String], serviceDate: String) async throws -> SpiderResult<TripDelays> {
        try await delays(byServiceDate: [serviceDate: tripIds])
    }

    /// All active service alerts for the environment.
    public func alerts() async throws -> SpiderResult<ServiceAlerts> {
        do {
            let dto: AlertsResponse = try await transport.getJson("/realtime/v1/alerts")
            let alerts = ServiceAlerts(
                alerts: (dto.alerts ?? []).map(mapAlert),
                freshness: mapFreshness(dto.feedTimestamp, dto.staleSeconds)
            )
            return .success(alerts)
        } catch {
            return .failure(toSpiderError(error))
        }
    }
}

// Percent-encode a single path segment (escapes '/', unlike .urlPathAllowed) to mirror encodeURIComponent.
private let pathSegmentAllowed: CharacterSet = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))

// Wire timestamps are epoch SECONDS; public models use epoch MILLIS.
private func secondsToMs(_ value: Int?) -> Int64? {
    value.map { Int64($0) * 1000 }
}

private func mapFreshness(_ feedTimestamp: Int?, _ staleSeconds: Double?) -> FeedFreshness {
    FeedFreshness(feedTimestampEpochMs: secondsToMs(feedTimestamp), staleSeconds: staleSeconds)
}

private func mapVehicle(_ v: VehicleDto) -> LiveVehicle {
    LiveVehicle(
        tripId: v.tripId, routeId: v.routeId, vehicleId: v.vehicleId, label: v.label,
        latitude: v.latitude, longitude: v.longitude, bearing: v.bearing, speed: v.speed,
        stopId: v.stopId, currentStatus: v.currentStatus,
        occupancy: OccupancyStatus.fromWire(v.occupancyStatus),
        timestampEpochMs: secondsToMs(v.timestamp)
    )
}

private func mapDelayGroup(_ g: DelayGroupResult) -> ServiceDateDelays {
    ServiceDateDelays(
        serviceDate: g.serviceDate,
        delays: (g.delays ?? []).map(mapDelay),
        missing: g.missing ?? []
    )
}

private func mapDelay(_ d: DelayDto) -> TripDelay {
    TripDelay(
        tripId: d.tripId, routeId: d.routeId, delaySeconds: d.delaySeconds,
        scheduleRelationship: d.scheduleRelationship,
        stopTimeUpdates: (d.stopTimeUpdates ?? []).map(mapStopTimeUpdate)
    )
}

private func mapStopTimeUpdate(_ s: StopTimeUpdateDto) -> StopTimeUpdate {
    StopTimeUpdate(
        stopId: s.stopId, stopSequence: s.stopSequence,
        arrivalDelay: s.arrivalDelay, departureDelay: s.departureDelay,
        scheduleRelationship: s.scheduleRelationship
    )
}

private func mapAlert(_ a: AlertDto) -> ServiceAlert {
    ServiceAlert(
        id: a.id, cause: a.cause, effect: a.effect, severityLevel: a.severityLevel,
        headerText: a.headerText, descriptionText: a.descriptionText, url: a.url,
        activePeriods: (a.activePeriods ?? []).map { AlertActivePeriod(startEpochMs: secondsToMs($0.start), endEpochMs: secondsToMs($0.end)) },
        informedEntities: (a.informedEntities ?? []).map { AlertInformedEntity(agencyId: $0.agencyId, routeId: $0.routeId, tripId: $0.tripId, stopId: $0.stopId) }
    )
}

// MARK: - wire types (hand-written; freshness fields are decoded from the top level of each response)

private struct VehicleDto: Decodable {
    let tripId: String?
    let routeId: String?
    let vehicleId: String?
    let label: String?
    let latitude: Double?
    let longitude: Double?
    let bearing: Double?
    let speed: Double?
    let stopId: String?
    let currentStatus: String?
    let occupancyStatus: String?
    let timestamp: Int?
}

private struct VehiclesResponse: Decodable {
    let vehicles: [VehicleDto]?
    let missing: [String]?
    let feedTimestamp: Int?
    let staleSeconds: Double?
}

private struct VehicleByTripResponse: Decodable {
    let vehicle: VehicleDto?
    let feedTimestamp: Int?
    let staleSeconds: Double?
}

private struct StopTimeUpdateDto: Decodable {
    let stopId: String?
    let stopSequence: Int?
    let arrivalDelay: Int?
    let departureDelay: Int?
    let scheduleRelationship: String?
}

private struct DelayDto: Decodable {
    let tripId: String?
    let routeId: String?
    let delaySeconds: Int?
    let scheduleRelationship: String?
    let stopTimeUpdates: [StopTimeUpdateDto]?
}

// Grouped, service-date-scoped request body for POST /realtime/v1/delays.
private struct DelayQuery: Encodable {
    let serviceDate: String
    let tripIds: [String]
}

private struct DelaysRequest: Encodable {
    let queries: [DelayQuery]
}

private struct DelayGroupResult: Decodable {
    let serviceDate: String
    let delays: [DelayDto]?
    let missing: [String]?
}

private struct DelaysResponse: Decodable {
    let results: [DelayGroupResult]?
    let feedTimestamp: Int?
    let staleSeconds: Double?
}

private struct ActivePeriodDto: Decodable {
    let start: Int?
    let end: Int?
}

private struct InformedEntityDto: Decodable {
    let agencyId: String?
    let routeId: String?
    let tripId: String?
    let stopId: String?
}

private struct AlertDto: Decodable {
    let id: String?
    let cause: String?
    let effect: String?
    let severityLevel: String?
    let headerText: String?
    let descriptionText: String?
    let url: String?
    let activePeriods: [ActivePeriodDto]?
    let informedEntities: [InformedEntityDto]?
}

private struct AlertsResponse: Decodable {
    let alerts: [AlertDto]?
    let feedTimestamp: Int?
    let staleSeconds: Double?
}
