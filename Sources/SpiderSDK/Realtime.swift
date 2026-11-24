import Foundation

// MARK: - Public realtime models

/// How fresh a realtime feed is. Timestamps are epoch milliseconds; `staleSeconds` is age in seconds.
public struct FeedFreshness: Sendable, Equatable {
    public let feedTimestampEpochMs: Int64?
    public let staleSeconds: Int?
}

/// A vehicle's live position and features. GTFS-RT producers populate different subsets, so beyond the trip and
/// position every field is optional. `tripId`, `routeId`, `stopId` and `vehicleId` are feed-prefixed
/// (`<feedId>:<id>`), like routing's ids.
public struct LiveVehicle: Sendable, Equatable {
    public let tripId: String
    /// The GTFS service date (`YYYY-MM-DD`) of the trip run the vehicle is on.
    public let serviceDate: String
    /// The start time of the trip run, as the feed's GTFS-RT `start_time` gives it: a GTFS time `HH:MM:SS` that may
    /// exceed `24:00:00`. It tells apart the runs of a frequency-based trip; nil when the feed gives none.
    public let startTime: String?
    public let routeId: String?
    public let vehicleId: String?
    public let label: String?
    public let latitude: Double
    public let longitude: Double
    public let bearing: Double?
    public let speed: Double?
    public let stopId: String?
    public let currentStatus: String?
    public let occupancy: OccupancyStatus?
    public let timestampEpochMs: Int64?
    /// Whether the vehicle reported for the trip takes wheelchairs. Nil when the feed doesn't say.
    public let wheelchairAccessible: VehicleWheelchairAccessibility?
    /// Whether the vehicle reported for the trip is air-conditioned. Nil when unknown.
    public let airConditioning: Bool?
    /// Whether the vehicle reported for the trip offers Wi-Fi. Nil when unknown.
    public let wifi: Bool?
    /// Whether the vehicle reported for the trip accepts card payment on board. Nil when unknown.
    public let cardPayment: Bool?
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

/// A trip's live schedule deviation. Delay values are in seconds; ids are feed-prefixed (`<feedId>:<id>`).
public struct TripDelay: Sendable, Equatable {
    public let tripId: String
    public let routeId: String?
    public let delaySeconds: Int?
    public let scheduleRelationship: String?
    public let stopTimeUpdates: [StopTimeUpdate]
}

/// Result of `SpiderRealtime.delays`: the delays the feed reported for one GTFS service date, the `missing` trip
/// ids it didn't, and feed freshness.
public struct TripDelays: Sendable, Equatable {
    public let serviceDate: String
    public let delays: [TripDelay]
    public let missing: [String]
    public let freshness: FeedFreshness

    /// The delay for `tripId` on this service date, if the feed reported one.
    public func delayFor(tripId: String) -> TripDelay? {
        delays.first { $0.tripId == tripId }
    }
}

/// An original stop time of a trip, by `stopSequence` and/or `stopId` as the feed gives it (GTFS-RT
/// `StopSelector`). `stopId` is feed-prefixed (`<feedId>:<id>`). Experimental, as GTFS-RT trip modifications are.
public struct StopSelector: Sendable, Equatable {
    public let stopSequence: Int?
    public let stopId: String?
}

/// A stop a modified trip visits in place of the replaced span (GTFS-RT `ReplacementStop`). `stopId` is
/// feed-prefixed (`<feedId>:<id>`). `name`, `latitude` and `longitude` are set only when the feed defines the stop
/// as a realtime `Stop` entity; otherwise it is a static stop, which the stop search returns. Experimental, as
/// GTFS-RT trip modifications are.
public struct ReplacementStop: Sendable, Equatable {
    public let stopId: String?
    /// Seconds from the arrival at the reference stop (the stop before `TripModification.startStop`, or the
    /// trip's first stop when the modification starts there) to the arrival here.
    public let travelTimeToStopSeconds: Int?
    public let name: String?
    public let latitude: Double?
    public let longitude: Double?
}

/// A detour: a span of a trip's stop times replaced by `replacementStops` (GTFS-RT
/// `TripModifications.Modification`). Experimental, as GTFS-RT trip modifications are: its shape may change in a
/// later contract version.
public struct TripModification: Sendable, Equatable {
    /// The feed-prefixed (`<feedId>:<id>`) id of the feed entity holding the trip modifications.
    public let id: String
    /// The GTFS times (`HH:MM:SS`) of the frequency-based runs it applies to; nil when it applies to every run of
    /// the trip on the service date.
    public let startTimes: [String]?
    /// The first original stop time replaced.
    public let startStop: StopSelector?
    /// The last original stop time replaced, inclusive; nil when no stop time is replaced.
    public let endStop: StopSelector?
    /// The stops the trip now visits in place of the replaced span, in order; empty when the feed lists none.
    public let replacementStops: [ReplacementStop]
    /// Seconds added to every arrival and departure after the end of the modification; 0 when the feed doesn't
    /// set it.
    public let propagatedModificationDelaySeconds: Int
    /// The feed-prefixed id of the service alert describing the modification, as `SpiderRealtime.alerts()` returns
    /// it.
    public let alertId: String?
    public let lastModifiedEpochMs: Int64?
    /// The modified trip's path; nil when the feed defines no realtime shape for it.
    public let shape: [LatLon]?
}

/// The live update of one trip run: its schedule deviation (delay values in seconds) and the trip modifications
/// (detours) that select it. A run with modifications and no GTFS-RT trip update has empty `stopTimeUpdates` and nil
/// `delaySeconds`, `scheduleRelationship` and `routeId`. Ids are feed-prefixed (`<feedId>:<id>`).
public struct TripUpdate: Sendable, Equatable {
    public let tripId: String
    /// The start time of the trip run, as the feed's GTFS-RT `start_time` gives it: a GTFS time `HH:MM:SS` that may
    /// exceed `24:00:00`. Each run of a frequency-based trip is its own update; nil when the feed gives none.
    public let startTime: String?
    public let routeId: String?
    public let delaySeconds: Int?
    public let scheduleRelationship: String?
    public let stopTimeUpdates: [StopTimeUpdate]
    /// Experimental: the modifications that apply to this run, in feed order; their delays accumulate along the
    /// trip. Empty when none applies.
    public let modifications: [TripModification]
}

/// Result of `SpiderRealtime.tripUpdates`: the updates of every trip run the feed reported or modified on one GTFS
/// service date, the `missing` trip ids it has neither for, and feed freshness.
public struct TripUpdates: Sendable, Equatable {
    public let serviceDate: String
    /// One per trip run, a frequency-based trip's runs in order of `startTime` (a run without one first).
    public let tripUpdates: [TripUpdate]
    public let missing: [String]
    public let freshness: FeedFreshness

    /// The update of `tripId`'s run on this service date that starts at `startTime` (compared as a time, so
    /// `8:10:00` is `08:10:00`), or its first run when `startTime` is nil. Nil when the feed has none.
    public func updateFor(tripId: String, startTime: String? = nil) -> TripUpdate? {
        let runs = tripUpdates.filter { $0.tripId == tripId }
        guard let startTime else { return runs.first }
        let seconds = gtfsTimeSeconds(startTime)
        return runs.first { run in
            guard let runStart = run.startTime else { return false }
            if let seconds, let runSeconds = gtfsTimeSeconds(runStart) { return seconds == runSeconds }
            return runStart == startTime
        }
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
    public let id: String
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
private let MAX_TRIP_IDS = 50

/// The realtime surface: live vehicle positions, schedule deviations, and service alerts. Poll-based —
/// see the `poll*` methods for change-detecting streams.
public final class SpiderRealtime {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    /// Live positions for the runs of the given feed-prefixed trip ids (`<feedId>:<id>`) on one GTFS `serviceDate`
    /// (`YYYY-MM-DD`): pass a leg's or departure's `serviceDate`. A vehicle counts only while it runs that run, so a
    /// future date has none. Up to 50 ids per call. No trip ids return an empty result without a request; a
    /// malformed date or more than 50 ids fail as `.badRequest` without a request.
    public func vehicles(serviceDate: String, tripIds: [String]) async throws -> SpiderResult<VehiclePositions> {
        guard isServiceDate(serviceDate) else { return .failure(invalid("serviceDate")) }
        guard !tripIds.isEmpty else { return .success(EMPTY_POSITIONS) }
        guard tripIds.count <= MAX_TRIP_IDS else { return .failure(outOfRange("tripIds")) }
        do {
            let dto: VehiclesResponse = try await transport.getJson(
                "/realtime/v1/vehicles",
                query: [("serviceDate", serviceDate), ("tripIds", tripIds.joined(separator: ","))]
            )
            let positions = VehiclePositions(
                vehicles: dto.vehicles.map(mapVehicle),
                missing: dto.missing,
                freshness: mapFreshness(dto.feedTimestamp, dto.staleSeconds)
            )
            return .success(positions)
        } catch {
            return .failure(toSpiderError(error))
        }
    }

    /// The live vehicle for a single trip run: `tripId` on GTFS `serviceDate` (`YYYY-MM-DD`, a leg's or
    /// departure's `serviceDate`). `startTime` picks the run of a frequency-based trip by the start time the feed
    /// reports it with, a GTFS time `H:MM:SS` or `HH:MM:SS` (hours up to 99) compared as a time; `vehicle` is nil
    /// when no run has it. Nil answers the run with the earliest start time, so a trip that is not frequency-based
    /// needs none. A 404 is a normal "no vehicle currently reporting", not an error. A malformed date or start time
    /// fails as `.badRequest` without a request.
    public func vehicleForTrip(_ tripId: String, serviceDate: String, startTime: String? = nil) async throws -> SpiderResult<LiveVehicleUpdate> {
        guard isServiceDate(serviceDate) else { return .failure(invalid("serviceDate")) }
        if let startTime, gtfsTimeSeconds(startTime) == nil { return .failure(invalid("startTime")) }
        do {
            let encoded = tripId.addingPercentEncoding(withAllowedCharacters: pathSegmentAllowed) ?? tripId
            let path = "/realtime/v1/vehicles/by-trip/\(encoded)"
            var query = [("serviceDate", serviceDate)]
            if let startTime { query.append(("startTime", startTime)) }
            let raw = try await transport.getRaw(path, query: query)
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

    /// Live delays for feed-prefixed `tripIds` (`<feedId>:<id>`) running on one GTFS `serviceDate`
    /// (`YYYY-MM-DD`): pass a leg's, departure's or trip's `serviceDate` and ids through. The ids are
    /// de-duplicated and sorted, so equal requests share a cache entry. A malformed date, no ids, a blank id or
    /// more than 50 distinct ids fail as `.badRequest` without a request.
    ///
    /// Deprecated with `GET /realtime/v1/delays`, which keeps working unchanged until it is retired with notice,
    /// no earlier than 2027-05-24. A frequency-based trip answers only its run with the earliest start time; its
    /// successor `tripUpdates(serviceDate:tripIds:)` lists every run, with its trip modifications.
    @available(*, deprecated, message: "GET /realtime/v1/delays is deprecated (retired no earlier than 2027-05-24); use tripUpdates(serviceDate:tripIds:).")
    public func delays(serviceDate: String, tripIds: [String]) async throws -> SpiderResult<TripDelays> {
        let query: [(String, String)]
        switch tripRunsQuery(serviceDate: serviceDate, tripIds: tripIds) {
        case .success(let q): query = q
        case .failure(let error): return .failure(error)
        }
        do {
            let dto: DelaysResponse = try await transport.getJson("/realtime/v1/delays", query: query)
            return .success(TripDelays(
                serviceDate: dto.serviceDate,
                delays: dto.delays.map(mapDelay),
                missing: dto.missing,
                freshness: mapFreshness(dto.feedTimestamp, dto.staleSeconds)
            ))
        } catch {
            return .failure(toSpiderError(error))
        }
    }

    /// Live trip updates for feed-prefixed `tripIds` (`<feedId>:<id>`) running on one GTFS `serviceDate`
    /// (`YYYY-MM-DD`): each trip run's schedule deviation and the trip modifications (detours, experimental) that
    /// select it. Pass a leg's, departure's or trip's `serviceDate` and ids through. A frequency-based trip has one
    /// update per run, told apart by `startTime`. The ids are de-duplicated and sorted, so equal requests share a
    /// cache entry. A malformed date, no ids, a blank id or more than 50 distinct ids fail as `.badRequest` without
    /// a request. The successor of `delays(serviceDate:tripIds:)`.
    public func tripUpdates(serviceDate: String, tripIds: [String]) async throws -> SpiderResult<TripUpdates> {
        let query: [(String, String)]
        switch tripRunsQuery(serviceDate: serviceDate, tripIds: tripIds) {
        case .success(let q): query = q
        case .failure(let error): return .failure(error)
        }
        do {
            let dto: TripUpdatesResponse = try await transport.getJson("/realtime/v1/trip-updates", query: query)
            return .success(TripUpdates(
                serviceDate: dto.serviceDate,
                tripUpdates: dto.tripUpdates.map(mapTripUpdate),
                missing: dto.missing,
                freshness: mapFreshness(dto.feedTimestamp, dto.staleSeconds)
            ))
        } catch {
            return .failure(toSpiderError(error))
        }
    }

    private func tripRunsQuery(serviceDate: String, tripIds: [String]) -> SpiderResult<[(String, String)]> {
        guard isServiceDate(serviceDate) else { return .failure(invalid("serviceDate")) }
        guard !tripIds.isEmpty else { return .failure(required("tripIds")) }
        guard !tripIds.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return .failure(invalid("tripIds"))
        }
        let ids = Set(tripIds).sorted { $0.utf8.lexicographicallyPrecedes($1.utf8) }
        guard ids.count <= MAX_TRIP_IDS else { return .failure(outOfRange("tripIds")) }
        return .success([("serviceDate", serviceDate), ("tripIds", ids.joined(separator: ","))])
    }

    /// All active service alerts for the environment.
    public func alerts() async throws -> SpiderResult<ServiceAlerts> {
        do {
            let dto: AlertsResponse = try await transport.getJson("/realtime/v1/alerts")
            let alerts = ServiceAlerts(
                alerts: dto.alerts.map(mapAlert),
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
private func secondsToMs(_ value: Int64?) -> Int64? {
    value.map { $0 * 1000 }
}

private func mapFreshness(_ feedTimestamp: Int64?, _ staleSeconds: Int?) -> FeedFreshness {
    FeedFreshness(feedTimestampEpochMs: secondsToMs(feedTimestamp), staleSeconds: staleSeconds)
}

private func mapVehicle(_ v: VehicleDto) -> LiveVehicle {
    LiveVehicle(
        tripId: v.tripId, serviceDate: v.serviceDate, startTime: v.startTime, routeId: v.routeId,
        vehicleId: v.vehicleId, label: v.label,
        latitude: v.latitude, longitude: v.longitude, bearing: v.bearing, speed: v.speed,
        stopId: v.stopId, currentStatus: v.currentStatus,
        occupancy: OccupancyStatus.fromWire(v.occupancyStatus),
        timestampEpochMs: secondsToMs(v.timestamp),
        wheelchairAccessible: VehicleWheelchairAccessibility.fromWire(v.wheelchairAccessible),
        airConditioning: v.airConditioning, wifi: v.wifi, cardPayment: v.cardPayment
    )
}

private func mapTripUpdate(_ u: TripUpdateDto) -> TripUpdate {
    TripUpdate(
        tripId: u.tripId, startTime: u.startTime, routeId: u.routeId, delaySeconds: u.delaySeconds,
        scheduleRelationship: u.scheduleRelationship,
        stopTimeUpdates: u.stopTimeUpdates.map(mapStopTimeUpdate),
        modifications: (u.modifications ?? []).map(mapModification)
    )
}

private func mapModification(_ m: TripModificationDto) -> TripModification {
    TripModification(
        id: m.id, startTimes: m.startTimes,
        startStop: m.startStop.map { StopSelector(stopSequence: $0.stopSequence, stopId: $0.stopId) },
        endStop: m.endStop.map { StopSelector(stopSequence: $0.stopSequence, stopId: $0.stopId) },
        replacementStops: m.replacementStops.map {
            ReplacementStop(
                stopId: $0.stopId, travelTimeToStopSeconds: $0.travelTimeToStop,
                name: $0.name, latitude: $0.latitude, longitude: $0.longitude
            )
        },
        propagatedModificationDelaySeconds: m.propagatedModificationDelay,
        alertId: m.alertId,
        lastModifiedEpochMs: secondsToMs(m.lastModifiedTime),
        shape: m.shape.map { decodePolyline($0, precision: 1e5) }
    )
}

private func mapDelay(_ d: DelayDto) -> TripDelay {
    TripDelay(
        tripId: d.tripId, routeId: d.routeId, delaySeconds: d.delaySeconds,
        scheduleRelationship: d.scheduleRelationship,
        stopTimeUpdates: d.stopTimeUpdates.map(mapStopTimeUpdate)
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
        activePeriods: a.activePeriods.map { AlertActivePeriod(startEpochMs: secondsToMs($0.start), endEpochMs: secondsToMs($0.end)) },
        informedEntities: a.informedEntities.map { AlertInformedEntity(agencyId: $0.agencyId, routeId: $0.routeId, tripId: $0.tripId, stopId: $0.stopId) }
    )
}

// MARK: - wire types (hand-written; freshness fields are decoded from the top level of each response)

private struct VehicleDto: Decodable {
    let tripId: String
    let serviceDate: String
    let routeId: String?
    let vehicleId: String?
    let label: String?
    let latitude: Double
    let longitude: Double
    let bearing: Double?
    let speed: Double?
    let stopId: String?
    let currentStatus: String?
    let occupancyStatus: String?
    let timestamp: Int64?
    let startTime: String?
    let wheelchairAccessible: String?
    let airConditioning: Bool?
    let wifi: Bool?
    let cardPayment: Bool?
}

private struct VehiclesResponse: Decodable {
    let vehicles: [VehicleDto]
    let missing: [String]
    let feedTimestamp: Int64?
    let staleSeconds: Int?
}

private struct VehicleByTripResponse: Decodable {
    let vehicle: VehicleDto?
    let feedTimestamp: Int64?
    let staleSeconds: Int?
}

private struct StopTimeUpdateDto: Decodable {
    let stopId: String?
    let stopSequence: Int?
    let arrivalDelay: Int?
    let departureDelay: Int?
    let scheduleRelationship: String?
}

private struct DelayDto: Decodable {
    let tripId: String
    let routeId: String?
    let delaySeconds: Int?
    let scheduleRelationship: String?
    let stopTimeUpdates: [StopTimeUpdateDto]
}

private struct DelaysResponse: Decodable {
    let serviceDate: String
    let delays: [DelayDto]
    let missing: [String]
    let feedTimestamp: Int64?
    let staleSeconds: Int?
}

private struct StopSelectorDto: Decodable {
    let stopSequence: Int?
    let stopId: String?
}

private struct ReplacementStopDto: Decodable {
    let stopId: String?
    let travelTimeToStop: Int?
    let name: String?
    let latitude: Double?
    let longitude: Double?
}

private struct TripModificationDto: Decodable {
    let id: String
    let startTimes: [String]?
    let startStop: StopSelectorDto?
    let endStop: StopSelectorDto?
    let replacementStops: [ReplacementStopDto]
    let propagatedModificationDelay: Int
    let alertId: String?
    let lastModifiedTime: Int64?
    let shape: String?
}

private struct TripUpdateDto: Decodable {
    let tripId: String
    let startTime: String?
    let routeId: String?
    let delaySeconds: Int?
    let scheduleRelationship: String?
    let stopTimeUpdates: [StopTimeUpdateDto]
    let modifications: [TripModificationDto]?
}

private struct TripUpdatesResponse: Decodable {
    let serviceDate: String
    let tripUpdates: [TripUpdateDto]
    let missing: [String]
    let feedTimestamp: Int64?
    let staleSeconds: Int?
}

private struct ActivePeriodDto: Decodable {
    let start: Int64?
    let end: Int64?
}

private struct InformedEntityDto: Decodable {
    let agencyId: String?
    let routeId: String?
    let tripId: String?
    let stopId: String?
}

private struct AlertDto: Decodable {
    let id: String
    let cause: String?
    let effect: String?
    let severityLevel: String?
    let headerText: String?
    let descriptionText: String?
    let url: String?
    let activePeriods: [ActivePeriodDto]
    let informedEntities: [InformedEntityDto]
}

private struct AlertsResponse: Decodable {
    let alerts: [AlertDto]
    let feedTimestamp: Int64?
    let staleSeconds: Int?
}
