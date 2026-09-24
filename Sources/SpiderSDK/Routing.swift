import Foundation
import SpiderContract

// MARK: - Public routing models

/// One leg of an itinerary (a single vehicle ride or walk).
public struct Leg: Sendable, Equatable {
    public let mode: TransitMode?
    public let startScheduled: String
    public let endScheduled: String
    // Realtime-estimated start/end times (ISO-8601) and the schedule deviation in seconds (positive = late,
    // negative = early), present when the trip is tracked. `isRealtime` is true when this leg carries live
    // data; `serviceDate` is the GTFS service date (`YYYYMMDD`) the trip runs on — pass it to
    // `SpiderRealtime.delays`, don't derive one from a clock time (GTFS times can exceed 24:00).
    public let startEstimated: String?
    public let endEstimated: String?
    public let startDelaySeconds: Int?
    public let endDelaySeconds: Int?
    public let isRealtime: Bool
    public let realtimeState: RealtimeState?
    public let serviceDate: String?
    public let fromName: String?
    public let toName: String?
    public let fromGtfsId: String?
    public let toGtfsId: String?
    public let routeShortName: String?
    public let routeLongName: String?
    public let headsign: String?
    public let distanceMeters: Double?
    public let durationSeconds: Double?
    public let tripGtfsId: String?
    public let bikesAllowed: BikesAllowed?
    public let accessibilityScore: Double?
    public let fromWheelchair: WheelchairBoarding?
    public let toWheelchair: WheelchairBoarding?
    public let geometry: [LatLon]
}

/// A full origin-to-destination itinerary.
public struct Itinerary: Sendable, Equatable {
    public let start: String?
    public let end: String?
    public let durationSeconds: Int
    public let waitingTimeSeconds: Int?
    public let numberOfTransfers: Int
    public let accessibilityScore: Double?
    public let legs: [Leg]
}

/// A paged itinerary with its cursor.
public struct RouteEdge: Sendable, Equatable {
    public let cursor: String
    public let itinerary: Itinerary
}

/// Relay-style paging info for a `Route`.
public struct RoutePageInfo: Sendable, Equatable {
    public let startCursor: String?
    public let endCursor: String?
    public let hasNextPage: Bool
    public let hasPreviousPage: Bool
    public let searchWindowUsed: String?
}

/// A non-fatal routing problem (e.g. no transit connection in the window).
public struct RoutingError: Sendable, Equatable {
    public let code: RoutingErrorCode
    public let description: String
    public let inputField: InputField?
}

/// The result of a trip-plan search: a page of itineraries plus paging info and any routing errors.
public struct Route: Sendable, Equatable {
    public let edges: [RouteEdge]
    public let pageInfo: RoutePageInfo
    public let routingErrors: [RoutingError]
    public let searchDateTime: String?
    // Carries the originating request so `planNext`/`planPrevious` can page without re-deriving it. Internal.
    let request: PlanRequest
}

/// A single departure from a stop.
public struct Departure: Sendable, Equatable {
    public let scheduledTimeEpochMs: Int64
    public let realtimeTimeEpochMs: Int64?
    public let isRealtime: Bool
    public let realtimeState: RealtimeState?
    public let headsign: String?
    public let tripGtfsId: String?
    public let routeShortName: String?
    public let routeLongName: String?
    public let mode: TransitMode?
}

/// One stop on a trip's timetable.
public struct TripStop: Sendable, Equatable {
    public let gtfsId: String
    public let name: String
    public let lat: Double?
    public let lon: Double?
    public let scheduledArrivalEpochMs: Int64?
    public let scheduledDepartureEpochMs: Int64?
    public let realtimeArrivalEpochMs: Int64?
    public let realtimeDepartureEpochMs: Int64?
    public let isRealtime: Bool
    public let wheelchairBoarding: WheelchairBoarding?
}

/// A single trip's route, stops, and geometry.
public struct TripDetails: Sendable, Equatable {
    public let gtfsId: String
    public let routeShortName: String?
    public let routeLongName: String?
    public let mode: TransitMode?
    public let headsign: String?
    public let directionId: String?
    public let bikesAllowed: BikesAllowed?
    public let stops: [TripStop]
    public let geometry: [LatLon]
}

/// Options for a trip-plan search. `departAt`/`arriveBy` are mutually exclusive (arriveBy wins if both set;
/// neither = depart now). `allowedTransitModes` empty = all modes. `searchWindowMinutes` defaults to 60.
public struct PlanOptions: Sendable {
    public let origin: Location
    public let destination: Location
    public var departAt: Date?
    public var arriveBy: Date?
    public var via: [ViaLocation]
    public var allowedTransitModes: [TransitMode]
    public var maxTransfers: Int?
    public var searchWindowMinutes: Int?
    public var wheelchairAccessible: Bool

    public init(
        origin: Location,
        destination: Location,
        departAt: Date? = nil,
        arriveBy: Date? = nil,
        via: [ViaLocation] = [],
        allowedTransitModes: [TransitMode] = [],
        maxTransfers: Int? = nil,
        searchWindowMinutes: Int? = nil,
        wheelchairAccessible: Bool = false
    ) {
        self.origin = origin
        self.destination = destination
        self.departAt = departAt
        self.arriveBy = arriveBy
        self.via = via
        self.allowedTransitModes = allowedTransitModes
        self.maxTransfers = maxTransfers
        self.searchWindowMinutes = searchWindowMinutes
        self.wheelchairAccessible = wheelchairAccessible
    }
}

// Internal paging context carried on each Route.
enum PlanTimeKind: Sendable, Equatable { case departAt, arriveBy }

struct PlanRequest: Sendable, Equatable {
    let origin: Location
    let destination: Location
    let timeKind: PlanTimeKind
    let time: Date
    let via: [ViaLocation]
    let allowedTransitModes: [TransitMode]
    let maxTransfers: Int?
    let searchWindowMinutes: Int
    let wheelchairAccessible: Bool
}

// Public methods inline these as literal default arguments (10 / 360) — public default args cannot
// reference non-public symbols. Keep the literals below in sync with these names if you change them.
private let DEFAULT_SEARCH_WINDOW_MINUTES = 60
private let DEFAULT_TIME_RANGE_SECONDS = 24 * 60 * 60
private let ROUTING_INT_MAX = 2_147_483_647

// The transit modes valid in a modes filter — the street/leg modes (WALK/BICYCLE/CAR/TRANSIT) must not reach it.
private let WIRE_TRANSIT_MODES: Set<String> = [
    "AIRPLANE", "BUS", "CABLE_CAR", "CARPOOL", "COACH", "FERRY", "FUNICULAR", "GONDOLA",
    "MONORAIL", "RAIL", "SNOW_AND_ICE", "SUBWAY", "TAXI", "TRAM", "TROLLEYBUS",
]

private let planIsoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

/// The routing surface: trip planning (`plan` + paging + streaming), stop `departures`, and single `trip` detail.
public final class SpiderRouting {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    /// Plans a trip. Returns the first window of itineraries.
    public func plan(_ options: PlanOptions) async throws -> SpiderResult<Route> {
        let request = makeRequest(options)
        return try await page(request)
    }

    /// The next window after `route`, or nil if there is none. Pages forward with `after` (no page-size count).
    public func planNext(_ route: Route) async throws -> SpiderResult<Route>? {
        guard route.pageInfo.hasNextPage else { return nil }
        return try await page(route.request, after: route.pageInfo.endCursor)
    }

    /// The previous window before `route`, or nil if there is none. Pages backward with `before` (no page-size count).
    public func planPrevious(_ route: Route) async throws -> SpiderResult<Route>? {
        guard route.pageInfo.hasPreviousPage else { return nil }
        return try await page(route.request, before: route.pageInfo.startCursor)
    }

    /// Streams the initial search window over Server-Sent Events as the router sweeps it, emitting itineraries
    /// as they finalize instead of one batched page. Cold and cancellable: iterating starts the request,
    /// cancelling the consuming task stops the sweep. Each `.result` carries a batch of itineraries with
    /// realtime delays already applied to their legs; a terminal `.done` then carries the continuation cursors
    /// (or a terminal `.failure`, which is yielded — never thrown).
    ///
    /// `targetResults` is a soft floor the sweep aims to reach; `maxWindowMinutes` caps how far it searches.
    /// To continue, read `done.pageInfo` and call `planStreamNext(..., after: done.pageInfo.endCursor)` (when
    /// `hasNextPage`) or `planStreamPrevious(..., before: done.pageInfo.startCursor)` (when `hasPreviousPage`).
    /// `options.searchWindowMinutes` is ignored — the stream paces itself. For a single batched page, use `plan`.
    public func planStream(
        _ options: PlanOptions,
        targetResults: Int = 5,
        maxWindowMinutes: Int = 360
    ) -> AsyncStream<PlanStreamEvent> {
        planStreamInternal(options, targetResults: targetResults, maxWindowMinutes: maxWindowMinutes, after: nil, before: nil)
    }

    /// Continues a plan stream forward from `after` — the `endCursor` of a prior stream's terminal `.done`
    /// `RoutePageInfo` (only meaningful when that page's `hasNextPage` is true). Repeats `planStream`'s inputs
    /// so `targetResults` / `maxWindowMinutes` can differ per continuation. Same event contract as `planStream`.
    public func planStreamNext(
        _ options: PlanOptions,
        targetResults: Int = 5,
        maxWindowMinutes: Int = 360,
        after: String
    ) -> AsyncStream<PlanStreamEvent> {
        planStreamInternal(options, targetResults: targetResults, maxWindowMinutes: maxWindowMinutes, after: after, before: nil)
    }

    /// Continues a plan stream backward from `before` — the `startCursor` of a prior stream's terminal `.done`
    /// `RoutePageInfo` (only meaningful when that page's `hasPreviousPage` is true). Repeats `planStream`'s
    /// inputs so `targetResults` / `maxWindowMinutes` can differ per continuation. Same event contract as
    /// `planStream`.
    public func planStreamPrevious(
        _ options: PlanOptions,
        targetResults: Int = 5,
        maxWindowMinutes: Int = 360,
        before: String
    ) -> AsyncStream<PlanStreamEvent> {
        planStreamInternal(options, targetResults: targetResults, maxWindowMinutes: maxWindowMinutes, after: nil, before: before)
    }

    private func planStreamInternal(
        _ options: PlanOptions,
        targetResults: Int,
        maxWindowMinutes: Int,
        after: String?,
        before: String?
    ) -> AsyncStream<PlanStreamEvent> {
        AsyncStream { continuation in
            let task = Task {
                await self.runPlanStream(
                    options, targetResults: targetResults, maxWindowMinutes: maxWindowMinutes,
                    after: after, before: before, into: continuation
                )
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Departures from a stop, soonest first. `numberOfDepartures` caps the count; `startTime` defaults to now.
    public func departures(
        _ stopId: String,
        numberOfDepartures: Int = 30,
        startTime: Date? = nil,
        timeRangeSeconds: Int? = nil
    ) async throws -> SpiderResult<[Departure]> {
        do {
            let variables = StopDeparturesVariables(
                id: stopId,
                numberOfDepartures: numberOfDepartures,
                startTime: startTime.map { Int($0.timeIntervalSince1970.rounded(.down)) },
                timeRange: clampSeconds(timeRangeSeconds ?? DEFAULT_TIME_RANGE_SECONDS)
            )
            let data: StopDeparturesData = try await transport.graphql(PersistedQueries.departures, variables)
            guard let stop = data.asStop ?? data.asStation else {
                throw TransportError(.noData, "routing returned no stop or station for id=\(stopId)")
            }
            return .success(mapDepartures(stop))
        } catch let error as SpiderContractMismatchError {
            throw error
        } catch {
            return .failure(toSpiderError(error))
        }
    }

    /// A single trip's stops, times, and geometry.
    public func trip(_ tripId: String, serviceDate: String? = nil) async throws -> SpiderResult<TripDetails> {
        do {
            let variables = TripVariables(id: tripId, serviceDate: serviceDate)
            let data: TripData = try await transport.graphql(PersistedQueries.trip, variables)
            guard let trip = data.trip else {
                throw TransportError(.noData, "routing returned no trip for id=\(tripId)")
            }
            return .success(mapTrip(trip))
        } catch let error as SpiderContractMismatchError {
            throw error
        } catch {
            return .failure(toSpiderError(error))
        }
    }

    // MARK: paging internals

    private func makeRequest(_ options: PlanOptions) -> PlanRequest {
        let kind: PlanTimeKind = options.arriveBy != nil ? .arriveBy : .departAt
        let time = options.arriveBy ?? options.departAt ?? Date()
        return PlanRequest(
            origin: options.origin,
            destination: options.destination,
            timeKind: kind,
            time: time,
            via: options.via,
            allowedTransitModes: options.allowedTransitModes,
            maxTransfers: options.maxTransfers,
            searchWindowMinutes: options.searchWindowMinutes ?? DEFAULT_SEARCH_WINDOW_MINUTES,
            wheelchairAccessible: options.wheelchairAccessible
        )
    }

    private func page(_ request: PlanRequest, before: String? = nil, after: String? = nil) async throws -> SpiderResult<Route> {
        do {
            return .success(try await fetchPlan(request, before: before, after: after))
        } catch let error as SpiderContractMismatchError {
            throw error
        } catch {
            return .failure(toSpiderError(error))
        }
    }

    private func fetchPlan(_ request: PlanRequest, before: String?, after: String?) async throws -> Route {
        let iso = planIsoFormatter.string(from: request.time)
        let dateTime = request.timeKind == .departAt
            ? PlanDateTimeInput(earliestDeparture: iso)
            : PlanDateTimeInput(latestArrival: iso)
        let variables = PlanConnectionVariables(
            dateTime: dateTime,
            origin: locationToInput(request.origin),
            destination: locationToInput(request.destination),
            searchWindow: "PT\(max(1, request.searchWindowMinutes))M",
            via: request.via.isEmpty ? nil : request.via.map(viaToInput),
            modes: modesInput(request.allowedTransitModes),
            preferences: preferencesInput(request),
            before: before,
            after: after
        )
        let data: PlanConnectionData = try await transport.graphql(PersistedQueries.plan, variables)
        guard let plan = data.planConnection else {
            throw TransportError(.noData, "routing returned no plan data")
        }
        let edges = (plan.edges ?? []).map { RouteEdge(cursor: $0.cursor, itinerary: mapItinerary($0.node)) }
        let pageInfo = RoutePageInfo(
            startCursor: plan.pageInfo.startCursor,
            endCursor: plan.pageInfo.endCursor,
            hasNextPage: plan.pageInfo.hasNextPage,
            hasPreviousPage: plan.pageInfo.hasPreviousPage,
            searchWindowUsed: plan.pageInfo.searchWindowUsed
        )
        let routingErrors = plan.routingErrors.map {
            RoutingError(
                code: RoutingErrorCode.fromWire($0.code.rawValue),
                description: $0.description,
                inputField: InputField.fromWire($0.inputField?.rawValue)
            )
        }
        return Route(edges: edges, pageInfo: pageInfo, routingErrors: routingErrors, searchDateTime: plan.searchDateTime, request: request)
    }

    // Builds the SSE stream request variables from a plan request plus paging cursors. Internal seam so the
    // continuation routing (`planStreamNext` → `after`, `planStreamPrevious` → `before`) is unit-testable
    // without a live stream. `options.searchWindowMinutes` is intentionally not sent — the stream paces itself
    // via `targetResults` / `maxWindow`.
    func streamVariables(
        _ options: PlanOptions,
        targetResults: Int,
        maxWindowMinutes: Int,
        after: String?,
        before: String?
    ) -> PlanConnectionStreamVariables {
        let request = makeRequest(options)
        let iso = planIsoFormatter.string(from: request.time)
        let dateTime = request.timeKind == .departAt
            ? PlanDateTimeInput(earliestDeparture: iso)
            : PlanDateTimeInput(latestArrival: iso)
        return PlanConnectionStreamVariables(
            dateTime: dateTime,
            origin: locationToInput(request.origin),
            destination: locationToInput(request.destination),
            via: request.via.isEmpty ? nil : request.via.map(viaToInput),
            modes: modesInput(request.allowedTransitModes),
            preferences: preferencesInput(request),
            targetResults: targetResults,
            maxWindow: "PT\(max(1, maxWindowMinutes))M",
            before: before,
            after: after
        )
    }

    // Runs the SSE `plan-stream` request and pumps parsed events into the continuation. Uses
    // `URLSession.shared.bytes`, whose connection pool the default HTTP client (`.shared`) shares — so the
    // stream rides the same pool as the batch calls. No contract-version check here (`/routing/plan-stream`
    // is a streamed surface); every failure — a non-2xx response, a server `error` event, or a decode slip —
    // becomes a terminal `.failure` event, never a throw. A cancelled task stops the sweep quietly.
    private func runPlanStream(
        _ options: PlanOptions,
        targetResults: Int,
        maxWindowMinutes: Int,
        after: String?,
        before: String?,
        into continuation: AsyncStream<PlanStreamEvent>.Continuation
    ) async {
        let variables = streamVariables(
            options, targetResults: targetResults, maxWindowMinutes: maxWindowMinutes, after: after, before: before
        )

        let urlRequest: URLRequest
        do {
            urlRequest = try transport.streamingRequest(PersistedQueries.planstream, variables)
        } catch {
            continuation.yield(.failure(toSpiderError(error)))
            return
        }

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                continuation.yield(.failure(toSpiderError(
                    TransportError(.http, "routing plan-stream -> \(http.statusCode)", httpStatus: http.statusCode)
                )))
                return
            }
            var eventName: String?
            var dataLines: [String] = []
            func flush() {
                defer { eventName = nil; dataLines = [] }
                guard !dataLines.isEmpty else { return }
                if let event = parsePlanStreamRecord(event: eventName ?? SSE_DEFAULT_EVENT, data: dataLines.joined(separator: "\n")) {
                    continuation.yield(event)
                }
            }
            for try await line in bytes.lines {
                if line.isEmpty { flush(); continue }
                if line.hasPrefix(":") { continue } // comment / heartbeat
                guard let colon = line.firstIndex(of: ":") else { continue }
                let field = String(line[..<colon])
                var value = String(line[line.index(after: colon)...])
                if value.hasPrefix(" ") { value.removeFirst() }
                switch field {
                case "event": eventName = value
                case "data": dataLines.append(value)
                default: break // id / retry ignored
                }
            }
            flush() // a trailing record with no terminating blank line
        } catch is CancellationError {
            // Cancelled — stop quietly, matching the batch stream helpers.
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            continuation.yield(.failure(toSpiderError(error)))
        }
    }
}

// MARK: - request builders

private func locationToInput(_ location: Location) -> PlanLabeledLocationInput {
    switch location {
    case .coordinate(let latitude, let longitude):
        return PlanLabeledLocationInput(location: PlanLocationInput(coordinate: PlanCoordinateInput(latitude: latitude, longitude: longitude)))
    case .stop(let id):
        return PlanLabeledLocationInput(location: PlanLocationInput(stopLocation: PlanStopLocationInput(stopLocationId: id)))
    }
}

private func viaToInput(_ via: ViaLocation) -> PlanViaLocationInput {
    switch via {
    case .passThrough(let stopIds):
        return PlanViaLocationInput(passThrough: PlanPassThroughViaLocationInput(stopLocationIds: stopIds))
    case .visit(let location, let minimumWaitSeconds):
        let wait = minimumWaitSeconds > 0 ? "PT\(minimumWaitSeconds)S" : nil
        switch location {
        case .stop(let id):
            return PlanViaLocationInput(visit: PlanVisitViaLocationInput(minimumWaitTime: wait, stopLocationIds: [id]))
        case .coordinate(let latitude, let longitude):
            return PlanViaLocationInput(visit: PlanVisitViaLocationInput(coordinate: PlanCoordinateInput(latitude: latitude, longitude: longitude), minimumWaitTime: wait))
        }
    }
}

private func modesInput(_ modes: [TransitMode]) -> PlanModesInput? {
    let transit = modes
        .filter { WIRE_TRANSIT_MODES.contains($0.rawValue) }
        .compactMap { SpiderContract.TransitMode(rawValue: $0.rawValue) }
        .map { PlanTransitModePreferenceInput(mode: $0) }
    guard !transit.isEmpty else { return nil }
    return PlanModesInput(transit: PlanTransitModesInput(transit: transit))
}

private func preferencesInput(_ request: PlanRequest) -> PlanPreferencesInput? {
    // The router indexes legs with leg 0 = the initial access (walk, or nothing), so its wire
    // `maximumTransfers` counts boardings = transfers + 1 (wire 0 = walk-only, not exposed here).
    // `maxTransfers` is a transfer count, so map it to boardings: 0 transfers = 1 boarding (direct).
    let transit = request.maxTransfers.map { TransitPreferencesInput(transfer: TransferPreferencesInput(maximumTransfers: $0 + 1)) }
    let accessibility = request.wheelchairAccessible
        ? AccessibilityPreferencesInput(wheelchair: WheelchairPreferencesInput(enabled: true))
        : nil
    if transit == nil && accessibility == nil { return nil }
    return PlanPreferencesInput(accessibility: accessibility, transit: transit)
}

// MARK: - response mappers

private func mapItinerary(_ w: SpiderContract.Itinerary) -> Itinerary {
    Itinerary(
        start: w.start,
        end: w.end,
        durationSeconds: w.duration ?? 0,
        waitingTimeSeconds: w.waitingTime,
        numberOfTransfers: w.numberOfTransfers,
        accessibilityScore: w.accessibilityScore,
        legs: w.legs.map(mapLeg)
    )
}

// Shared wire→domain leg mapping, used by both the batch plan and the SSE stream (a stream chunk's
// itineraries are the same wire nodes as `planConnection.edges[].node`). Realtime delays ride here: each
// leg's estimated time + delay and its realtime state come straight off the wire node.
private func mapLeg(_ w: SpiderContract.Leg) -> Leg {
    Leg(
        mode: TransitMode.fromWire(w.mode?.rawValue),
        startScheduled: w.start.scheduledTime,
        endScheduled: w.end.scheduledTime,
        startEstimated: w.start.estimated?.time,
        endEstimated: w.end.estimated?.time,
        startDelaySeconds: parseDelaySeconds(w.start.estimated?.delay),
        endDelaySeconds: parseDelaySeconds(w.end.estimated?.delay),
        isRealtime: w.realTime ?? false,
        realtimeState: RealtimeState.fromWire(w.realtimeState?.rawValue),
        serviceDate: w.serviceDate,
        fromName: w.from.name,
        toName: w.to.name,
        fromGtfsId: w.from.stop?.gtfsId,
        toGtfsId: w.to.stop?.gtfsId,
        routeShortName: w.route?.shortName,
        routeLongName: w.route?.longName,
        headsign: w.headsign,
        distanceMeters: w.distance,
        durationSeconds: w.duration,
        tripGtfsId: w.trip?.gtfsId,
        bikesAllowed: BikesAllowed.fromWire(w.trip?.bikesAllowed?.rawValue),
        accessibilityScore: w.accessibilityScore,
        fromWheelchair: WheelchairBoarding.fromWire(w.from.stop?.wheelchairBoarding?.rawValue),
        toWheelchair: WheelchairBoarding.fromWire(w.to.stop?.wheelchairBoarding?.rawValue),
        geometry: w.legGeometry?.points.map(decodePolyline) ?? []
    )
}

// Parses a wire delay — an ISO-8601 duration ("PT60S", "PT1M30S", "-PT30S") or a bare integer of seconds —
// to whole seconds (positive = late, negative = early). Blank or unparseable input maps to nil.
func parseDelaySeconds(_ raw: String?) -> Int? {
    guard var s = raw?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
    if let seconds = Int(s) { return seconds }
    var sign = 1
    if s.hasPrefix("-") { sign = -1; s.removeFirst() } else if s.hasPrefix("+") { s.removeFirst() }
    guard s.hasPrefix("PT") else { return nil }
    s.removeFirst(2)
    var total = 0.0
    var number = ""
    var sawUnit = false
    for ch in s {
        if ch.isNumber || ch == "." { number.append(ch); continue }
        guard let value = Double(number) else { return nil }
        switch ch {
        case "H", "h": total += value * 3600
        case "M", "m": total += value * 60
        case "S", "s": total += value
        default: return nil
        }
        number = ""
        sawUnit = true
    }
    if !number.isEmpty || !sawUnit { return nil }
    return sign * Int(total.rounded())
}

private func mapDepartures(_ stop: StopDeparturesStop) -> [Departure] {
    let stopName = stop.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    var out: [Departure] = []
    for st in stop.stoptimesWithoutPatterns ?? [] {
        guard let serviceDay = st.serviceDay, let scheduledOffset = st.scheduledDeparture else { continue }
        if let headsign = st.headsign, headsign.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == stopName { continue }
        let route = st.trip?.route
        out.append(Departure(
            scheduledTimeEpochMs: Int64(serviceDay + scheduledOffset) * 1000,
            realtimeTimeEpochMs: st.realtimeDeparture.map { Int64(serviceDay + $0) * 1000 },
            isRealtime: st.realtime ?? false,
            realtimeState: RealtimeState.fromWire(st.realtimeState?.rawValue),
            headsign: st.headsign,
            tripGtfsId: st.trip?.gtfsId,
            routeShortName: route?.shortName,
            routeLongName: route?.longName,
            mode: TransitMode.fromWire(route?.mode?.rawValue)
        ))
    }
    return out
}

private func mapTrip(_ w: TripTrip) -> TripDetails {
    var stops: [TripStop] = []
    for st in w.stoptimesForDate ?? [] {
        guard let s = st.stop else { continue }
        let day = st.serviceDay
        func at(_ offset: Int?) -> Int64? {
            if let offset, let day { return Int64(day + offset) * 1000 }
            return nil
        }
        stops.append(TripStop(
            gtfsId: s.gtfsId,
            name: s.name,
            lat: s.lat,
            lon: s.lon,
            scheduledArrivalEpochMs: at(st.scheduledArrival),
            scheduledDepartureEpochMs: at(st.scheduledDeparture),
            realtimeArrivalEpochMs: at(st.realtimeArrival),
            realtimeDepartureEpochMs: at(st.realtimeDeparture),
            isRealtime: st.realtime ?? false,
            wheelchairBoarding: WheelchairBoarding.fromWire(s.wheelchairBoarding?.rawValue)
        ))
    }
    return TripDetails(
        gtfsId: w.gtfsId,
        routeShortName: w.route.shortName,
        routeLongName: w.route.longName,
        mode: TransitMode.fromWire(w.route.mode?.rawValue),
        headsign: w.tripHeadsign,
        directionId: w.directionId,
        bikesAllowed: BikesAllowed.fromWire(w.bikesAllowed?.rawValue),
        stops: stops,
        geometry: w.tripGeometry?.points.map(decodePolyline) ?? []
    )
}

private func clampSeconds(_ seconds: Int) -> Int {
    max(0, min(seconds, ROUTING_INT_MAX))
}

// MARK: - SSE plan-stream parsing

// The SSE event name a record defaults to when the server sends only `data:` lines.
private let SSE_DEFAULT_EVENT = "message"

private struct StreamChunkData: Decodable {
    let results: [SpiderContract.Itinerary]?
}

private struct StreamPageInfoData: Decodable {
    let startCursor: String?
    let endCursor: String?
    let hasNextPage: Bool?
    let hasPreviousPage: Bool?
    let searchWindowUsed: String?
}

private struct StreamErrorData: Decodable {
    let errors: [StreamGraphQLError]?
    let message: String?
}

private struct StreamGraphQLError: Decodable {
    let message: String?
    let extensions: StreamGraphQLErrorExtensions?
}

private struct StreamGraphQLErrorExtensions: Decodable {
    let code: String?
    let field: String?
}

// Parses one finished SSE record (event name + accumulated data) into a `PlanStreamEvent`; returns nil for
// records the SDK doesn't surface (heartbeats, unknown events, blank data, and the server's terminal `done`
// telemetry frame — the `pageInfo` frame is the terminal event the SDK exposes). A malformed payload becomes a
// terminal `.failure` rather than tearing the stream down. `internal` so the wire-contract test drives it.
func parsePlanStreamRecord(event: String, data: String) -> PlanStreamEvent? {
    guard !data.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    let bytes = Data(data.utf8)
    let decoder = JSONDecoder()
    switch event {
    case "chunk":
        do {
            let chunk = try decoder.decode(StreamChunkData.self, from: bytes)
            return .result((chunk.results ?? []).map(mapItinerary))
        } catch {
            return .failure(toSpiderError(SpiderDecodingError(message: "failed to decode plan-stream chunk", cause: error)))
        }
    case "pageInfo":
        do {
            let page = try decoder.decode(StreamPageInfoData.self, from: bytes)
            return .done(RoutePageInfo(
                startCursor: page.startCursor,
                endCursor: page.endCursor,
                hasNextPage: page.hasNextPage ?? false,
                hasPreviousPage: page.hasPreviousPage ?? false,
                searchWindowUsed: page.searchWindowUsed
            ))
        } catch {
            return .failure(toSpiderError(SpiderDecodingError(message: "failed to decode plan-stream pageInfo", cause: error)))
        }
    case "done":
        // Terminal server telemetry — it only marks the sweep's end; `pageInfo` already carried the cursors.
        return nil
    case "error":
        return .failure(streamErrorToSpiderError(data))
    default:
        return nil
    }
}

// A stream `error` record is the same GraphQL error envelope the batch path returns, so it maps through the
// same taxonomy — a top-level BAD_REQUEST becomes a typed `.badRequest` (with its field), anything else server.
private func streamErrorToSpiderError(_ data: String) -> SpiderError {
    if let payload = try? JSONDecoder().decode(StreamErrorData.self, from: Data(data.utf8)) {
        if let errors = payload.errors, !errors.isEmpty {
            if let bad = errors.first(where: { $0.extensions?.code == "BAD_REQUEST" }) {
                return toSpiderError(TransportError(.badRequest, bad.message ?? "", field: bad.extensions?.field))
            }
            let joined = errors.compactMap { $0.message }.joined(separator: ", ")
            return toSpiderError(TransportError(.upstream, "routing plan-stream errors: \(joined)"))
        }
        if let message = payload.message {
            return toSpiderError(TransportError(.upstream, "plan-stream error: \(message)"))
        }
    }
    return toSpiderError(TransportError(.upstream, "plan-stream error: \(String(data.prefix(300)))"))
}
