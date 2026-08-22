# Releasing

The Swift SDK ships via **Swift Package Manager** — there is no package registry. A
release is just a git tag on this public repo; consumers resolve it directly.

## Cut a release

1. Bump `version.properties` — the SDK version is `<contract>.<patch>` (`contract` tracks
   the API contract version; `patch` is for SDK-only fixes).
2. Run `scripts/stamp-version.sh` (and the contract-generation script if the contract
   changed) so `Sources/SpiderSDK/SDKVersion.swift` and `ContractVersion.swift` match.
3. Commit, then tag with the bare semver (no `v` prefix, to match the README's `from:`)
   and push:

   ```sh
   git tag 0.1.0
   git push origin 0.1.0
   ```

No account, no token, no registry. Consumers add:

```swift
.package(url: "https://github.com/tiducto/spider-sdk-swift.git", from: "0.1.0")
```
