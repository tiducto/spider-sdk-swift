import Foundation
import SpiderContract

// MARK: - Public routing models

/// One leg of an itinerary (a single vehicle ride or walk).
public struct Leg: Sendable, Equatable {
    public let mode: TransitMode?
    public let startScheduled: String
    public let endScheduled: String
    public let fromName: String?
    public let toName: String?
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
    public var first: Int?
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
        first: Int? = nil,
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
        self.first = first
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

private enum PageDirection { case forward, backward }

// Public methods inline these as literal default arguments (5 / 10 / 360) — public default args cannot
// reference non-public symbols. Keep the literals below in sync with these names if you change them.
private let DEFAULT_FIRST = 5
private let DEFAULT_SEARCH_WINDOW_MINUTES = 60
private let MAX_RESULTS_PER_STEP = 50
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

    /// Plans a trip. Returns the first page of itineraries.
    public func plan(_ options: PlanOptions) async throws -> SpiderResult<Route> {
        let request = makeRequest(options)
        return try await page(request, first: options.first ?? DEFAULT_FIRST)
    }

    /// The next page after `route`, or nil if there is none.
    public func planNext(_ route: Route, first: Int = 5) async throws -> SpiderResult<Route>? {
        guard route.pageInfo.hasNextPage else { return nil }
        return try await page(route.request, first: first, after: route.pageInfo.endCursor)
    }

    /// The previous page before `route`, or nil if there is none. Pages backward (last + before), Relay-correct.
    public func planPrevious(_ route: Route, last: Int = 5) async throws -> SpiderResult<Route>? {
        guard route.pageInfo.hasPreviousPage else { return nil }
        return try await page(route.request, last: last, before: route.pageInfo.startCursor)
    }

    /// Streams itineraries forward, one search window per step, until `targetResults` are collected or
    /// `maxTraversalMinutes` of time is traversed. Lazy: stop iterating to skip the remaining searches.
    public func planUntil(
        _ options: PlanOptions,
        targetResults: Int = 10,
        maxTraversalMinutes: Int = 360
    ) -> AsyncThrowingStream<SpiderResult<Route>, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let windowMin = options.searchWindowMinutes ?? DEFAULT_SEARCH_WINDOW_MINUTES
                    let steps = stepCount(maxTraversalMinutes, windowMin)
                    var opts = options
                    opts.first = MAX_RESULTS_PER_STEP
                    let first = try await self.plan(opts)
                    continuation.yield(first)
                    guard case .success(let route) = first else { continuation.finish(); return }
                    try await self.stepStream(
                        from: route, direction: .forward, remainingSteps: steps - 1,
                        targetResults: targetResults, collectedSoFar: route.edges.count, continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Streaming form of `planNext`: steps forward from `prev`.
    public func planNextUntil(
        _ prev: Route,
        targetResults: Int = 10,
        maxTraversalMinutes: Int = 360
    ) -> AsyncThrowingStream<SpiderResult<Route>, Error> {
        streamFrom(prev, direction: .forward, targetResults: targetResults, maxTraversalMinutes: maxTraversalMinutes)
    }

    /// Streaming form of `planPrevious`: steps backward from `prev`.
    public func planPreviousUntil(
        _ prev: Route,
        targetResults: Int = 10,
        maxTraversalMinutes: Int = 360
    ) -> AsyncThrowingStream<SpiderResult<Route>, Error> {
        streamFrom(prev, direction: .backward, targetResults: targetResults, maxTraversalMinutes: maxTraversalMinutes)
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

    private func page(_ request: PlanRequest, first: Int? = nil, last: Int? = nil, before: String? = nil, after: String? = nil) async throws -> SpiderResult<Route> {
        do {
            return .success(try await fetchPlan(request, first: first, last: last, before: before, after: after))
        } catch let error as SpiderContractMismatchError {
            throw error
        } catch {
            return .failure(toSpiderError(error))
        }
    }

    private func fetchPlan(_ request: PlanRequest, first: Int?, last: Int?, before: String?, after: String?) async throws -> Route {
        let iso = planIsoFormatter.string(from: request.time)
        let dateTime = request.timeKind == .departAt
            ? PlanDateTimeInput(earliestDeparture: iso)
            : PlanDateTimeInput(latestArrival: iso)
        let variables = PlanConnectionVariables(
            dateTime: dateTime,
            origin: locationToInput(request.origin),
            destination: locationToInput(request.destination),
            via: request.via.isEmpty ? nil : request.via.map(viaToInput),
            modes: modesInput(request.allowedTransitModes),
            preferences: preferencesInput(request),
            searchWindow: "PT\(max(1, request.searchWindowMinutes))M",
            first: first,
            last: last,
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

    private func streamFrom(_ prev: Route, direction: PageDirection, targetResults: Int, maxTraversalMinutes: Int) -> AsyncThrowingStream<SpiderResult<Route>, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let steps = stepCount(maxTraversalMinutes, prev.request.searchWindowMinutes)
                    try await self.stepStream(
                        from: prev, direction: direction, remainingSteps: steps,
                        targetResults: targetResults, collectedSoFar: 0, continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func stepStream(
        from start: Route,
        direction: PageDirection,
        remainingSteps: Int,
        targetResults: Int,
        collectedSoFar: Int,
        continuation: AsyncThrowingStream<SpiderResult<Route>, Error>.Continuation
    ) async throws {
        if collectedSoFar >= targetResults { return }
        var prev = start
        var collected = collectedSoFar
        var i = 0
        while i < max(0, remainingSteps) {
            if Task.isCancelled { return }
            let result = direction == .forward
                ? try await planNext(prev, first: MAX_RESULTS_PER_STEP)
                : try await planPrevious(prev, last: MAX_RESULTS_PER_STEP)
            guard let result else { return }
            continuation.yield(result)
            guard case .success(let route) = result else { return }
            collected += route.edges.count
            if collected >= targetResults { return }
            prev = route
            i += 1
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
    let transit = request.maxTransfers.map { TransitPreferencesInput(transfer: TransferPreferencesInput(maximumTransfers: $0)) }
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

private func mapLeg(_ w: SpiderContract.Leg) -> Leg {
    Leg(
        mode: TransitMode.fromWire(w.mode?.rawValue),
        startScheduled: w.start.scheduledTime,
        endScheduled: w.end.scheduledTime,
        fromName: w.from.name,
        toName: w.to.name,
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

// Each cursor step advances a full (fixed) search window, so steps to cover the total time is a plain division.
private func stepCount(_ maxTraversalMinutes: Int, _ stepMinutes: Int) -> Int {
    max(1, maxTraversalMinutes / max(1, stepMinutes))
}
