import Foundation

// Identity headers sent on every request. `apikey` carries the raw key; the two telemetry headers let the
// gateway track contract/SDK adoption and deprecation. `x-spider-sdk` is `<lang>/<semver>`.
let CONTRACT_HEADER = "x-spider-contract-version"
let SDK_HEADER = "x-spider-sdk"
let SDK_IDENTITY = "swift/" + SDK_VERSION

// The major component of a "major.minor" version string ("5.0" -> "5").
func spiderMajor(_ version: String) -> String {
    if let dot = version.firstIndex(of: ".") { return String(version[..<dot]) }
    return version
}

// Compares only the MAJOR contract component against the version the gateway declared on the response.
// A missing/empty header is a no-op (tolerate older gateways). A major mismatch throws
// SpiderContractMismatchError, deliberately escaping the SpiderResult channel so it is a hard, visible failure.
func checkContract(_ declaredByGateway: String?) throws {
    guard let declared = declaredByGateway, !declared.isEmpty else { return }
    if spiderMajor(CONTRACT_VERSION) != spiderMajor(declared) {
        throw SpiderContractMismatchError(expected: CONTRACT_VERSION, actual: declared)
    }
}
