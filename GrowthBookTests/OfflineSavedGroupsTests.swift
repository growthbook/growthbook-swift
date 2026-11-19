import XCTest
@testable import GrowthBook

/// Covers `savedGroups` handling in offline mode — i.e. when a payload is supplied to the builder
/// via `features: Data` and no network or disk round-trip happens at init.
///
/// The payload's `savedGroups` must reach evaluation, otherwise every `$inGroup` / `$notInGroup`
/// condition resolves against an empty group. `$notInGroup` in particular then matches *every*
/// user, so a rule meant to exclude a group applies to everyone.
class OfflineSavedGroupsTests: XCTestCase {

    private let testApiHost = "https://host.com"

    /// A payload gating `my-feature` on the user being in the `vips` saved group.
    private func inGroupPayload() -> String {
        """
        {
          "features": {
            "my-feature": {
              "defaultValue": "off",
              "rules": [{
                "id": "rule-1",
                "condition": {"id": {"$inGroup": "vips"}},
                "force": "on"
              }]
            }
          },
          "savedGroups": {"vips": ["user-vip"]}
        }
        """
    }

    /// The same payload, but the rule fires for users *outside* the `vips` group.
    private func notInGroupPayload() -> String {
        """
        {
          "features": {
            "my-feature": {
              "defaultValue": "off",
              "rules": [{
                "id": "rule-1",
                "condition": {"id": {"$notInGroup": "vips"}},
                "force": "on"
              }]
            }
          },
          "savedGroups": {"vips": ["user-vip"]}
        }
        """
    }

    private func makeSDK(payload: String, userId: String, clientKey: String) -> GrowthBookSDK {
        GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: clientKey,
            attributes: ["id": userId],
            features: Data(payload.utf8),
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: nil, error: nil))
        .initializer()
    }

    // MARK: - $inGroup

    func testInGroupMatchesMemberInOfflineMode() {
        let manager = CachingManager(apiKey: "offline-sg-in-member")
        manager.clearCache()

        let sdk = makeSDK(payload: inGroupPayload(), userId: "user-vip", clientKey: "offline-sg-in-member")

        XCTAssertEqual(sdk.evalFeature(id: "my-feature").value?.stringValue, "on",
                       "A user in the saved group must match $inGroup")
        manager.clearCache()
    }

    func testInGroupDoesNotMatchNonMemberInOfflineMode() {
        let manager = CachingManager(apiKey: "offline-sg-in-other")
        manager.clearCache()

        let sdk = makeSDK(payload: inGroupPayload(), userId: "user-plain", clientKey: "offline-sg-in-other")

        XCTAssertEqual(sdk.evalFeature(id: "my-feature").value?.stringValue, "off")
        manager.clearCache()
    }

    // MARK: - $notInGroup (the fail-open case)

    func testNotInGroupDoesNotMatchMemberInOfflineMode() {
        let manager = CachingManager(apiKey: "offline-sg-notin-member")
        manager.clearCache()

        let sdk = makeSDK(payload: notInGroupPayload(), userId: "user-vip", clientKey: "offline-sg-notin-member")

        // Without the payload's savedGroups the group is empty, so $notInGroup matches everyone and
        // this returns "on" — the rule fires for exactly the user it was meant to exclude.
        XCTAssertEqual(sdk.evalFeature(id: "my-feature").value?.stringValue, "off",
                       "$notInGroup must not match a user who IS in the saved group")
        manager.clearCache()
    }

    func testNotInGroupMatchesNonMemberInOfflineMode() {
        let manager = CachingManager(apiKey: "offline-sg-notin-other")
        manager.clearCache()

        let sdk = makeSDK(payload: notInGroupPayload(), userId: "user-plain", clientKey: "offline-sg-notin-other")

        XCTAssertEqual(sdk.evalFeature(id: "my-feature").value?.stringValue, "on")
        manager.clearCache()
    }

    // MARK: - Exposure through the public context

    func testSavedGroupsFromPreloadedPayloadAreExposedOnContext() {
        let manager = CachingManager(apiKey: "offline-sg-context")
        manager.clearCache()

        let sdk = makeSDK(payload: inGroupPayload(), userId: "user-vip", clientKey: "offline-sg-context")

        XCTAssertEqual(sdk.getGBContext().savedGroups?["vips"].arrayValue.first?.stringValue, "user-vip")
        manager.clearCache()
    }

    // MARK: - Encrypted payloads

    func testEncryptedSavedGroupsFromPreloadedPayloadAreApplied() throws {
        let manager = CachingManager(apiKey: "offline-sg-encrypted")
        manager.clearCache()

        let encryptionKey = "Zvwv/+uhpFDznZ6SX28Yjg=="
        let features = """
        {"my-feature":{"defaultValue":"off","rules":[{"id":"rule-1","condition":{"id":{"$inGroup":"vips"}},"force":"on"}]}}
        """
        let savedGroups = #"{"vips":["user-vip"]}"#

        let payload = """
        {
          "encryptedFeatures": "\(try encrypt(features, key: encryptionKey))",
          "encryptedSavedGroups": "\(try encrypt(savedGroups, key: encryptionKey))"
        }
        """

        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: "offline-sg-encrypted",
            encryptionKey: encryptionKey,
            attributes: ["id": "user-vip"],
            features: Data(payload.utf8),
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: nil, error: nil))
        .initializer()

        XCTAssertEqual(sdk.evalFeature(id: "my-feature").value?.stringValue, "on",
                       "encryptedSavedGroups from a preloaded payload must be decrypted and applied")
        manager.clearCache()
    }

    // MARK: - No savedGroups in payload

    func testPayloadWithoutSavedGroupsLeavesThemNil() {
        let manager = CachingManager(apiKey: "offline-sg-absent")
        manager.clearCache()

        let payload = """
        {"features":{"my-feature":{"defaultValue":"off"}}}
        """
        let sdk = makeSDK(payload: payload, userId: "user-1", clientKey: "offline-sg-absent")

        XCTAssertNil(sdk.getGBContext().savedGroups)
        XCTAssertEqual(sdk.evalFeature(id: "my-feature").value?.stringValue, "off")
        manager.clearCache()
    }

    /// An encrypted API payload also carries an empty `features` object; the encrypted features win.
    func testEncryptedPayloadWithEmptyFeaturesObjectIsApplied() throws {
        let clientKey = "offline-sg-encrypted-api-shape"
        let manager = CachingManager(apiKey: clientKey)
        manager.clearCache()
        defer { manager.clearCache() }

        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: clientKey,
            encryptionKey: encryptionKey,
            attributes: ["id": "user-vip"],
            features: Data(try encryptedPayload(includeEmptyFeatures: true).utf8),
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: nil, error: nil))
        .initializer()

        XCTAssertEqual(sdk.evalFeature(id: "my-feature").value?.stringValue, "on")
    }

    // MARK: - Cold start from the cache a preloaded payload wrote

    /// A later launch without the payload reads the features from cache, and must get the saved
    /// groups with them; otherwise `$notInGroup` matches the member it should exclude.
    func testColdStartFromCacheKeepsPreloadedSavedGroups() {
        let clientKey = "offline-sg-cold-start"
        let manager = CachingManager(apiKey: clientKey)
        manager.clearCache()
        defer { manager.clearCache() }

        _ = makeSDK(payload: notInGroupPayload(), userId: "user-vip", clientKey: clientKey)
        let coldStart = makeCachedSDK(clientKey: clientKey, encryptionKey: nil)

        XCTAssertEqual(coldStart.evalFeature(id: "my-feature").value?.stringValue, "off",
                       "$notInGroup must not match a member after a cold start from cache")
    }

    func testColdStartFromCacheKeepsEncryptedPreloadedSavedGroups() throws {
        let clientKey = "offline-sg-cold-start-encrypted"
        let manager = CachingManager(apiKey: clientKey)
        manager.clearCache()
        defer { manager.clearCache() }

        _ = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: clientKey,
            encryptionKey: encryptionKey,
            attributes: ["id": "user-vip"],
            features: Data(try encryptedPayload(includeEmptyFeatures: true).utf8),
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: nil, error: nil))
        .initializer()
        let coldStart = makeCachedSDK(clientKey: clientKey, encryptionKey: encryptionKey)

        XCTAssertEqual(coldStart.evalFeature(id: "my-feature").value?.stringValue, "on",
                       "the encrypted saved groups must be cached in the form the cache is read back in")
    }

    // MARK: - stableSession

    /// Under stableSession a refresh must not replace the session's saved groups any more than
    /// its features; otherwise a member is re-targeted mid-session.
    func testStableSessionKeepsPreloadedSavedGroupsOnRefresh() {
        let clientKey = "offline-sg-stable-refresh"
        let manager = CachingManager(apiKey: clientKey)
        manager.clearCache()
        defer { manager.clearCache() }

        // The refreshed payload drops user-vip from the group
        let refreshed = notInGroupPayload().replacingOccurrences(of: #"["user-vip"]"#, with: #"["someone-else"]"#)
        let refreshedExpectation = expectation(description: "refresh")
        refreshedExpectation.assertForOverFulfill = false
        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: clientKey,
            attributes: ["id": "user-vip"],
            features: Data(notInGroupPayload().utf8),
            trackingCallback: { _, _ in },
            backgroundSync: false,
            ttlSeconds: 0
        )
        .setStableSession(true)
        .setRefreshHandler(refreshHandler: { _ in refreshedExpectation.fulfill() })
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: refreshed, error: nil))
        .initializer()
        XCTAssertEqual(sdk.evalFeature(id: "my-feature").value?.stringValue, "off")

        sdk.refreshCache()
        wait(for: [refreshedExpectation], timeout: 5)

        XCTAssertEqual(sdk.evalFeature(id: "my-feature").value?.stringValue, "off",
                       "the session's saved groups must not change on refresh")
    }

    /// Without a preload, the first network payload establishes the session: its saved groups
    /// arrive after its features and must still be applied.
    func testStableSessionAppliesSavedGroupsFromTheFirstNetworkPayload() {
        let clientKey = "offline-sg-stable-first-fetch"
        let manager = CachingManager(apiKey: clientKey)
        manager.clearCache()
        defer { manager.clearCache() }

        let loaded = expectation(description: "first fetch")
        loaded.assertForOverFulfill = false
        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: clientKey,
            attributes: ["id": "user-vip"],
            trackingCallback: { _, _ in },
            refreshHandler: nil,
            backgroundSync: false
        )
        .setStableSession(true)
        .setRefreshHandler(refreshHandler: { _ in loaded.fulfill() })
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: inGroupPayload(), error: nil))
        .initializer()
        wait(for: [loaded], timeout: 5)

        XCTAssertEqual(sdk.evalFeature(id: "my-feature").value?.stringValue, "on")
    }

    /// A preloaded payload whose features don't load leaves the session to the first fetch, which
    /// must apply its own saved groups rather than keep the preload's.
    func testStableSessionPreloadWithoutFeaturesTakesGroupsFromTheFirstFetch() {
        let clientKey = "offline-sg-stable-no-features"
        let manager = CachingManager(apiKey: clientKey)
        manager.clearCache()
        defer { manager.clearCache() }

        // Empty features are invalid under stableSession, so the SDK falls back to the network
        let preload = #"{"features":{},"savedGroups":{"vips":["someone-else"]}}"#
        let loaded = expectation(description: "first fetch")
        loaded.assertForOverFulfill = false
        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: clientKey,
            attributes: ["id": "user-vip"],
            features: Data(preload.utf8),
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setStableSession(true)
        .setRefreshHandler(refreshHandler: { _ in loaded.fulfill() })
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: inGroupPayload(), error: nil))
        .initializer()
        wait(for: [loaded], timeout: 5)

        XCTAssertEqual(sdk.evalFeature(id: "my-feature").value?.stringValue, "on")
    }

    /// Cached saved groups without readable cached features must not lock the session: the first
    /// fetch's features and groups belong together.
    func testStableSessionCachedGroupsWithoutFeaturesDoNotLockTheSession() throws {
        let clientKey = "offline-sg-stable-groups-only-cache"
        let manager = CachingManager(apiKey: clientKey)
        manager.clearCache()
        defer { manager.clearCache() }
        manager.saveContent(fileName: Constants.savedGroupsCache, content: Data(#"{"vips":["someone-else"]}"#.utf8))

        let loaded = expectation(description: "first fetch")
        loaded.assertForOverFulfill = false
        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: clientKey,
            attributes: ["id": "user-vip"],
            trackingCallback: { _, _ in },
            refreshHandler: nil,
            backgroundSync: false
        )
        .setStableSession(true)
        .setRefreshHandler(refreshHandler: { _ in loaded.fulfill() })
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: inGroupPayload(), error: nil))
        .initializer()
        wait(for: [loaded], timeout: 5)

        XCTAssertEqual(sdk.evalFeature(id: "my-feature").value?.stringValue, "on")
    }

    // MARK: - Helper

    private let encryptionKey = "Zvwv/+uhpFDznZ6SX28Yjg=="

    /// `$inGroup: vips` with `user-vip` in the group, as encrypted features and saved groups.
    private func encryptedPayload(includeEmptyFeatures: Bool) throws -> String {
        let features = #"{"my-feature":{"defaultValue":"off","rules":[{"id":"rule-1","condition":{"id":{"$inGroup":"vips"}},"force":"on"}]}}"#
        let savedGroups = #"{"vips":["user-vip"]}"#
        return """
        {
          \(includeEmptyFeatures ? #""features": {},"# : "")
          "encryptedFeatures": "\(try encrypt(features, key: encryptionKey))",
          "encryptedSavedGroups": "\(try encrypt(savedGroups, key: encryptionKey))"
        }
        """
    }

    /// An SDK with no payload and no network, so it starts from what the cache holds.
    private func makeCachedSDK(clientKey: String, encryptionKey: String?) -> GrowthBookSDK {
        let loaded = expectation(description: "cache loaded")
        loaded.assertForOverFulfill = false
        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: clientKey,
            encryptionKey: encryptionKey,
            attributes: ["id": "user-vip"],
            trackingCallback: { _, _ in },
            refreshHandler: nil,
            backgroundSync: false
        )
        .setRefreshHandler(refreshHandler: { _ in loaded.fulfill() })
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: nil, error: SDKError.failedToLoadData))
        .initializer()
        wait(for: [loaded], timeout: 5)
        return sdk
    }

    /// Encrypts `plainText` in the `iv.cipherText` base64 form the SDK expects.
    private func encrypt(_ plainText: String, key: String) throws -> String {
        let crypto = Crypto()
        let keyBytes = [UInt8](Data(base64Encoded: key)!)
        let iv = [UInt8]("0123456789abcdef".utf8)
        let cipher = try crypto.encrypt(key: keyBytes, iv: iv, plainText: [UInt8](plainText.utf8))
        return "\(Data(iv).base64EncodedString()).\(Data(cipher).base64EncodedString())"
    }
}
