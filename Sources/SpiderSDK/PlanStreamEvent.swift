import Foundation

/// One event from a plan stream (`SpiderRouting.planStream` / `planStreamNext` / `planStreamPrevious`). The
/// router sweeps the search window and pushes itineraries as they finalize: zero or more `result` events, then
/// a terminal `done` carrying the continuation cursors. A `failure` is terminal and takes the place of the
/// rest — it is never thrown, it is the last event the stream yields.
public enum PlanStreamEvent {
    /// A batch of finalized itineraries as the search frontier advances. Each `Itinerary`'s legs carry the
    /// scheduled times plus the realtime delay fields (`startEstimated` / `endEstimated` /
    /// `startDelaySeconds` / `endDelaySeconds` / `isRealtime` / `realtimeState`) — the same delay handling
    /// the one-shot `plan` applies.
    case result([Itinerary])

    /// Terminal: the continuation cursors, mirroring `Route.pageInfo`. Read `pageInfo.endCursor` (when
    /// `pageInfo.hasNextPage`) and continue with `planStreamNext(..., after:)`, or `pageInfo.startCursor`
    /// (when `pageInfo.hasPreviousPage`) and continue with `planStreamPrevious(..., before:)`.
    case done(RoutePageInfo)

    /// Terminal failure — a transport/HTTP problem, a decoding error, or a server `error` event (e.g. an
    /// invalid request). Carries the same `SpiderError` taxonomy the one-shot calls return.
    case failure(SpiderError)
}
