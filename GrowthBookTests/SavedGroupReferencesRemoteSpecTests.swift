import XCTest

@testable import GrowthBook

/// Runs the `savedGroupReferencesRemote` section of the vendored conformance suite
/// (growthbook/growthbook#7277): saved groups whose members live outside the payload, resolved by
/// the app into the user's remote group ids.
///
/// The `feature` cases run through a real `GrowthBookSDK`, not the evaluator alone, because their
/// point is how `remoteGroupIds` on the context reaches evaluation.
class SavedGroupReferencesRemoteSpecTests: XCTestCase {

    // MARK: - evalCondition

    func testEvalConditionSpec() {
        let cases = section(TestHelper().getSavedGroupReferencesRemoteData("evalCondition"), "evalCondition")
        var failures: [String] = []

        for testCase in cases {
            let name = testCase[0].stringValue
            let expected = testCase[3].boolValue
            let savedGroups: JSON? = testCase.arrayValue.count > 4 ? testCase[4] : nil

            let actual = ConditionEvaluator().isEvalCondition(
                attributes: testCase[2],
                conditionObj: testCase[1],
                savedGroups: savedGroups
            )

            if actual != expected {
                failures.append("• \(name)\n    expected \(expected), got \(actual)")
            }
        }

        report(failures, of: cases.count, section: "evalCondition")
    }

    // MARK: - feature

    func testFeatureSpec() {
        let cases = section(TestHelper().getSavedGroupReferencesRemoteData("feature"), "feature")
        var failures: [String] = []

        for testCase in cases {
            let name = testCase[0].stringValue
            let context = testCase[1]
            let expected = FeatureResultTest(json: testCase[3].dictionaryValue)

            let sdk = makeSDK(
                features: context["features"],
                savedGroups: context["savedGroups"],
                attributes: context["attributes"],
                remoteGroupIds: context["remoteGroupIds"].array?.map(\.stringValue)
            )
            let result = sdk.evalFeature(id: testCase[2].stringValue)

            var mismatches: [String] = []
            check("value", result.value, expected.value, into: &mismatches)
            check("on", result.isOn, expected.isOn, into: &mismatches)
            check("off", result.isOff, expected.isOff, into: &mismatches)
            check("source", result.source, expected.source, into: &mismatches)
            check("ruleId", result.ruleId, expected.ruleId, into: &mismatches)

            if !mismatches.isEmpty {
                failures.append("• \(name)\n    " + mismatches.joined(separator: "\n    "))
            }
        }

        report(failures, of: cases.count, section: "feature")
    }

    // MARK: - setRemoteGroupIds

    func testSetRemoteGroupIdsChangesEvaluationAtRuntime() {
        let sdk = makeSDK(
            features: Self.features,
            savedGroups: Self.savedGroups,
            attributes: JSON(["account_id": "a1"]),
            remoteGroupIds: nil
        )

        XCTAssertFalse(sdk.isOn(feature: "flag"), "unresolved groups match nobody")
        XCTAssertFalse(sdk.isOn(feature: "excluded"), "unresolved groups fail \"not in group\" too")

        sdk.setRemoteGroupIds(["grp_vip"])
        XCTAssertTrue(sdk.isOn(feature: "flag"))
        XCTAssertFalse(sdk.isOn(feature: "excluded"))
        XCTAssertEqual(sdk.getRemoteGroupIds(), ["grp_vip"])

        // An empty array means "in no group", which is what lets "not in group" match
        sdk.setRemoteGroupIds([])
        XCTAssertFalse(sdk.isOn(feature: "flag"))
        XCTAssertTrue(sdk.isOn(feature: "excluded"))

        sdk.setRemoteGroupIds(nil)
        XCTAssertFalse(sdk.isOn(feature: "flag"))
        XCTAssertFalse(sdk.isOn(feature: "excluded"))
    }

    func testRemoteEvalSendsTheRemoteGroupIds() {
        let client = CapturingPostClient(successResponse: MockResponse().successResponse, error: nil as Error?)
        let posted = expectation(description: "remote-eval POST with remote group ids")
        client.onPost = { params in
            let attributes = params["attributes"] as? [String: Any]
            if attributes?[Constants.remoteGroupIdsAttribute] as? [String] == ["grp_vip"] {
                XCTAssertEqual(attributes?["account_id"] as? String, "a1")
                posted.fulfill()
            }
        }
        let sdk = GrowthBookBuilder(
            apiHost: "https://host.com",
            clientKey: "sdk-remote-groups",
            attributes: ["account_id": "a1"],
            trackingCallback: { _, _ in },
            backgroundSync: false,
            remoteEval: true,
            // fetchFeatures skips the request while the cache is fresh, and the initial remote-eval
            // fetch would otherwise make it fresh before setRemoteGroupIds refreshes
            ttlSeconds: 0
        )
        .setNetworkDispatcher(networkDispatcher: client)
        .initializer()

        sdk.setRemoteGroupIds(["grp_vip"])

        wait(for: [posted], timeout: 5)
    }

    /// The flag is cached on `savedGroups` changes, so every read doesn't rescan the payload
    func testHasRemoteSavedGroupsFollowsSavedGroupsChanges() {
        let data = EvaluationData(streamingHost: nil, attributes: JSON([:]), forcedVariations: nil,
                                  savedGroups: Self.savedGroups)
        XCTAssertTrue(data.hasRemoteSavedGroups, "set from init")

        data.savedGroups = JSON(["admins": ["type": "list", "attributeKey": "id", "values": ["u_1"]]])
        XCTAssertFalse(data.hasRemoteSavedGroups)

        data.savedGroups = Self.savedGroups
        XCTAssertTrue(data.hasRemoteSavedGroups)

        data.savedGroups = nil
        XCTAssertFalse(data.hasRemoteSavedGroups)
    }

    func testInGroupOnARemoteEntryIsUndecided() {
        let savedGroups = JSON(["grp_vip": ["type": "remote", "attributeKey": "account_id"]])
        let attributes = JSON(["account_id": "a1", "__gb_remoteGroupIds": ["grp_vip"]])
        let evaluator = ConditionEvaluator()

        // $inGroup takes values from the payload, and a remote entry has none: undecided, so it fails,
        // and fails under $not as well
        let inGroup = JSON(["account_id": ["$inGroup": "grp_vip"]])
        XCTAssertNil(evaluator.evalCondition(attributes: attributes, conditionObj: inGroup, savedGroups: savedGroups))
        XCTAssertFalse(evaluator.isEvalCondition(attributes: attributes, conditionObj: JSON(["$not": inGroup.object]), savedGroups: savedGroups))
    }

    // MARK: - Helpers

    // "flag" is on for members of grp_vip; "excluded" is on for resolved non-members, with the
    // $exists guard GrowthBook adds to "not in group" rules
    private static let savedGroups = JSON(["grp_vip": ["type": "remote", "attributeKey": "account_id"]])
    private static let features = JSON(parseJSON: #"""
    {
      "flag": {"defaultValue": false, "rules": [
        {"condition": {"$savedGroup": {"id": "grp_vip"}}, "force": true}
      ]},
      "excluded": {"defaultValue": false, "rules": [
        {"condition": {
          "$not": {"$savedGroup": {"id": "grp_vip"}},
          "__gb_remoteGroupIds": {"$exists": true}
        }, "force": true}
      ]}
    }
    """#)

    private func makeSDK(features: JSON, savedGroups: JSON, attributes: JSON, remoteGroupIds: [String]?) -> GrowthBookSDK {
        let payload = try! JSON(["features": features.object]).rawData()
        let builder = GrowthBookBuilder(
            features: payload,
            attributes: attributes.dictionaryObject ?? [:],
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: nil, error: nil as Error?))
        if let remoteGroupIds {
            _ = builder.setRemoteGroupIds(remoteGroupIds)
        }
        let sdk = builder.initializer()
        // A preloaded payload doesn't seed saved groups; this is the path a fetched payload takes
        if savedGroups.exists() {
            sdk.savedGroupsFetchedSuccessfully(savedGroups: savedGroups, isRemote: false)
        }
        return sdk
    }

    private func section(_ cases: [JSON]?, _ name: String) -> [JSON] {
        guard let cases, !cases.isEmpty else {
            XCTFail("savedGroupReferencesRemote.\(name) is missing from the conformance fixtures")
            return []
        }
        return cases
    }

    private func check<T: Equatable>(_ field: String, _ actual: T?, _ expected: T?, into mismatches: inout [String]) {
        if actual != expected {
            mismatches.append("\(field): expected \(expected.map { "\($0)" } ?? "nil"), got \(actual.map { "\($0)" } ?? "nil")")
        }
    }

    private func report(_ failures: [String], of total: Int, section: String) {
        if !failures.isEmpty {
            XCTFail("\(failures.count) of \(total) savedGroupReferencesRemote.\(section) cases failed:\n"
                    + failures.joined(separator: "\n"))
        }
    }
}

/// Records each remote-eval POST body, then answers like `MockNetworkClient`.
private class CapturingPostClient: MockNetworkClient {
    var onPost: (([String: Any]) -> Void)?

    override func consumePOSTRequest(url: String, params: [String: Any], successResult: @escaping (Data) -> Void, errorResult: @escaping (any Error) -> Void) {
        onPost?(params)
        super.consumePOSTRequest(url: url, params: params, successResult: successResult, errorResult: errorResult)
    }
}
