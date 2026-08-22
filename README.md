# spider-sdk-swift

The Swift SDK for **Spider** — the managed transit API by Tiducto. Trip planning, stop search, and live realtime data behind one typed client that ships the exact queries the gateway allows and attaches auth for you.

Native Swift package, no runtime dependencies (`Foundation`/`URLSession`). Sibling of the Kotlin, TypeScript, and Dart SDKs — same domain model, Swift idioms (`async`/`await`, `AsyncThrowingStream`, `Codable`).

## Supported platforms

iOS 15+ · macOS 12+ · tvOS 15+ · watchOS 8+ · Swift 5.9+

## Install

Swift Package Manager. In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/tiducto/spider-sdk-swift.git", from: "0.1.0"),
],
targets: [
    .target(name: "YourApp", dependencies: [.product(name: "SpiderSDK", package: "spider-sdk-swift")]),
]
```

Or in Xcode: **File ▸ Add Package Dependencies…** and paste the repo URL.

## Quickstart

```swift
import SpiderSDK

let client = SpiderClient(baseURL: "https://your-env-slug.api.tiducto.eu", apiKey: ProcessInfo.processInfo.environment["SPIDER_API_KEY"]!)

let result = try await client.routing.plan(PlanOptions(
    origin: .coordinate(49.19, 16.61),
    destination: .coordinate(49.23, 16.53),
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

Ordinary failures are values — every call returns a `SpiderResult<T>` you branch on. The one thrown error is `SpiderContractMismatchError`, raised when the gateway speaks a different **major** contract version than this SDK.

## What's in it

- **`client.routing`** — trip planning (with paging and a streaming `planUntil`), departures, and single-trip lookups.
- **`client.stops`** — text search, geo queries (nearest / bounding box), and lookup by GTFS id.
- **`client.realtime`** — poll-based live vehicle positions, delays, and alerts, plus change-detecting `poll…` streams (no push connections).

**Full API reference and guides → [docs.tiducto.eu](https://docs.tiducto.eu).** Product overview → [tiducto.eu](https://tiducto.eu).

## Contract & codegen

The wire models under `Sources/SpiderContract/` and the persisted-query ids are generated from the published contract by `scripts/generate-contract.sh` (via `tiducto/spider-codegen`) and committed — the package carries the types, not the spec. `client.contractVersion` reports the contract version this SDK speaks. Don't hand-edit generated files; re-run the script.

## License

Apache-2.0 — see [LICENSE](LICENSE).
