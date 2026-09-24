# Changelog

## 0.1.2

### Added

- `SpiderClient.warmup()` — pre-warms the connection to the environment API host so the
  first real call rides an already-open TLS connection instead of paying the ~0.6s
  cold-connect cost. Issues one keyless `GET /ping` through the SDK's shared `URLSession`;
  best-effort (never throws), returns the measured elapsed seconds. Call at app start or
  on foreground, fire-and-forget.

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
