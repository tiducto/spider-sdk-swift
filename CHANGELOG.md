# Changelog

## 1.2.0

Targets Spider API contract 1.2. Routing moves from persisted GraphQL queries to REST, and every routing, stop
and realtime call moves to a `/v1` path. The calls are made the same way as in 1.1; the changes are below.

Once the API serves contract 1.2, SDK 1.1 and earlier stop working: the paths they call are no longer served.

### Changed

- **Routing, stop and realtime calls go to `/v1` paths.** Routing is REST: `plan` / `planNext` / `planPrevious`
  POST a JSON body to `/routing/v1/plan`, the plan stream to `/routing/v1/plan-stream`, `departures` to
  `/routing/v1/departures` and `trip` to `/routing/v1/trip`. Stop search calls `/stops/v1/search`, and realtime
  `/realtime/v1/vehicles`, `/realtime/v1/vehicles/by-trip/{id}`, `/realtime/v1/delays` and `/realtime/v1/alerts`.
- **Every HTTP 410, on any surface, is `.queryRetired`**: the API no longer serves the part this SDK version calls.
- **`SpiderError.field` on a `.badRequest`** is the server's `field` when the body has one: a dot path from the
  request body's root (e.g. `preferences.transit.transfer.maximumTransfers`). Otherwise it is the field a
  `<field> is required|invalid|out of range|not allowed` message names, dot paths included.
- **A via visit to a coordinate fails before any request**, as `.badRequest` `via is invalid` (field `via`), the
  answer the server always gave. Visit a stop: `.visit(.stop(id), minimumWaitSeconds:)`.
- **A via visit's `minimumWaitSeconds` is 0 to 3 600 (1 h)**; outside that it fails as `.badRequest`
  `via.visit.minimumWaitTime is out of range` (field `via.visit.minimumWaitTime`) without a request.
- **Plan streams.** A stream that ends before its `.done` (the connection dropped) ends with a `.failure`
  (`.network`), the same failure a dropped batch call gets. Events this SDK doesn't know are skipped, so new
  events are additive. A malformed event's `.failure` is the last event of its stream.
- **The plan-limit refusals** (`.planningLimitReached`, `.agreementInactive`) are recognised by the body's `code`
  as well as its `error`.
- **`serverCode` no longer carries `persisted_query_rejected`** (HTTP 403): the API no longer sends it.

### Deprecated

Removal candidates for 2.0:

- `RouteEdge.cursor` is always `"NoCursor"`. Page with `Route.pageInfo` (`planNext` / `planPrevious`).
- `Itinerary.accessibilityScore` and `Leg.accessibilityScore` are always nil.

## 1.1.0

Targets Spider API contract 1.1.

### Added

- **`PlanOptions.reliability`** (`Reliability`: `.standard`, `.safe`, `.verySafe`) for `plan` and `planStream`:
  each leg's arrival is planned with the trip's typical delay at that stop, the median at `.standard`, the 70th
  percentile at `.safe`, the 90th at `.verySafe`. Boarding keeps the scheduled departure, and a trip with live
  realtime uses its realtime times. Nil (the default) plans on the timetable alone.
- **Typical delays.** `Leg.typicalArrivalDelaySeconds`: the delay planned onto the leg's arrival at the requested
  reliability, nil without one. `Departure.typicalDelaySeconds` and `TripStop.typicalDelaySeconds`: the usual
  delay at the stop for that trip, the median for the service date's day type. All come from the environment's
  realtime history and are nil when there is none.
- **`Leg.interlineWithPreviousLeg`**: true when the rider stays on the same vehicle from the previous leg, which
  carries on as another trip, often under another line number. That change is not counted in
  `numberOfTransfers`.

### Changed

- Requests use the contract 1.1 persisted queries. The 1.0 queries stay served until 2027-07-01.

## 1.0.0

Targets Spider API contract 1.0. The first stable release: from here on, breaking changes need a new major.

### Changed

- **`planStream` / `planStreamNext` / `planStreamPrevious` require `targetResults:` and `maxWindowMinutes:`.**
  There is no SDK default; `maxWindowMinutes` must be at least 120.
- **`PlanStreamEvent.done` carries `PlanStreamEvent.Done`**: `pageInfo` (the continuation cursors) and
  `routingErrors`, shaped as in `plan` and empty when there are none. A `LOCATION_NOT_FOUND` names `.from`,
  `.to` or `.via` in `inputField`.
- **`WheelchairBoarding` and `BikesAllowed` gain `.unknown`**, like the other decoded enums (`TransitMode`,
  `RealtimeState`, `RoutingErrorCode`, `InputField`, `OccupancyStatus`): a value this SDK version doesn't know
  decodes to `.unknown` instead of nil. `NO_INFORMATION` / `NO_DATA_AVAILABLE` stay nil. An exhaustive `switch`
  needs the new cases.
- **HTTP 400 is `.badRequest`** (it was `.unknown`), with `field` set when the server's message names one.
- **Invalid input is rejected before any request**, as `.badRequest` naming only the field (e.g.
  `maxWindow is out of range`): a stream window under 2 h (`maxWindow`), a departures `timeRangeSeconds` outside
  1–86 400 (`timeRange`), more than 50 realtime trip ids across all service dates (`tripIds`), a
  `StopFilter.limit` outside 1–50 (`limit`), a via pass-through without 1–10 stop ids or a visit wait outside
  0–86 400 s (`via`), or a malformed `serviceDate` in `trip` or `delays` (`serviceDate is invalid`). Nothing is
  clamped.
- **Defaults are always sent.** `departures` sends 30 departures over 24 h unless told otherwise, and
  `timeRangeSeconds` is a non-optional `Int` (default 86 400). `StopFilter.limit`, `near(…limit:)` and
  `within(…limit:)` take a non-optional `Int` (default 20). Drop any explicit `nil`.
- An unknown persisted-query id (403 `persisted_query_rejected`) stays `.unauthorized` and keeps the gateway's
  message.

### Added

- **`SpiderErrorCode.queryRetired`** (`query_retired`) for a persisted query the API no longer serves
  (HTTP 410).
- **`SpiderErrorCode.planningLimitReached`** (`planning_limit_reached`) when the project has reached the
  trip-planning limit its plan includes: trip planning (`plan`, `planStream`) is refused, the other calls keep
  working.
- **`SpiderErrorCode.agreementInactive`** (`agreement_inactive`) when the project's agreement is not active:
  every call made with the key is refused.
  Both come from the response body's code whatever the HTTP status, on every surface (including a plan stream
  refused before it starts). A `vehicleForTrip` 404 carrying one of them is that error, not "no vehicle". The
  message is the body's, with `trip planning limit reached` / `agreement is not active` when the body has none,
  and the error carries `httpStatus` and `serverCode`. A 403 without one of these codes stays `.unauthorized`.
  An exhaustive `switch` on `SpiderErrorCode` needs the three new cases.
- **Display fields.** `Leg`: `routeGtfsId`, `routeColor`, `routeTextColor`, `fromPlatformCode`,
  `toPlatformCode`, `fromZoneId`, `toZoneId`. `Departure`: `routeGtfsId`, `routeColor`, `routeTextColor`,
  `stopGtfsId`, `platformCode`, `wheelchairAccessible`. `TripDetails`: `routeGtfsId`, `routeColor`,
  `routeTextColor`, `wheelchairAccessible`. `TripStop`: `platformCode`, `zoneId`. Colours are the feed's GTFS
  hex without `#`.
- **`Departure.serviceDate` and `TripDetails.serviceDate`** (ISO `YYYY-MM-DD`): the GTFS service date the trip
  runs on. A departure after midnight on a night line belongs to the previous day's service; pass this value to
  `delays`.
- **Stops:** `Stop.code`, `Stop.locationType`, `Stop.wheelchairBoarding`, `Stop.modes`, and
  `StopFilter.modes` (stops served by at least one of the modes). Search text also matches a stop's code, town
  and district.

### Removed

- `SpiderContractMismatchError`: a gateway declaring another contract major is no longer an error.
- The departures filter that dropped rows whose headsign equals the stop name.

### Fixed

- `planStream` yields every record. `bytes.lines` dropped the blank lines that end each SSE record, so the
  records merged and the stream yielded nothing.
- A `planStream` answered with a 200 JSON GraphQL error (a missing required variable) ends with `.badRequest`
  naming the field, instead of ending without an event.

## 0.7.1

### Changed

- The streaming plan surface is reshaped around cursor continuation. `planStream(_:targetResults:maxWindowMinutes:)`
  streams the initial window; `planStreamNext(_:targetResults:maxWindowMinutes:after:)` and
  `planStreamPrevious(_:targetResults:maxWindowMinutes:before:)` continue forward/backward from a raw cursor
  string. `PlanStreamEvent` is now three variants — `.result([Itinerary])` (a batch of finalized itineraries as
  the sweep advances), `.done(RoutePageInfo)` (terminal; carries the continuation cursors `endCursor` /
  `startCursor` and `hasNextPage` / `hasPreviousPage`), and `.failure(SpiderError)` (terminal, yielded not
  thrown). Read `done.pageInfo` to decide whether and how to continue.

### Removed

- `planUntil` / `planNextUntil` / `planPreviousUntil` — the client-side window-walkers. Drive the sweep with
  `planStream` plus `planStreamNext` / `planStreamPrevious`, continuing from the terminal `.done` page's cursors.

## 0.7.0

Syncs to Spider API contract 0.7 and brings the SDK to parity with the reference SDKs.

### Added

- `SpiderRouting.planStream(...)` — streams itineraries over Server-Sent Events as the router sweeps
  the search window forward, emitting `PlanStreamEvent` values (`.chunk` / `.page` / `.done`, or a
  terminal `.failure`) instead of one batched page. Each `.chunk`'s legs carry the same realtime
  delays as the one-shot `plan`; `targetResults` / `maxWindowMinutes` pace the sweep and
  `after` / `before` continue from a prior `.page`'s cursors. Cold and cancellable, and it never
  throws — failures arrive as a terminal `.failure` event.
- `Leg` now surfaces realtime data: `startEstimated` / `endEstimated`, `startDelaySeconds` /
  `endDelaySeconds` (positive = late, negative = early), `isRealtime`, `realtimeState`, `serviceDate`,
  and the endpoint stop ids `fromGtfsId` / `toGtfsId`.
- `SpiderClient.warmup()` — pre-warms the connection to the environment API host so the first real
  call rides an already-open TLS connection instead of paying the ~0.6s cold-connect cost. Issues one
  `GET /ping` (authenticated with the client apikey) through the SDK's shared `URLSession`;
  best-effort (never throws), returns the measured elapsed seconds. Call at app start or on
  foreground, fire-and-forget.

### Changed

- **Realtime `delays` now resolves per trip instance** (breaking). A GTFS-RT delay is bound to a
  `(tripId, serviceDate)` instance, so `SpiderRealtime.delays` takes the service date each trip runs
  on — `delays(byServiceDate:)` (or `delays(_:serviceDate:)` for a single day) — and returns
  `TripDelays.groups: [ServiceDateDelays]`, looked up per instance via `delayFor(tripId:serviceDate:)`.
  `serviceDate` is the GTFS service date `YYYYMMDD`, taken from the plan leg (not the departure clock —
  GTFS times can exceed 24:00). The request is now a grouped POST; `pollDelays` mirrors the new
  signatures. The old flat `delays(_:)` / `pollDelays(_:)` are removed.
- The client apikey is applied once per client (through the shared `Transport` request builder)
  instead of per call, and the warm-up `/ping` probe now carries it (the gateway `/ping` route is
  moving keyless → keyed).

### Fixed

- `maxTransfers` now maps to the router's boarding count (`maximumTransfers = transfers + 1`). The
  router indexes legs with leg 0 as the initial access (walk, or nothing), so passing the caller's
  transfer count verbatim made `maxTransfers` 0 and 1 behave identically. Now `0` means direct,
  `1` allows one transfer, and so on.

## 0.1.0 — 2026-08-22

Initial public pre-release; targets Spider API contract 0.1.

This is a pre-1.0 release: the API surface is not yet stable and may change in
backward-incompatible ways before 1.0.

Covered surfaces:

- Trip planning (`planConnection`)
- Stop departures
- Single-trip lookup
- Stop text and geographic search
- Realtime vehicles, delays, and alerts
