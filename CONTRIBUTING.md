# Contributing Guide

We welcome all contributions!

This repo is the official GrowthBook SDK for Swift — a client library for
evaluating feature flags and running experiments on Apple platforms.

## Requirements

- **Xcode** with the command line tools. Xcode itself must be the selected
  developer directory, not the standalone Command Line Tools:

  ```sh
  xcode-select -p   # must print a path inside Xcode.app
  ```

  If it prints `/Library/Developer/CommandLineTools`, point it at Xcode —
  CLT alone ships no XCTest, and `swift test` fails with
  `no such module 'XCTest'`:

  ```sh
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ```

  After a major Xcode upgrade you may also need to accept the new license and
  install the additional components, both of which need a real terminal:

  ```sh
  sudo xcodebuild -license accept
  sudo xcodebuild -runFirstLaunch
  ```

- **Swift 5.9+**, as declared by `swift-tools-version` in `Package.swift`.

Running `./Scripts/runTest.sh` or `./Scripts/build.sh` locally additionally
needs the Xcode version CI selects, which is pinned in
`.github/workflows/` — see [Testing](#testing). Day-to-day work doesn't
need it.

There are no third-party dependencies. `Package.swift` declares none, there is
no lockfile, and nothing is generated or vendored except the conformance
fixtures.

## Getting started

Fork the repo, or clone directly if you have write access:

```sh
git clone git@github.com:growthbook/growthbook-swift.git
cd growthbook-swift
swift build
swift test
```

That's the whole setup. Get a green baseline before you start writing code —
the suite runs in a few seconds on macOS.

The package also builds as an Xcode project (`GrowthBook-IOS.xcodeproj`, scheme
`GrowthBook`) if you'd rather work there. Both harnesses compile the same
sources and run the same tests.

## Writing code

### Layout

| Path | Contents |
| --- | --- |
| `Sources/CommonMain/Evaluators/` | Feature, experiment and condition evaluation — the core |
| `Sources/CommonMain/Features/` | Feature loading and the view model that drives refreshes |
| `Sources/CommonMain/Network/` | HTTP and the SSE streaming connection |
| `Sources/CommonMain/Caching/` | Payload and ETag caching |
| `Sources/CommonMain/StickyBucket/` | Sticky bucket assignment storage |
| `Sources/CommonMain/Plugins/` | Tracking plugins and `SDKVersion.swift` |
| `Sources/CommonMain/Model/` | Payload and configuration types |
| `Sources/CommonMain/JsonManager/` | The vendored dynamic `JSON` value type used during evaluation |
| `Sources/CommonMain/Utils/` | Hashing, bucketing, version comparison, crypto |
| `GrowthBookTests/` | Tests, flat, one file per area |
| `GrowthBookTests/Source/` | Conformance fixtures — see [Conformance corpus](#conformance-corpus) |
| `GrowthBook/GrowthBook.h` | Umbrella header for the framework target |
| `Scripts/` | The CI test and xcframework build scripts |

`Sources/CommonMain` is the single SPM target — the `CommonMain` name is
historical, not a hint that other targets exist.

### Public API

Anything `public` is consumed by apps via SwiftPM, CocoaPods, or the prebuilt
xcframework, so removing or changing a `public` symbol is a breaking change and
needs an issue first. Adding is cheap. Prefer `internal` unless a caller
genuinely needs the symbol — note that tests use `@testable import GrowthBook`,
so `internal` is still fully testable and is not a reason to widen access.

### SDK parity

GrowthBook's SDKs must make identical decisions given identical inputs, and the
[JavaScript SDK](https://github.com/growthbook/growthbook/tree/main/packages/sdk-js)
is the reference implementation. Match it.

When you touch evaluation, read the corresponding JS source rather than
reasoning from the Swift alone — most bugs found here have been small
divergences from it, not logic errors in isolation. If you deliberately
diverge, say so explicitly in the PR. Silent divergence is the thing to avoid.

### Platform support

`Package.swift` declares macOS 10.15+, iOS 12+, tvOS 12+, watchOS 5+ and
visionOS 1+. Anything newer needs an `@available` guard or a runtime check.
`swift test` only exercises macOS, so an API that is unavailable on watchOS
will compile clean locally and fail in CI — check the availability of any
Foundation or system API you reach for.

## Testing

```sh
swift test                              # everything, on macOS
swift test --filter UtilsTests          # one suite
swift test --filter testPaddedVersion   # one test
swift test -c release                   # release build, for timing work
```

`swift test` on macOS is the fast loop and is what you want while developing.
It runs the same test code CI does.

`./Scripts/runTest.sh` is what CI runs: the same suite across iOS, tvOS,
watchOS and visionOS simulators. It hard-codes its simulator destinations by
device name, and CI selects the Xcode version that provides them.

On a newer Xcode those device names may no longer exist, and the script fails
before running any tests. If that happens, treat it as the script having
drifted behind the current toolchain rather than a problem with your setup —
the pinned destinations, and the Xcode version CI selects, need updating
together. Please open an issue or a PR for it.

Meanwhile `swift test` runs the same test code on macOS, and CI covers the
other platforms, so day-to-day work isn't blocked.

Add tests with your change: a bug fix should come with a test that fails before
it and passes after.

### Conformance corpus

`GrowthBookTests/Source/json.json` is the shared cross-SDK corpus, mirrored from
the [JS SDK](https://github.com/growthbook/growthbook/blob/main/packages/sdk-js/test/cases.json).
It's how every GrowthBook SDK proves it evaluates features, conditions, hashing
and bucketing identically. **If a corpus case fails, assume your change is
wrong, not the corpus.**

Two conventions matter here:

- **`json.json` is a verbatim copy of upstream.** Don't edit it. Syncing is a
  whole-file swap, which is what keeps the diff reviewable and makes an
  accidental drop obvious.
- **Cases this SDK keeps that upstream doesn't carry live in
  `local-cases.json`.** They're loaded separately and merged at test time. They
  are in their own file precisely so a corpus swap cannot silently delete
  them — an earlier 0.8.0 sync did exactly that.

If you fix a parity bug, the durable fix is a case added *upstream* in
`growthbook/growthbook`, not one added here — otherwise the other SDKs keep the
bug and nothing stops this one regressing. Use `local-cases.json` only for
behavior genuinely specific to this SDK.

Fixtures are resolved from both `Bundle.module` (SwiftPM) and
`Bundle(for:)` (Xcode), and a miss fails loudly. That is deliberate: resolving
only through `Bundle(for:)` once made every fixture-driven suite return early
and report success while evaluating nothing. If you add a fixture, load it
through `TestHelper` rather than reaching for a bundle directly.

## Code quality

There is no linter or formatter configured — no SwiftLint, no swift-format, and
no CI style gate. Match the surrounding code: the existing style is 4-space
indentation, `camelCase`, and doc comments (`///`) on non-obvious declarations
explaining *why* rather than restating the signature.

Keep the diff focused. Send unrelated refactors and reformatting separately.

## Opening pull requests

Open an issue first for API changes, new configuration, or behavior changes —
cheaper than discovering at review time that the design needs to change. For a
typo or an obvious fix, just open the PR. There are no issue or PR templates.

1. Branch from `main`. Naming is loose; existing branches use `fix/thing`,
   `feat/thing`, and `yourname/thing`.
2. Check your work before pushing:
   ```sh
   swift build
   swift test
   ```
3. Commit. Subjects follow conventional-commit prefixes (`fix:`, `feat:`,
   `test:`) though nothing enforces it.
4. Open the PR against `main`. Describe what changed and how to verify it, and
   call out parity implications explicitly — especially any change to which
   users a targeting rule matches, since that silently changes live audiences
   on upgrade.

CI (`.github/workflows/pullRequest.yml`) selects a pinned Xcode version, runs
`./Scripts/runTest.sh` across the four simulator platforms, then builds the
xcframework with `./Scripts/build.sh`. The most common failure is a test that
passes on macOS but hits an API unavailable on watchOS or tvOS.

Push follow-up commits rather than force-pushing where you can; it keeps review
comments anchored to the code they were written about.

## Releasing

Maintainers handle releases, and they are fully automatic — there is no manual
step and no version to edit by hand.

Merging to `main` triggers `.github/workflows/main.yml`, which:

1. computes the version with [GitVersion](https://gitversion.net/) using
   `.github/gitversion.yml`,
2. writes it into `Sources/CommonMain/Plugins/SDKVersion.swift` at build time,
3. runs the tests and builds the xcframework,
4. creates the GitHub release and tag, and uploads `GrowthBook.xcframework.zip`.

`.github/workflows/deploy.yml` then runs `pod trunk push` to publish to
CocoaPods. SwiftPM needs nothing further — it consumes the git tag directly.

> The `gbSdkVersion` value checked into `SDKVersion.swift` is stale by design.
> CI rewrites it during the release build and never commits it back, so the
> value in the repo does not track the released version. Don't "fix" it.

### Choosing the version bump

`gitversion.yml` uses `mode: Mainline`, so **every merge to `main` bumps the
patch version** unless the commit message says otherwise. To cut a minor or
major release, include a marker in the merge commit message:

```
+semver: minor
+semver: major
```

For example, `1.2.0` came from a merge titled
`Merge pull request #176 … +semver: minor`.

This is easy to miss, and it is not recoverable after the fact — once CI
tags and publishes to CocoaPods, that version is taken. If a change alters
which users a rule matches, decide on the bump *before* merging.

## Getting help

- [Slack community](https://slack.growthbook.io?ref=contributing) — we're happy
  to help you get set up
- [Open an issue](https://github.com/growthbook/growthbook-swift/issues)
- [Swift SDK docs](https://docs.growthbook.io/lib/swift)

Found a security vulnerability? Email security@growthbook.io — **don't file a
public issue**. See the [security
policy](https://github.com/growthbook/growthbook/blob/main/SECURITY.md).

Contributors are expected to follow the [Code of
Conduct](https://github.com/growthbook/growthbook/blob/main/CODE_OF_CONDUCT.md).
