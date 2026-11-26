# Changelog

## [2.1.1](https://github.com/growthbook/growthbook-swift/compare/2.1.0...2.1.1) (2026-11-25)


### Bug Fixes

* keep cached saved groups and bandits in step with features; refetch remote eval on setter changes ([#209](https://github.com/growthbook/growthbook-swift/issues/209)) ([897986f](https://github.com/growthbook/growthbook-swift/commit/897986fa573dd8df377983f496b1edef81d4a43e))

## [2.1.0](https://github.com/growthbook/growthbook-swift/compare/2.0.2...2.1.0) (2026-11-18)


### Features

* add remote saved groups (savedGroupReferencesRemote) ([#201](https://github.com/growthbook/growthbook-swift/issues/201)) ([48faebf](https://github.com/growthbook/growthbook-swift/commit/48faebf9653862ef8952c2c7717418dd330975ea))
* resolve saved groups by reference through $savedGroup ([#199](https://github.com/growthbook/growthbook-swift/issues/199)) ([c161220](https://github.com/growthbook/growthbook-swift/commit/c161220b526ffaa31bc07287ca01e2b87cf4262d))


### Bug Fixes

* apply savedGroups from a preloaded payload ([#189](https://github.com/growthbook/growthbook-swift/issues/189)) ([45d290e](https://github.com/growthbook/growthbook-swift/commit/45d290e3951f6471077392a0cd2b7f34a0d8ea85))
* SSE reconnect exponential backoff and HTTP 200-only retry ([#171](https://github.com/growthbook/growthbook-swift/issues/171)) ([a3a6ee2](https://github.com/growthbook/growthbook-swift/commit/a3a6ee24b7c75a7b4c0b9e4cffad640e93d8373f))

## [2.0.2](https://github.com/growthbook/growthbook-swift/compare/2.0.1...2.0.2) (2026-11-12)


### Bug Fixes

* avoid quadratic regex when stripping version build metadata ([#204](https://github.com/growthbook/growthbook-swift/issues/204)) ([1fe3988](https://github.com/growthbook/growthbook-swift/commit/1fe39888453d3e2d983896053bc4f4f5ecf494b1))
