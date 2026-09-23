# Changelog

## Unreleased

### Added

- `SpiderClient.warmup()` — pre-warms the connection to the environment API host so the
  first real call rides an already-open TLS connection instead of paying the ~0.6s
  cold-connect cost. Issues one keyless `GET /ping` through the SDK's shared `URLSession`;
  best-effort (never throws), returns the measured elapsed seconds. Call at app start or
  on foreground, fire-and-forget.

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
