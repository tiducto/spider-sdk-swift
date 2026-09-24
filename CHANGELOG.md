# Changelog

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
