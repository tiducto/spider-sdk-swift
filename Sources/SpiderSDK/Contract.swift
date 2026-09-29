import Foundation

// Identity headers sent on every request. `apikey` carries the raw key; the two telemetry headers let the
// gateway track contract/SDK adoption and deprecation. `x-spider-sdk` is `<lang>/<semver>`.
let CONTRACT_HEADER = "x-spider-contract-version"
let SDK_HEADER = "x-spider-sdk"
let SDK_IDENTITY = "swift/" + SDK_VERSION
