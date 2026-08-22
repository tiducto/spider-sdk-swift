# spider-sdk-swift

The Swift SDK for the **Spider** transit API — trip planning, stop search, and live realtime data behind one
typed client. It ships the exact query documents the gateway allows and attaches auth for you, so you get a
typed, closed surface out of the box.

This is a native Swift package with **no runtime dependencies** (it uses `Foundation`/`URLSession`). It is a
sibling of the Kotlin and TypeScript SDKs and mirrors their domain model and semantics, adapted to Swift idioms
(`async`/`await`, `AsyncThrowingStream`, `Codable`).

## Supported platforms

iOS 15+ · macOS 12+ · tvOS 15+ · watchOS 8+ · Swift 5.9+

## Install

Swift Package Manager. In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/tiducto/spider-sdk-swift.git", from: "5.1.1"),
],
targets: [
    .target(name: "YourApp", dependencies: [.product(name: "SpiderSDK", package: "spider-sdk-swift")]),
]
```

Or in Xcode: **File ▸ Add Package Dependencies…** and paste the repo URL.

## Quickstart

Construct a client with your environment's base URL and API key, then call a surface. Every call returns a
`SpiderResult<T>` you branch on before reading the value.

```swift
import SpiderSDK

let client = SpiderClient(baseURL: "https://your-env-slug.api.tiducto.eu", apiKey: ProcessInfo.processInfo.environment["SPIDER_API_KEY"]!)

let result = try await client.routing.plan(PlanOptions(
    origin: .coordinate(49.1908, 16.6128),
    destination: .coordinate(49.2270, 16.5273),
    first: 3
))

switch result {
case .success(let route):
    for edge in route.edges {
        let legs = edge.itinerary.legs.map { $0.mode?.rawValue ?? "WALK" }.joined(separator: " → ")
        print("\(edge.itinerary.durationSeconds / 60) min: \(legs)")
    }
case .failure(let error):
    print("plan failed: \(error.code) — \(error.message)")
}
```

### Trip planning

```swift
// Filter modes, cap transfers, prefer step-free routing, widen the search window.
let result = try await client.routing.plan(PlanOptions(
    origin: .stop("U123Z1"),
    destination: .coordinate(49.19, 16.61),
    departAt: Date(),
    allowedTransitModes: [.tram, .bus, .subway],
    maxTransfers: 2,
    searchWindowMinutes: 90,
    wheelchairAccessible: true
))

// Page forward / backward.
if case .success(let route) = result, let next = try await client.routing.planNext(route) { /* … */ }

// Or stream itineraries, stepping the search window until you have enough.
for try await page in client.routing.planUntil(PlanOptions(origin: .stop("A"), destination: .stop("B")), targetResults: 20) {
    if case .success(let route) = page { /* collect route.edges */ }
}
```

### Departures & a single trip

```swift
let departures = try await client.routing.departures("U123Z1", numberOfDepartures: 10)
let trip = try await client.routing.trip("T-4821", serviceDate: "2026-08-21")
```

### Stop search

```swift
let stops = try await client.stops.search(StopFilter(name: "Náměstí", city: "Brno"))
```

### Realtime (poll-based)

```swift
// One-shot.
let positions = try await client.realtime.vehicles(["T-1", "T-2"])
let alerts = try await client.realtime.alerts()

// Or a change-detecting stream (yields only when the data changes; cancel the task to stop).
for try await update in client.realtime.pollVehicles(["T-1", "T-2"], intervalMs: 10_000) {
    if case .success(let positions) = update { /* update the map */ }
}
```

## Errors

Ordinary failures are values, not thrown: every call returns `SpiderResult<T>`, and `.failure` carries a
`SpiderError` with a stable `code` (`network`, `timeout`, `unauthorized`, `notFound`, `server`, `rateLimited`,
`decoding`, `unknown`). The **one** thrown error is `SpiderContractMismatchError` — raised when the gateway
speaks a different **major** contract version than this SDK, so it surfaces as a hard failure rather than a
soft result.

## Options

```swift
let client = SpiderClient(baseURL: base, apiKey: key, options: SpiderClientOptions(
    timeout: 20,                                             // seconds, default 30
    routing: FeatureOptions(autoRetry: AutoRetryOptions(maxAttempts: 3)) // opt-in retries, per surface
))
```

Retries (opt-in per surface) back off on `429`/`5xx` and network/timeout errors, honoring a numeric
`Retry-After`. Inject a custom `HTTPClient` via `SpiderClientOptions(httpClient:)` for tests or proxies.

## Contract & codegen

The wire models under `Sources/SpiderContract/` and the persisted-query ids are **generated** from the
published contract by `scripts/generate-contract.sh` (via `tiducto/spider-codegen`) and committed — the package
carries the types, not the spec. `client.contractVersion` reports the contract version this SDK speaks (`5.1`).
Do not hand-edit generated files; re-run the script.
