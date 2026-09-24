// Generated from the published contract's x-persisted-query-id by scripts/generate-contract.sh. Do not edit.
//
// The gateway enforces a persisted-query allowlist: clients POST { id, variables } and the id is the
// lowercase-hex SHA-256 of the canonical query text. An id the gateway has not registered is rejected 403,
// so these must never drift from the published contract — they are generated, never hand-typed.

struct PersistedOp {
    let id: String
    let path: String
}

enum PersistedQueries {
    static let departures = PersistedOp(id: "70a644fe3c6b2cbf5b2d70cef8230c1428bea6357ae1766772162d86469563d0", path: "departures")
    static let plan = PersistedOp(id: "06004d101213f2d6abbbde9e7ed3fd239af47352168d5fd47ece8c46cab67618", path: "plan")
    static let planstream = PersistedOp(id: "7f82dbee066bcb53a1ddfe83254abb396c408c5ce95a151ac743c656789aef4b", path: "plan-stream")
    static let trip = PersistedOp(id: "e8959a8d47a8e8437ee3ec740cd9c3e28bd401efdd236dde0502559daea53920", path: "trip")
}
