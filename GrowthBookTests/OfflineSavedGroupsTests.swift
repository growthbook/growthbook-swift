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

    // MARK: - Helper

    /// Encrypts `plainText` in the `iv.cipherText` base64 form the SDK expects.
    private func encrypt(_ plainText: String, key: String) throws -> String {
        let crypto = Crypto()
        let keyBytes = [UInt8](Data(base64Encoded: key)!)
        let iv = [UInt8]("0123456789abcdef".utf8)
        let cipher = try crypto.encrypt(key: keyBytes, iv: iv, plainText: [UInt8](plainText.utf8))
        return "\(Data(iv).base64EncodedString()).\(Data(cipher).base64EncodedString())"
    }
}
