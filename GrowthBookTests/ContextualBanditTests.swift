import XCTest
@testable import GrowthBook

/// Covers consumption of the contextual bandit payload: leaf selection by condition, weight
/// application before bucketing, fallback behaviour, and enrichment of the experiment result.
///
/// All weight recomputation happens on the GrowthBook backend — the SDK only picks the matching
/// leaf and applies its ready weights, so these tests assert selection and application, not any
/// optimisation behaviour.
class ContextualBanditTests: XCTestCase {

    // MARK: - Helpers

    private func makeContext(
        features: Features = [:],
        attributes: JSON = JSON(["id": "user-1"]),
        contextualBandits: JSON? = nil,
        savedGroups: JSON? = nil,
        forcedVariations: JSON? = nil,
        isQaMode: Bool = false
    ) -> EvalContext {
        let globalContext = GlobalContext(
            features: features,
            savedGroups: savedGroups,
            contextualBandits: contextualBandits
        )
        let userContext = UserContext(attributes: attributes, forcedVariations: forcedVariations)
        let options = ClientOptions(isEnabled: true, stickyBucketService: nil, isQaMode: isQaMode, trackingClosure: { _, _ in })
        return EvalContext(globalContext: globalContext, userContext: userContext, stackContext: StackContext(), options: options)
    }

    private func makeFeature(_ raw: [String: Any]) -> Feature {
        Feature(json: JSON(raw).dictionaryValue)
    }

    private func evaluate(_ featureKey: String, in context: EvalContext) -> FeatureResult {
        FeatureEvaluator(context: context, featureKey: featureKey).evaluateFeature()
    }

    /// A rule whose variations live under `contextualVariations` and which points at `bandit-1`.
    /// `weights` on the rule act as the aggregate fallback when no leaf matches.
    private func banditRule(ref: String? = "bandit-1", weights: [Float]? = nil) -> [String: Any] {
        var rule: [String: Any] = [
            "id": "rule-1",
            "key": "my-experiment",
            "contextualVariations": ["control", "treatment"]
        ]
        if let ref { rule["contextualBanditRef"] = ref }
        if let weights { rule["weights"] = weights }
        return rule
    }

    /// A bandit definition with two leaves: leaf 1 targets US, leaf 2 targets CA.
    /// Leaf 1's weights force variation 0, leaf 2's force variation 1.
    private func twoLeafBandits(banditVersion: Int = 7) -> JSON {
        JSON([
            "bandit-1": [
                "banditVersion": banditVersion,
                "contexts": [
                    ["leafId": 1, "condition": ["country": "US"], "weights": [1.0, 0.0]],
                    ["leafId": 2, "condition": ["country": "CA"], "weights": [0.0, 1.0]]
                ]
            ]
        ])
    }

    // MARK: - Leaf selection

    func testMatchingLeafAppliesItsWeightsAndIsReportedOnResult() {
        let context = makeContext(
            features: ["my-feature": makeFeature(["defaultValue": "off", "rules": [banditRule()]])],
            attributes: JSON(["id": "user-1", "country": "CA"]),
            contextualBandits: twoLeafBandits()
        )

        let result = evaluate("my-feature", in: context)

        XCTAssertEqual(result.source, FeatureSource.experiment.rawValue)
        // Leaf 2's weights are [0, 1] — every user lands in variation 1 regardless of hash.
        XCTAssertEqual(result.value?.stringValue, "treatment")
        XCTAssertEqual(result.experimentResult?.variationId, 1)
        XCTAssertEqual(result.experimentResult?.leafId, 2)
        XCTAssertEqual(result.experimentResult?.variationWeights, [0.0, 1.0])
        XCTAssertEqual(result.experimentResult?.banditVersion, 7)
    }

    func testFirstMatchingLeafWinsWhenSeveralConditionsMatch() {
        // Both leaves match a US user; the first one listed must win.
        let bandits = JSON([
            "bandit-1": [
                "banditVersion": 2,
                "contexts": [
                    ["leafId": 10, "condition": ["country": "US"], "weights": [1.0, 0.0]],
                    ["leafId": 20, "condition": ["country": "US"], "weights": [0.0, 1.0]]
                ]
            ]
        ])
        let context = makeContext(
            features: ["my-feature": makeFeature(["defaultValue": "off", "rules": [banditRule()]])],
            attributes: JSON(["id": "user-1", "country": "US"]),
            contextualBandits: bandits
        )

        let result = evaluate("my-feature", in: context)

        XCTAssertEqual(result.experimentResult?.leafId, 10)
        XCTAssertEqual(result.experimentResult?.variationWeights, [1.0, 0.0])
        XCTAssertEqual(result.value?.stringValue, "control")
    }

    func testLeafWithoutConditionMatchesEveryUser() {
        let bandits = JSON([
            "bandit-1": [
                "banditVersion": 1,
                "contexts": [
                    ["leafId": 5, "weights": [0.0, 1.0]]
                ]
            ]
        ])
        let context = makeContext(
            features: ["my-feature": makeFeature(["defaultValue": "off", "rules": [banditRule()]])],
            attributes: JSON(["id": "user-1"]),
            contextualBandits: bandits
        )

        let result = evaluate("my-feature", in: context)

        XCTAssertEqual(result.experimentResult?.leafId, 5)
        XCTAssertEqual(result.value?.stringValue, "treatment")
    }

    func testLeafConditionCanReferenceSavedGroups() {
        let bandits = JSON([
            "bandit-1": [
                "banditVersion": 4,
                "contexts": [
                    ["leafId": 9, "condition": ["id": ["$inGroup": "vips"]], "weights": [0.0, 1.0]]
                ]
            ]
        ])
        let context = makeContext(
            features: ["my-feature": makeFeature(["defaultValue": "off", "rules": [banditRule()]])],
            attributes: JSON(["id": "user-1"]),
            contextualBandits: bandits,
            savedGroups: JSON(["vips": ["user-1", "user-2"]])
        )

        let result = evaluate("my-feature", in: context)

        XCTAssertEqual(result.experimentResult?.leafId, 9)
        XCTAssertEqual(result.value?.stringValue, "treatment")
    }

    // MARK: - Fallback: no leaf matches

    func testNoMatchingLeafFallsBackToRuleWeightsWithFallbackLeafId() {
        let context = makeContext(
            features: ["my-feature": makeFeature([
                "defaultValue": "off",
                "rules": [banditRule(weights: [1.0, 0.0])]
            ])],
            // Matches neither the US nor the CA leaf.
            attributes: JSON(["id": "user-1", "country": "UA"]),
            contextualBandits: twoLeafBandits()
        )

        let result = evaluate("my-feature", in: context)

        XCTAssertEqual(result.experimentResult?.leafId, ContextualBandit.fallbackLeafId)
        XCTAssertEqual(result.experimentResult?.leafId, -1)
        // The rule's own aggregate weights survive — [1, 0] forces variation 0.
        XCTAssertEqual(result.experimentResult?.variationWeights, [1.0, 0.0])
        XCTAssertEqual(result.value?.stringValue, "control")
        XCTAssertEqual(result.experimentResult?.banditVersion, 7)
    }

    func testNoMatchingLeafAndNoRuleWeightsFallsBackToEqualWeights() {
        let context = makeContext(
            features: ["my-feature": makeFeature(["defaultValue": "off", "rules": [banditRule()]])],
            attributes: JSON(["id": "user-1", "country": "UA"]),
            contextualBandits: twoLeafBandits()
        )

        let result = evaluate("my-feature", in: context)

        XCTAssertEqual(result.experimentResult?.leafId, -1)
        XCTAssertEqual(result.experimentResult?.variationWeights, [0.5, 0.5])
    }

    func testEmptyContextsListFallsBack() {
        let bandits = JSON(["bandit-1": ["banditVersion": 3, "contexts": [] as [Any]]])
        let context = makeContext(
            features: ["my-feature": makeFeature(["defaultValue": "off", "rules": [banditRule(weights: [0.0, 1.0])]])],
            contextualBandits: bandits
        )

        let result = evaluate("my-feature", in: context)

        XCTAssertEqual(result.experimentResult?.leafId, -1)
        XCTAssertEqual(result.experimentResult?.variationWeights, [0.0, 1.0])
        XCTAssertEqual(result.experimentResult?.banditVersion, 3)
    }

    // MARK: - Fallback: missing ref / missing payload

    func testUnknownRefLeavesExperimentUntouched() {
        let context = makeContext(
            features: ["my-feature": makeFeature([
                "defaultValue": "off",
                "rules": [banditRule(ref: "does-not-exist", weights: [0.0, 1.0])]
            ])],
            attributes: JSON(["id": "user-1", "country": "US"]),
            contextualBandits: twoLeafBandits()
        )

        let result = evaluate("my-feature", in: context)

        // No definition found → no bandit metadata at all, rule weights apply as usual.
        XCTAssertNil(result.experimentResult?.leafId)
        XCTAssertNil(result.experimentResult?.variationWeights)
        XCTAssertNil(result.experimentResult?.banditVersion)
        XCTAssertNil(result.experiment?.contextualBandit)
        XCTAssertEqual(result.value?.stringValue, "treatment")
    }

    func testRefWithNoBanditsPayloadStillEvaluatesAsExperiment() {
        let context = makeContext(
            features: ["my-feature": makeFeature([
                "defaultValue": "off",
                "rules": [banditRule(weights: [0.0, 1.0])]
            ])],
            contextualBandits: nil
        )

        let result = evaluate("my-feature", in: context)

        XCTAssertEqual(result.source, FeatureSource.experiment.rawValue)
        XCTAssertNil(result.experimentResult?.leafId)
        XCTAssertEqual(result.value?.stringValue, "treatment")
    }

    // MARK: - contextualVariations

    func testContextualVariationsAreUsedWithoutARef() {
        // A rule can carry contextualVariations with no ref; the variations must still be read
        // rather than the rule being skipped for having no `variations`.
        let context = makeContext(
            features: ["my-feature": makeFeature([
                "defaultValue": "off",
                "rules": [banditRule(ref: nil, weights: [0.0, 1.0])]
            ])]
        )

        let result = evaluate("my-feature", in: context)

        XCTAssertEqual(result.source, FeatureSource.experiment.rawValue)
        XCTAssertEqual(result.value?.stringValue, "treatment")
        XCTAssertNil(result.experimentResult?.leafId)
    }

    func testContextualVariationsTakePrecedenceOverVariations() {
        let rule: [String: Any] = [
            "id": "rule-1",
            "key": "my-experiment",
            "variations": ["legacy-a", "legacy-b"],
            "contextualVariations": ["control", "treatment"],
            "weights": [0.0, 1.0]
        ]
        let context = makeContext(
            features: ["my-feature": makeFeature(["defaultValue": "off", "rules": [rule]])]
        )

        let result = evaluate("my-feature", in: context)

        XCTAssertEqual(result.value?.stringValue, "treatment")
    }

    func testBanditRefWorksWithPlainVariationsKey() {
        let rule: [String: Any] = [
            "id": "rule-1",
            "key": "my-experiment",
            "variations": ["control", "treatment"],
            "contextualBanditRef": "bandit-1"
        ]
        let context = makeContext(
            features: ["my-feature": makeFeature(["defaultValue": "off", "rules": [rule]])],
            attributes: JSON(["id": "user-1", "country": "CA"]),
            contextualBandits: twoLeafBandits()
        )

        let result = evaluate("my-feature", in: context)

        XCTAssertEqual(result.experimentResult?.leafId, 2)
        XCTAssertEqual(result.value?.stringValue, "treatment")
    }

    // MARK: - Only reported for a real exposure

    func testForcedVariationClearsBanditSelection() {
        let context = makeContext(
            features: ["my-feature": makeFeature(["defaultValue": "off", "rules": [banditRule()]])],
            attributes: JSON(["id": "user-1", "country": "CA"]),
            contextualBandits: twoLeafBandits(),
            forcedVariations: JSON(["my-experiment": 0])
        )

        let result = evaluate("my-feature", in: context)

        // The user was force-assigned, not hash-bucketed — the bandit weights did not decide
        // anything, so no selection may be reported.
        XCTAssertEqual(result.experimentResult?.hashUsed, false)
        XCTAssertNil(result.experimentResult?.leafId)
        XCTAssertNil(result.experimentResult?.variationWeights)
        XCTAssertNil(result.experimentResult?.banditVersion)
        XCTAssertNil(result.experiment?.contextualBandit)
    }

    func testQaModeYieldsNoBanditSelection() {
        let context = makeContext(
            features: ["my-feature": makeFeature(["defaultValue": "off", "rules": [banditRule()]])],
            attributes: JSON(["id": "user-1", "country": "CA"]),
            contextualBandits: twoLeafBandits(),
            isQaMode: true
        )

        let result = evaluate("my-feature", in: context)

        // QA mode never puts the user in the experiment, so the rule is skipped entirely.
        XCTAssertEqual(result.source, FeatureSource.defaultValue.rawValue)
        XCTAssertNil(result.experimentResult?.leafId)
    }

    func testUserExcludedByCoverageGetsNoBanditSelection() {
        var rule = banditRule()
        rule["coverage"] = 0.0
        let context = makeContext(
            features: ["my-feature": makeFeature(["defaultValue": "off", "rules": [rule]])],
            attributes: JSON(["id": "user-1", "country": "CA"]),
            contextualBandits: twoLeafBandits()
        )

        let result = evaluate("my-feature", in: context)

        XCTAssertEqual(result.source, FeatureSource.defaultValue.rawValue)
        XCTAssertNil(result.experimentResult?.leafId)
    }

    // MARK: - Tracking callback

    func testTrackingCallbackReceivesBanditEnrichedResult() {
        var tracked: [(Experiment, ExperimentResult)] = []
        // `ExperimentHelper.shared` dedupes tracking per
        // (hashAttribute, hashValue, experimentKey, variationId) for the lifetime of the process,
        // so this test needs an experiment key and user id no other test in the suite uses.
        let rule: [String: Any] = [
            "id": "rule-1",
            "key": "bandit-tracking-experiment",
            "contextualVariations": ["control", "treatment"],
            "contextualBanditRef": "bandit-1"
        ]
        let globalContext = GlobalContext(
            features: ["my-feature": makeFeature(["defaultValue": "off", "rules": [rule]])],
            savedGroups: nil,
            contextualBandits: twoLeafBandits()
        )
        let userContext = UserContext(attributes: JSON(["id": "bandit-tracking-user", "country": "CA"]))
        let options = ClientOptions(isEnabled: true, stickyBucketService: nil, isQaMode: false) { experiment, result in
            tracked.append((experiment, result))
        }
        let context = EvalContext(globalContext: globalContext, userContext: userContext, stackContext: StackContext(), options: options)

        _ = evaluate("my-feature", in: context)

        XCTAssertEqual(tracked.count, 1)
        XCTAssertEqual(tracked.first?.1.leafId, 2)
        XCTAssertEqual(tracked.first?.1.banditVersion, 7)
        XCTAssertEqual(tracked.first?.0.contextualBandit?.leafId, 2)
        XCTAssertEqual(tracked.first?.0.weights, [0.0, 1.0])
    }

    // MARK: - Model parsing

    func testFeatureRuleParsesBanditFields() {
        let rule = FeatureRule(json: JSON([
            "id": "rule-1",
            "contextualBanditRef": "bandit-1",
            "contextualVariations": ["a", "b"]
        ]).dictionaryValue)

        XCTAssertEqual(rule.contextualBanditRef, "bandit-1")
        XCTAssertEqual(rule.contextualVariations?.count, 2)
        XCTAssertEqual(rule.contextualVariations?.first?.stringValue, "a")
        XCTAssertNil(rule.variations)
    }

    func testFeatureRuleWithoutBanditFieldsHasNilBanditProperties() {
        let rule = FeatureRule(json: JSON(["id": "rule-1", "variations": ["a", "b"]]).dictionaryValue)

        XCTAssertNil(rule.contextualBanditRef)
        XCTAssertNil(rule.contextualVariations)
        XCTAssertEqual(rule.variations?.count, 2)
    }

    func testContextualBanditDefinitionParsing() {
        let definition = ContextualBanditDefinition(json: JSON([
            "banditVersion": 12,
            "contexts": [
                ["leafId": 0, "condition": ["country": "US"], "weights": [0.25, 0.75]],
                ["leafId": 1]
            ]
        ]).dictionaryValue)

        XCTAssertEqual(definition.banditVersion, 12)
        XCTAssertEqual(definition.contexts?.count, 2)
        XCTAssertEqual(definition.contexts?[0].leafId, 0)
        XCTAssertEqual(definition.contexts?[0].weights, [0.25, 0.75])
        XCTAssertEqual(definition.contexts?[0].condition?["country"].stringValue, "US")
        XCTAssertEqual(definition.contexts?[1].leafId, 1)
        XCTAssertNil(definition.contexts?[1].weights)
        XCTAssertNil(definition.contexts?[1].condition)
    }

    func testContextualBanditDefinitionParsingWithMissingFields() {
        let definition = ContextualBanditDefinition(json: JSON([:] as [String: Any]).dictionaryValue)

        XCTAssertNil(definition.banditVersion)
        XCTAssertNil(definition.contexts)
    }

    func testExperimentResultParsesBanditFieldsFromJson() {
        let result = ExperimentResult(json: JSON([
            "inExperiment": true,
            "variationId": 1,
            "leafId": 3,
            "banditVersion": 8,
            "variationWeights": [0.3, 0.7]
        ]).dictionaryValue)

        XCTAssertEqual(result.leafId, 3)
        XCTAssertEqual(result.banditVersion, 8)
        XCTAssertEqual(result.variationWeights, [0.3, 0.7])
    }

    // MARK: - Payload parsing

    func testFeaturesDataModelDecodesContextualBandits() throws {
        let json = """
        {
          "features": {},
          "contextualBandits": {
            "bandit-1": {
              "banditVersion": 5,
              "contexts": [{"leafId": 0, "condition": {"country": "US"}, "weights": [0.4, 0.6]}]
            }
          }
        }
        """
        let model = try JSONDecoder().decode(FeaturesDataModel.self, from: Data(json.utf8))

        XCTAssertNil(model.encryptedContextualBandits)
        let definition = model.contextualBandits?["bandit-1"]
        XCTAssertEqual(definition?["banditVersion"].intValue, 5)
        XCTAssertEqual(definition?["contexts"].arrayValue.count, 1)
    }

    func testFeaturesDataModelDecodesEncryptedContextualBandits() throws {
        let json = """
        {"features": {}, "encryptedContextualBandits": "iv.cipher"}
        """
        let model = try JSONDecoder().decode(FeaturesDataModel.self, from: Data(json.utf8))

        XCTAssertEqual(model.encryptedContextualBandits, "iv.cipher")
        XCTAssertNil(model.contextualBandits)
    }

    func testPayloadWithoutBanditsKeepsBanditFieldsNil() throws {
        let json = """
        {"features": {}, "savedGroups": {"vips": ["a"]}}
        """
        let model = try JSONDecoder().decode(FeaturesDataModel.self, from: Data(json.utf8))

        XCTAssertNil(model.contextualBandits)
        XCTAssertNil(model.encryptedContextualBandits)
        XCTAssertNotNil(model.savedGroups)
    }

    // MARK: - End-to-end through the SDK

    private let testApiHost = "https://host.com"

    /// A full API payload whose single feature is a contextual bandit rule. Leaf 1 forces
    /// variation 0 ("control"), leaf 2 forces variation 1 ("treatment").
    private func payload(banditVersion: Int, usWeights: [Float], caWeights: [Float]) -> String {
        """
        {
          "features": {
            "my-feature": {
              "defaultValue": "off",
              "rules": [{
                "id": "rule-1",
                "key": "e2e-experiment",
                "contextualBanditRef": "bandit-1",
                "contextualVariations": ["control", "treatment"]
              }]
            }
          },
          "contextualBandits": {
            "bandit-1": {
              "banditVersion": \(banditVersion),
              "contexts": [
                {"leafId": 1, "condition": {"country": "US"}, "weights": [\(usWeights[0]), \(usWeights[1])]},
                {"leafId": 2, "condition": {"country": "CA"}, "weights": [\(caWeights[0]), \(caWeights[1])]}
              ]
            }
          }
        }
        """
    }

    func testBanditsFromPreloadedPayloadAreApplied() {
        let clientKey = "bandit-offline-key"
        let manager = CachingManager(apiKey: clientKey)
        manager.clearCache()

        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: clientKey,
            attributes: ["id": "user-1", "country": "CA"],
            features: Data(payload(banditVersion: 1, usWeights: [1.0, 0.0], caWeights: [0.0, 1.0]).utf8),
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: nil, error: nil))
        .initializer()

        let result = sdk.evalFeature(id: "my-feature")

        XCTAssertEqual(result.source, FeatureSource.experiment.rawValue)
        XCTAssertEqual(result.value?.stringValue, "treatment")
        XCTAssertEqual(result.experimentResult?.leafId, 2)
        XCTAssertEqual(result.experimentResult?.banditVersion, 1)
        manager.clearCache()
    }

    func testBanditsFromNetworkPayloadAreApplied() {
        let clientKey = "bandit-network-key"
        let manager = CachingManager(apiKey: clientKey)
        manager.clearCache()

        let refreshed = XCTestExpectation(description: "refreshHandler called")
        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: clientKey,
            attributes: ["id": "user-1", "country": "US"],
            trackingCallback: { _, _ in },
            backgroundSync: false,
            ttlSeconds: 0
        )
        .setRefreshHandler(refreshHandler: { _ in DispatchQueue.main.async { refreshed.fulfill() } })
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(
            successResponse: payload(banditVersion: 4, usWeights: [1.0, 0.0], caWeights: [0.0, 1.0]),
            error: nil
        ))
        .initializer()

        wait(for: [refreshed], timeout: 2.0)

        let result = sdk.evalFeature(id: "my-feature")

        XCTAssertEqual(result.value?.stringValue, "control")
        XCTAssertEqual(result.experimentResult?.leafId, 1)
        XCTAssertEqual(result.experimentResult?.banditVersion, 4)
        manager.clearCache()
    }

    func testStableSessionDoesNotApplyRefreshedBandits() {
        let clientKey = "bandit-stable-key"
        let manager = CachingManager(apiKey: clientKey)
        manager.clearCache()

        // Session starts with bandits that send a CA user to "treatment".
        let initialPayload = payload(banditVersion: 1, usWeights: [1.0, 0.0], caWeights: [0.0, 1.0])
        // The refresh flips CA to "control" and bumps the version — it must not take effect now.
        let refreshedPayload = payload(banditVersion: 2, usWeights: [0.0, 1.0], caWeights: [1.0, 0.0])

        let refreshed = XCTestExpectation(description: "refreshHandler called")
        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: clientKey,
            attributes: ["id": "user-1", "country": "CA"],
            features: Data(initialPayload.utf8),
            trackingCallback: { _, _ in },
            backgroundSync: false,
            ttlSeconds: 0
        )
        .setStableSession(true)
        .setRefreshHandler(refreshHandler: { _ in DispatchQueue.main.async { refreshed.fulfill() } })
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: refreshedPayload, error: nil))
        .initializer()

        sdk.refreshCache()
        wait(for: [refreshed], timeout: 2.0)

        let result = sdk.evalFeature(id: "my-feature")

        XCTAssertEqual(result.value?.stringValue, "treatment", "Session bandit weights must survive the refresh")
        XCTAssertEqual(result.experimentResult?.leafId, 2)
        XCTAssertEqual(result.experimentResult?.banditVersion, 1, "banditVersion must still be the session's, not the refreshed one")
        manager.clearCache()
    }

    func testBanditsAreAppliedOnFirstFetchInStableSessionMode() {
        let clientKey = "bandit-stable-first-key"
        let manager = CachingManager(apiKey: clientKey)
        manager.clearCache()

        // No preloaded payload: the first network fetch establishes the session, and the bandits
        // riding along in that same payload must be applied rather than blocked by the latch.
        let refreshed = XCTestExpectation(description: "refreshHandler called")
        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: clientKey,
            attributes: ["id": "user-1", "country": "CA"],
            trackingCallback: { _, _ in },
            backgroundSync: false,
            ttlSeconds: 0
        )
        .setStableSession(true)
        .setRefreshHandler(refreshHandler: { _ in DispatchQueue.main.async { refreshed.fulfill() } })
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(
            successResponse: payload(banditVersion: 9, usWeights: [1.0, 0.0], caWeights: [0.0, 1.0]),
            error: nil
        ))
        .initializer()

        wait(for: [refreshed], timeout: 2.0)

        let result = sdk.evalFeature(id: "my-feature")

        XCTAssertEqual(result.experimentResult?.leafId, 2)
        XCTAssertEqual(result.experimentResult?.banditVersion, 9)
        XCTAssertEqual(result.value?.stringValue, "treatment")
        manager.clearCache()
    }

    func testContextualBanditsSurviveCacheRoundTrip() {
        let clientKey = "bandit-cache-key"
        let manager = CachingManager(apiKey: clientKey)
        manager.clearCache()

        // First SDK writes features + bandits to disk from the network response.
        let firstRefresh = XCTestExpectation(description: "first refresh")
        _ = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: clientKey,
            attributes: ["id": "user-1", "country": "CA"],
            trackingCallback: { _, _ in },
            backgroundSync: false,
            ttlSeconds: 0
        )
        .setRefreshHandler(refreshHandler: { _ in DispatchQueue.main.async { firstRefresh.fulfill() } })
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(
            successResponse: payload(banditVersion: 6, usWeights: [1.0, 0.0], caWeights: [0.0, 1.0]),
            error: nil
        ))
        .initializer()
        wait(for: [firstRefresh], timeout: 2.0)

        // A second SDK with a failing network must recover both from the cache.
        let secondRefresh = XCTestExpectation(description: "second refresh")
        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: clientKey,
            attributes: ["id": "user-1", "country": "CA"],
            trackingCallback: { _, _ in },
            backgroundSync: false,
            ttlSeconds: 0
        )
        .setRefreshHandler(refreshHandler: { _ in DispatchQueue.main.async { secondRefresh.fulfill() } })
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: nil, error: SDKError.failedToLoadData))
        .initializer()
        wait(for: [secondRefresh], timeout: 2.0)

        let result = sdk.evalFeature(id: "my-feature")

        XCTAssertEqual(result.experimentResult?.leafId, 2, "Bandits must be restored from the on-disk cache")
        XCTAssertEqual(result.experimentResult?.banditVersion, 6)
        manager.clearCache()
    }

    // MARK: - Sticky bucket identifier attributes

    /// The identifier attributes drive which assignment documents are fetched from the sticky bucket
    /// service. A contextual bandit rule carries its variations under `contextualVariations`, so a
    /// check for `variations` alone leaves its hash and fallback attributes unregistered and sticky
    /// bucketing silently never loads that experiment's documents.
    func testStickyBucketIdentifierAttributesIncludeContextualBanditRules() {
        let rule: [String: Any] = [
            "id": "rule-1",
            "key": "my-experiment",
            "contextualBanditRef": "bandit-1",
            "contextualVariations": ["control", "treatment"],
            "hashAttribute": "deviceId",
            "fallbackAttribute": "anonymousId"
        ]
        let context = makeContext(
            features: ["my-feature": makeFeature(["defaultValue": "off", "rules": [rule]])],
            contextualBandits: twoLeafBandits()
        )

        let attributes = Utils.deriveStickyBucketIdentifierAttributes(context: context, data: nil)

        XCTAssertTrue(attributes.contains("deviceId"),
                      "A bandit rule's hashAttribute must be registered for sticky bucketing")
        XCTAssertTrue(attributes.contains("anonymousId"),
                      "A bandit rule's fallbackAttribute must be registered for sticky bucketing")
    }

    func testStickyBucketIdentifierAttributesStillIncludePlainRules() {
        let rule: [String: Any] = [
            "id": "rule-1",
            "key": "plain-experiment",
            "variations": ["a", "b"],
            "hashAttribute": "userId"
        ]
        let context = makeContext(
            features: ["my-feature": makeFeature(["defaultValue": "off", "rules": [rule]])]
        )

        XCTAssertTrue(Utils.deriveStickyBucketIdentifierAttributes(context: context, data: nil).contains("userId"))
    }

    func testStickyBucketIdentifierAttributesIgnoreNonExperimentRules() {
        // A pure force rule has neither variations nor contextualVariations and must not contribute.
        let rule: [String: Any] = ["id": "rule-1", "force": "on", "hashAttribute": "shouldNotAppear"]
        let context = makeContext(
            features: ["my-feature": makeFeature(["defaultValue": "off", "rules": [rule]])]
        )

        XCTAssertFalse(Utils.deriveStickyBucketIdentifierAttributes(context: context, data: nil).contains("shouldNotAppear"))
    }

    // MARK: - Context plumbing

    func testContextManagerPropagatesContextualBanditsToEvalContext() {
        let evalData = EvaluationData(
            streamingHost: nil,
            attributes: JSON(["id": "user-1"]),
            forcedVariations: nil,
            features: [:],
            savedGroups: nil,
            contextualBandits: twoLeafBandits()
        )
        let globalConfig = GlobalConfig(
            apiHost: nil, clientKey: nil, encryptionKey: nil,
            isEnabled: true, isQaMode: false, backgroundSync: false,
            remoteEval: false, trackingClosure: { _, _ in }
        )
        let manager = ContextManager(globalConfig: globalConfig, evalData: evalData)

        XCTAssertEqual(
            manager.getEvalContext().globalContext.contextualBandits?["bandit-1"]["banditVersion"].intValue,
            7
        )

        // Cache invalidation: an update must be visible on the next context build.
        manager.updateEvalData { data in
            data.contextualBandits = JSON(["bandit-2": ["banditVersion": 99]])
        }
        XCTAssertNil(manager.getEvalContext().globalContext.contextualBandits?["bandit-1"].dictionary)
        XCTAssertEqual(
            manager.getEvalContext().globalContext.contextualBandits?["bandit-2"]["banditVersion"].intValue,
            99
        )
    }
}
