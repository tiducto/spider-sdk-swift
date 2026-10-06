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
    // data; `serviceDate` is the GTFS service date (`YYYY-MM-DD`) the trip runs on — pass it to
    // `SpiderRouting.trip` and `SpiderRealtime.delays`, don't derive one from a clock time (GTFS times can
    // exceed 24:00).
    public let startEstimated: String?
    public let endEstimated: String?
    public let startDelaySeconds: Int?
    public let endDelaySeconds: Int?
    public let isRealtime: Bool
    public let realtimeState: RealtimeState?
    public let serviceDate: String?
    /// The delay in seconds planned onto this leg's arrival at the requested `PlanOptions.reliability`. Nil when
    /// no reliability was requested or the trip has no delay history.
    public let typicalArrivalDelaySeconds: Int?
    public let fromName: String?
    public let toName: String?
    public let fromGtfsId: String?
    public let toGtfsId: String?
    /// The platform (GTFS `platform_code`) the leg boards at / alights at, when the feed has one.
    public let fromPlatformCode: String?
    public let toPlatformCode: String?
    /// The fare zone (GTFS `zone_id`) of the boarding / alighting stop, when the feed has one.
    public let fromZoneId: String?
    public let toZoneId: String?
    public let routeGtfsId: String?
    public let routeShortName: String?
    public let routeLongName: String?
    /// The route's colour: raw GTFS hex without `#` (e.g. `"FF0000"`), passed through as the feed gives it.
    /// Nil when the feed has none.
    public let routeColor: String?
    /// The colour of text drawn on `routeColor`: raw GTFS hex without `#` (e.g. `"FFFFFF"`). Nil when the feed
    /// has none.
    public let routeTextColor: String?
    public let headsign: String?
    public let distanceMeters: Double?
    public let durationSeconds: Double?
    public let tripGtfsId: String?
    /// True when the rider stays on the same vehicle from the previous leg, which carries on as another trip (often
    /// under another line number). Not counted in `Itinerary.numberOfTransfers`.
    public let interlineWithPreviousLeg: Bool
    public let bikesAllowed: BikesAllowed?
    @available(*, deprecated, message: "Always nil.")
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
    @available(*, deprecated, message: "Always nil.")
    public let accessibilityScore: Double?
    public let legs: [Leg]
}

/// One itinerary of a `Route` page.
public struct RouteEdge: Sendable, Equatable {
    @available(*, deprecated, message: "Always \"NoCursor\"; page with Route.pageInfo.")
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
    /// The usual delay in seconds at this stop for this trip: the median for the service date's day type, from the
    /// environment's realtime history. Nil when there is no history.
    public let typicalDelaySeconds: Int?
    public let headsign: String?
    public let tripGtfsId: String?
    /// The GTFS service date (`YYYY-MM-DD`) this departure's trip runs on — the previous day for a night
    /// departure past midnight. Pass it with `tripGtfsId` to `SpiderRouting.trip` and `SpiderRealtime.delays`.
    public let serviceDate: String
    public let routeGtfsId: String?
    public let routeShortName: String?
    public let routeLongName: String?
    /// The route's colour: raw GTFS hex without `#` (e.g. `"FF0000"`), passed through as the feed gives it.
    /// Nil when the feed has none.
    public let routeColor: String?
    /// The colour of text drawn on `routeColor`: raw GTFS hex without `#` (e.g. `"FFFFFF"`). Nil when the feed
    /// has none.
    public let routeTextColor: String?
    public let mode: TransitMode?
    /// The stop this departure leaves from (for a station, the platform) and its platform code (GTFS
    /// `platform_code`), when the feed has one.
    public let stopGtfsId: String?
    public let platformCode: String?
    /// Whether a wheelchair user can ride this departure's trip. Nil = no information.
    public let wheelchairAccessible: WheelchairBoarding?
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
    /// The usual delay in seconds at this stop for this trip: the median for the service date's day type, from the
    /// environment's realtime history. Nil when there is no history.
    public let typicalDelaySeconds: Int?
    public let wheelchairBoarding: WheelchairBoarding?
    /// The platform (GTFS `platform_code`) and fare zone (GTFS `zone_id`) of the stop, when the feed has them.
    public let platformCode: String?
    public let zoneId: String?
}

/// A single trip's route, stops, and geometry.
public struct TripDetails: Sendable, Equatable {
    public let gtfsId: String
    public let routeGtfsId: String?
    public let routeShortName: String?
    public let routeLongName: String?
    /// The route's colour: raw GTFS hex without `#` (e.g. `"FF0000"`), passed through as the feed gives it.
    /// Nil when the feed has none.
    public let routeColor: String?
    /// The colour of text drawn on `routeColor`: raw GTFS hex without `#` (e.g. `"FFFFFF"`). Nil when the feed
    /// has none.
    public let routeTextColor: String?
    public let mode: TransitMode?
    public let headsign: String?
    public let directionId: String?
    public let bikesAllowed: BikesAllowed?
    /// Whether a wheelchair user can ride this trip. Nil = no information.
    public let wheelchairAccessible: WheelchairBoarding?
    /// The GTFS service date (`YYYY-MM-DD`) the stop times are for — the value to pass to
    /// `SpiderRealtime.delays`. Nil when the trip has no stop times on the requested day.
    public let serviceDate: String?
    public let stops: [TripStop]
    public let geometry: [LatLon]
}

/// Options for a trip-plan search. `departAt`/`arriveBy` are mutually exclusive (arriveBy wins if both set;
/// neither = depart now). `allowedTransitModes` empty = all modes. `searchWindowMinutes` defaults to 60 and may go
/// up to the environment's search-window limit. `maxTransfers` nil = the environment's limit. `reliability` nil =
/// plan on the timetable alone.
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
    public var reliability: Reliability?

    public init(
        origin: Location,
        destination: Location,
        departAt: Date? = nil,
        arriveBy: Date? = nil,
        via: [ViaLocation] = [],
        allowedTransitModes: [TransitMode] = [],
        maxTransfers: Int? = nil,
        searchWindowMinutes: Int? = nil,
        wheelchairAccessible: Bool = false,
        reliability: Reliability? = nil
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
        self.reliability = reliability
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
    let reliability: Reliability?
}

private let DEFAULT_SEARCH_WINDOW_MINUTES = 60
// Fixed platform limits, checked before sending. The environment's own limits (search window, result count,
// number of via locations) are checked by the server.
private let MAX_TIME_RANGE_SECONDS = 86_400
private let MIN_STREAM_WINDOW_MINUTES = 120
private let MAX_VIA_STOP_IDS = 10
private let MAX_VIA_WAIT_SECONDS = 3_600
private let NO_CURSOR = "NoCursor"
private let PLAN_STREAM_PATH = "/routing/plan-stream"

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

    /// Plans a trip. Returns the first window of itineraries. A via location outside its fixed limits (1–10
    /// stop ids, a `minimumWaitSeconds` from 0 to 1 h) or a visit to a coordinate fails as `.badRequest` (field
    /// `via`) without a request.
    public func plan(_ options: PlanOptions) async throws -> SpiderResult<Route> {
        try await page(makeRequest(options))
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
    /// and any routing errors (or a terminal `.failure`, which is yielded — never thrown).
    ///
    /// `targetResults` is how many itineraries the sweep aims for, up to the environment's result count;
    /// `maxWindowMinutes` is how far it may search, from 120 (2 h) up to the environment's search-window limit,
    /// for departing and arriving alike. A `maxWindowMinutes` under 120 or a via location `plan` rejects fails as
    /// `.badRequest` without a request; a value above an environment limit fails the same way from the server.
    /// To continue, read `done.pageInfo` and call `planStreamNext(..., after: done.pageInfo.endCursor)` (when
    /// `hasNextPage`) or `planStreamPrevious(..., before: done.pageInfo.startCursor)` (when `hasPreviousPage`).
    /// `options.searchWindowMinutes` is ignored — the stream paces itself. For a single batched page, use `plan`.
    public func planStream(
        _ options: PlanOptions,
        targetResults: Int,
        maxWindowMinutes: Int
    ) -> AsyncStream<PlanStreamEvent> {
        planStreamInternal(options, targetResults: targetResults, maxWindowMinutes: maxWindowMinutes, after: nil, before: nil)
    }

    /// Continues a plan stream forward from `after` — the `pageInfo.endCursor` of a prior stream's terminal
    /// `.done` (only meaningful when that page's `hasNextPage` is true). Repeats `planStream`'s inputs
    /// so `targetResults` / `maxWindowMinutes` can differ per continuation. Same event contract as `planStream`.
    public func planStreamNext(
        _ options: PlanOptions,
        targetResults: Int,
        maxWindowMinutes: Int,
        after: String
    ) -> AsyncStream<PlanStreamEvent> {
        planStreamInternal(options, targetResults: targetResults, maxWindowMinutes: maxWindowMinutes, after: after, before: nil)
    }

    /// Continues a plan stream backward from `before` — the `pageInfo.startCursor` of a prior stream's terminal
    /// `.done` (only meaningful when that page's `hasPreviousPage` is true). Repeats `planStream`'s
    /// inputs so `targetResults` / `maxWindowMinutes` can differ per continuation. Same event contract as
    /// `planStream`.
    public func planStreamPrevious(
        _ options: PlanOptions,
        targetResults: Int,
        maxWindowMinutes: Int,
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

    /// Departures from a stop, soonest first: at most `numberOfDepartures` (from 1 up to the environment's
    /// limit), leaving within `timeRangeSeconds` (above 0, up to 24 h) of `startTime` (nil = now). A
    /// `timeRangeSeconds` outside that range fails as `.badRequest` (field `timeRange`) without a request.
    public func departures(
        _ stopId: String,
        numberOfDepartures: Int = 30,
        startTime: Date? = nil,
        timeRangeSeconds: Int = 86_400
    ) async throws -> SpiderResult<[Departure]> {
        guard (1...MAX_TIME_RANGE_SECONDS).contains(timeRangeSeconds) else { return .failure(outOfRange("timeRange")) }
        do {
            let body = DeparturesRequest(
                id: stopId,
                numberOfDepartures: numberOfDepartures,
                timeRange: timeRangeSeconds,
                startTime: startTime.map { Int($0.timeIntervalSince1970.rounded(.down)) }
            )
            let response: DeparturesResponse = try await transport.postJson("/routing/departures", body)
            guard let stop = response.stop else {
                throw TransportError(.noData, "routing returned no stop or station for id=\(stopId)")
            }
            return .success(mapDepartures(stop))
        } catch {
            return .failure(toSpiderError(error))
        }
    }

    /// A single trip's stops, times, and geometry on `serviceDate` (`YYYY-MM-DD`, e.g. a `Departure`'s or
    /// `Leg`'s `serviceDate`; nil = today). A malformed date fails as `.badRequest` without a request.
    public func trip(_ tripId: String, serviceDate: String? = nil) async throws -> SpiderResult<TripDetails> {
        if let serviceDate, !isServiceDate(serviceDate) {
            return .failure(invalid("serviceDate"))
        }
        do {
            let response: TripResponse = try await transport.postJson("/routing/trip", TripRequest(id: tripId, serviceDate: serviceDate))
            guard let trip = response.trip else {
                throw TransportError(.noData, "routing returned no trip for id=\(tripId)")
            }
            return .success(mapTrip(trip))
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
            wheelchairAccessible: options.wheelchairAccessible,
            reliability: options.reliability
        )
    }

    private func page(_ request: PlanRequest, before: String? = nil, after: String? = nil) async throws -> SpiderResult<Route> {
        do {
            return .success(try await fetchPlan(request, before: before, after: after))
        } catch {
            return .failure(toSpiderError(error))
        }
    }

    private func fetchPlan(_ request: PlanRequest, before: String?, after: String?) async throws -> Route {
        let body = PlanTripRequest(
            dateTime: dateTimeInput(request),
            origin: locationToInput(request.origin),
            destination: locationToInput(request.destination),
            searchWindow: "PT\(request.searchWindowMinutes)M",
            via: try viaInputs(request.via),
            modes: modesInput(request.allowedTransitModes),
            preferences: preferencesInput(request),
            before: before,
            after: after,
            reliability: reliabilityInput(request.reliability)
        )
        let plan: PlanTripResponse = try await transport.postJson("/routing/plan", body)
        let pageInfo = RoutePageInfo(
            startCursor: plan.pageInfo.startCursor,
            endCursor: plan.pageInfo.endCursor,
            hasNextPage: plan.pageInfo.hasNextPage,
            hasPreviousPage: plan.pageInfo.hasPreviousPage,
            searchWindowUsed: plan.pageInfo.searchWindowUsed
        )
        return Route(
            edges: plan.itineraries.map { RouteEdge(cursor: NO_CURSOR, itinerary: mapItinerary($0)) },
            pageInfo: pageInfo,
            routingErrors: plan.routingErrors.map(mapRoutingError),
            searchDateTime: plan.searchDateTime,
            request: request
        )
    }

    // The plan-stream body; internal so the wire-contract tests pin it. The stream paces itself, so no `searchWindow`.
    func streamBody(
        _ options: PlanOptions,
        targetResults: Int,
        maxWindowMinutes: Int,
        after: String?,
        before: String?
    ) throws -> PlanStreamRequest {
        let request = makeRequest(options)
        return PlanStreamRequest(
            dateTime: dateTimeInput(request),
            origin: locationToInput(request.origin),
            destination: locationToInput(request.destination),
            targetResults: targetResults,
            maxWindow: "PT\(maxWindowMinutes)M",
            via: try viaInputs(request.via),
            modes: modesInput(request.allowedTransitModes),
            preferences: preferencesInput(request),
            before: before,
            after: after,
            reliability: reliabilityInput(request.reliability)
        )
    }

    // Runs the SSE `plan-stream` request and pumps parsed events into the continuation. Uses
    // `URLSession.shared.bytes`, whose connection pool the default HTTP client (`.shared`) shares — so the
    // stream rides the same pool as the batch calls. Every failure — an input outside its fixed limits, a
    // non-2xx response, a decode slip, or a stream that ends before `pageInfo` — becomes a terminal `.failure`
    // event, never a throw. A cancelled task stops the sweep quietly.
    private func runPlanStream(
        _ options: PlanOptions,
        targetResults: Int,
        maxWindowMinutes: Int,
        after: String?,
        before: String?,
        into continuation: AsyncStream<PlanStreamEvent>.Continuation
    ) async {
        let urlRequest: URLRequest
        do {
            if maxWindowMinutes < MIN_STREAM_WINDOW_MINUTES { throw outOfRange("maxWindow") }
            let body = try streamBody(
                options, targetResults: targetResults, maxWindowMinutes: maxWindowMinutes, after: after, before: before
            )
            urlRequest = try transport.streamingRequest(PLAN_STREAM_PATH, body)
        } catch {
            continuation.yield(.failure(toSpiderError(error)))
            return
        }

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                var body = Data()
                for try await byte in bytes {
                    body.append(byte)
                    if body.count >= 4096 { break }
                }
                let failure = httpFailure("POST \(PLAN_STREAM_PATH)", status: http.statusCode, body: String(decoding: body, as: UTF8.self))
                continuation.yield(.failure(toSpiderError(failure)))
                return
            }
            var eventName: String?
            var dataLines: [String] = []
            var sawPageInfo = false
            var failed = false
            func flush() {
                defer { eventName = nil; dataLines = [] }
                guard !dataLines.isEmpty,
                      let event = parsePlanStreamRecord(event: eventName ?? SSE_DEFAULT_EVENT, data: dataLines.joined(separator: "\n"))
                else { return }
                continuation.yield(event)
                switch event {
                case .done: sawPageInfo = true
                case .failure: failed = true
                case .result: break
                }
            }
            func handle(_ line: String) {
                if line.isEmpty { flush(); return }
                if line.hasPrefix(":") { return } // comment / heartbeat
                guard let colon = line.firstIndex(of: ":") else { return }
                let field = String(line[..<colon])
                var value = String(line[line.index(after: colon)...])
                if value.hasPrefix(" ") { value.removeFirst() }
                switch field {
                case "event": eventName = value
                case "data": dataLines.append(value)
                default: break // id / retry ignored
                }
            }
            // Split lines by hand: `bytes.lines` drops empty lines, and the empty line is what ends an SSE record.
            var line: [UInt8] = []
            for try await byte in bytes {
                guard byte == UInt8(ascii: "\n") else { line.append(byte); continue }
                if line.last == UInt8(ascii: "\r") { line.removeLast() }
                handle(String(decoding: line, as: UTF8.self))
                line.removeAll(keepingCapacity: true)
                if failed { return }
            }
            if !line.isEmpty { handle(String(decoding: line, as: UTF8.self)) }
            flush() // a trailing record with no terminating blank line
            if !failed && !sawPageInfo {
                continuation.yield(.failure(toSpiderError(TransportError(.upstream, "plan-stream ended before pageInfo"))))
            }
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

private func dateTimeInput(_ request: PlanRequest) -> PlanDateTimeInput {
    let iso = planIsoFormatter.string(from: request.time)
    return request.timeKind == .departAt ? PlanDateTimeInput(earliestDeparture: iso) : PlanDateTimeInput(latestArrival: iso)
}

// The via locations on the wire, rejecting any outside the fixed limits; how many there may be is the server's to check.
private func viaInputs(_ via: [ViaLocation]) throws -> [PlanViaLocationInput]? {
    guard !via.isEmpty else { return nil }
    return try via.map { location in
        switch location {
        case .passThrough(let stopIds):
            guard (1...MAX_VIA_STOP_IDS).contains(stopIds.count) else { throw outOfRange("via") }
            return PlanViaLocationInput(passThrough: PlanPassThroughViaLocationInput(stopLocationIds: stopIds))
        case .visit(.coordinate, _):
            throw invalid("via")
        case .visit(.stop(let id), let minimumWaitSeconds):
            guard (0...MAX_VIA_WAIT_SECONDS).contains(minimumWaitSeconds) else { throw outOfRange("via") }
            let wait = minimumWaitSeconds > 0 ? "PT\(minimumWaitSeconds)S" : nil
            return PlanViaLocationInput(visit: PlanVisitViaLocationInput(stopLocationIds: [id], minimumWaitTime: wait))
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
    return PlanPreferencesInput(transit: transit, accessibility: accessibility)
}

private func reliabilityInput(_ reliability: Reliability?) -> SpiderContract.Reliability? {
    reliability.flatMap { SpiderContract.Reliability(rawValue: $0.rawValue) }
}

// MARK: - response mappers

private func mapItinerary(_ w: SpiderContract.Itinerary) -> Itinerary {
    Itinerary(
        start: w.start,
        end: w.end,
        durationSeconds: w.duration ?? 0,
        waitingTimeSeconds: w.waitingTime,
        numberOfTransfers: w.numberOfTransfers,
        accessibilityScore: nil,
        legs: w.legs.map(mapLeg)
    )
}

// Shared wire→domain leg mapping, used by both the batch plan and the SSE stream (a stream chunk's
// itineraries are the same wire `Itinerary` as the plan's). Realtime delays ride here: each
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
        typicalArrivalDelaySeconds: w.typicalArrivalDelay,
        fromName: w.from.name,
        toName: w.to.name,
        fromGtfsId: w.from.stop?.gtfsId,
        toGtfsId: w.to.stop?.gtfsId,
        fromPlatformCode: w.from.stop?.platformCode,
        toPlatformCode: w.to.stop?.platformCode,
        fromZoneId: w.from.stop?.zoneId,
        toZoneId: w.to.stop?.zoneId,
        routeGtfsId: w.route?.gtfsId,
        routeShortName: w.route?.shortName,
        routeLongName: w.route?.longName,
        routeColor: w.route?.color,
        routeTextColor: w.route?.textColor,
        headsign: w.headsign,
        distanceMeters: w.distance,
        durationSeconds: w.duration,
        tripGtfsId: w.trip?.gtfsId,
        interlineWithPreviousLeg: w.interlineWithPreviousLeg ?? false,
        bikesAllowed: BikesAllowed.fromWire(w.trip?.bikesAllowed?.rawValue),
        accessibilityScore: nil,
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

private func mapRoutingError(_ w: SpiderContract.RoutingError) -> RoutingError {
    RoutingError(
        code: RoutingErrorCode.fromWire(w.code.rawValue),
        description: w.description,
        inputField: InputField.fromWire(w.inputField?.rawValue)
    )
}

private func mapDepartures(_ stop: DepartureBoard) -> [Departure] {
    var out: [Departure] = []
    for st in stop.stoptimesWithoutPatterns ?? [] {
        guard let serviceDay = st.serviceDay, let scheduledOffset = st.scheduledDeparture else { continue }
        let route = st.trip?.route
        out.append(Departure(
            scheduledTimeEpochMs: Int64(serviceDay + scheduledOffset) * 1000,
            realtimeTimeEpochMs: st.realtimeDeparture.map { Int64(serviceDay + $0) * 1000 },
            isRealtime: st.realtime ?? false,
            realtimeState: RealtimeState.fromWire(st.realtimeState?.rawValue),
            typicalDelaySeconds: st.typicalDelay,
            headsign: st.headsign,
            tripGtfsId: st.trip?.gtfsId,
            serviceDate: isoServiceDate(ofServiceDay: serviceDay),
            routeGtfsId: route?.gtfsId,
            routeShortName: route?.shortName,
            routeLongName: route?.longName,
            routeColor: route?.color,
            routeTextColor: route?.textColor,
            mode: TransitMode.fromWire(route?.mode?.rawValue),
            stopGtfsId: st.stop?.gtfsId,
            platformCode: st.stop?.platformCode,
            wheelchairAccessible: WheelchairBoarding.fromWire(st.trip?.wheelchairAccessible?.rawValue)
        ))
    }
    return out
}

private func mapTrip(_ w: TripTimetable) -> TripDetails {
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
            typicalDelaySeconds: st.typicalDelay,
            wheelchairBoarding: WheelchairBoarding.fromWire(s.wheelchairBoarding?.rawValue),
            platformCode: s.platformCode,
            zoneId: s.zoneId
        ))
    }
    return TripDetails(
        gtfsId: w.gtfsId,
        routeGtfsId: w.route.gtfsId,
        routeShortName: w.route.shortName,
        routeLongName: w.route.longName,
        routeColor: w.route.color,
        routeTextColor: w.route.textColor,
        mode: TransitMode.fromWire(w.route.mode?.rawValue),
        headsign: w.tripHeadsign,
        directionId: w.directionId,
        bikesAllowed: BikesAllowed.fromWire(w.bikesAllowed?.rawValue),
        wheelchairAccessible: WheelchairBoarding.fromWire(w.wheelchairAccessible?.rawValue),
        serviceDate: w.stoptimesForDate?.lazy.compactMap(\.serviceDay).first.map { isoServiceDate(ofServiceDay: $0) },
        stops: stops,
        geometry: w.tripGeometry?.points.map(decodePolyline) ?? []
    )
}

// MARK: - SSE plan-stream parsing

// The SSE event name a record defaults to when the server sends only `data:` lines.
private let SSE_DEFAULT_EVENT = "message"

// Parses one finished SSE record into a `PlanStreamEvent`: `chunk` → `.result`, `pageInfo` → `.done`, a malformed
// payload → `.failure`. Nil for every other record: `done` only ends the stream, and unknown events are ignored.
func parsePlanStreamRecord(event: String, data: String) -> PlanStreamEvent? {
    guard !data.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    let bytes = Data(data.utf8)
    do {
        switch event {
        case "chunk":
            let chunk: PlanStreamChunkEvent = try decode(from: bytes, where: "plan-stream chunk")
            return .result(chunk.results.map(mapItinerary))
        case "pageInfo":
            let page: PlanStreamPageInfoEvent = try decode(from: bytes, where: "plan-stream pageInfo")
            let pageInfo = RoutePageInfo(
                startCursor: page.startCursor,
                endCursor: page.endCursor,
                hasNextPage: page.hasNextPage,
                hasPreviousPage: page.hasPreviousPage,
                searchWindowUsed: page.searchWindowUsed
            )
            return .done(PlanStreamEvent.Done(pageInfo: pageInfo, routingErrors: page.routingErrors.map(mapRoutingError)))
        default:
            return nil
        }
    } catch {
        return .failure(toSpiderError(error))
    }
}
