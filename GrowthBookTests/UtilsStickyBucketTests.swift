import XCTest
@testable import GrowthBook

class UtilsStickyBucketTests: XCTestCase {

    // MARK: - Helpers

    private func makeEvalContext(
        attributes: JSON = JSON(["id": "user-1"]),
        features: Features = [:],
        experiments: [Experiment]? = nil,
        stickyDocs: [String: StickyAssignmentsDocument]? = nil,
        stickyService: StickyBucketServiceProtocol? = nil
    ) -> EvalContext {
        let globalContext = GlobalContext(features: features, experiments: experiments)
        let userContext = UserContext(attributes: attributes, stickyBucketAssignmentDocs: stickyDocs)
        let options = ClientOptions(
            isEnabled: true,
            stickyBucketService: stickyService,
            isQaMode: false,
            trackingClosure: { _, _ in }
        )
        return EvalContext(
            globalContext: globalContext,
            userContext: userContext,
            stackContext: StackContext(),
            options: options
        )
    }

    // MARK: - getStickyBucketExperimentKey

    func testGetStickyBucketExperimentKeyDefaultVersion() {
        XCTAssertEqual(Utils.getStickyBucketExperimentKey("my-exp"), "my-exp__0")
    }

    func testGetStickyBucketExperimentKeyWithVersion() {
        XCTAssertEqual(Utils.getStickyBucketExperimentKey("my-exp", 3), "my-exp__3")
    }

    func testGetStickyBucketExperimentKeyVersionZero() {
        XCTAssertEqual(Utils.getStickyBucketExperimentKey("exp", 0), "exp__0")
    }

    // MARK: - getStickyBucketAssignments

    func testGetStickyBucketAssignmentsNoDocsReturnsEmpty() {
        let context = makeEvalContext(stickyDocs: nil)
        let result = Utils.getStickyBucketAssignments(context: context, expHashAttribute: "id")
        XCTAssertTrue(result.isEmpty)
    }

    func testGetStickyBucketAssignmentsReturnsMatchingDoc() {
        let doc = StickyAssignmentsDocument(
            attributeName: "id",
            attributeValue: "user-1",
            assignments: ["exp__0": "control"]
        )
        let context = makeEvalContext(stickyDocs: ["id||user-1": doc])
        let result = Utils.getStickyBucketAssignments(context: context, expHashAttribute: "id")
        XCTAssertEqual(result["exp__0"], "control")
    }

    func testGetStickyBucketAssignmentsMergesFallback() {
        let primaryDoc = StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "user-1",
            assignments: ["exp-a__0": "variant"]
        )
        let fallbackDoc = StickyAssignmentsDocument(
            attributeName: "deviceId", attributeValue: "device-99",
            assignments: ["exp-b__0": "control"]
        )
        let context = makeEvalContext(
            attributes: JSON(["id": "user-1", "deviceId": "device-99"]),
            stickyDocs: ["id||user-1": primaryDoc, "deviceId||device-99": fallbackDoc]
        )
        let result = Utils.getStickyBucketAssignments(
            context: context,
            expHashAttribute: "id",
            expFallbackAttribute: "deviceId"
        )
        XCTAssertEqual(result["exp-a__0"], "variant")
        XCTAssertEqual(result["exp-b__0"], "control")
    }

    // MARK: - generateStickyBucketAssignmentDoc

    func testGenerateStickyBucketAssignmentDocNewKey() {
        let context = makeEvalContext()
        let result = Utils.generateStickyBucketAssignmentDoc(
            context: context,
            attributeName: "id",
            attributeValue: "user-1",
            assignments: ["exp__0": "variant"]
        )
        XCTAssertEqual(result.key, "id||user-1")
        XCTAssertEqual(result.doc.assignments["exp__0"], "variant")
        XCTAssertTrue(result.changed)
    }

    func testGenerateStickyBucketAssignmentDocMergesExisting() {
        let existingDoc = StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "user-1",
            assignments: ["exp-a__0": "control"]
        )
        let context = makeEvalContext(stickyDocs: ["id||user-1": existingDoc])
        let result = Utils.generateStickyBucketAssignmentDoc(
            context: context,
            attributeName: "id",
            attributeValue: "user-1",
            assignments: ["exp-b__0": "variant"]
        )
        XCTAssertEqual(result.doc.assignments["exp-a__0"], "control")
        XCTAssertEqual(result.doc.assignments["exp-b__0"], "variant")
        XCTAssertTrue(result.changed)
    }

    func testGenerateStickyBucketAssignmentDocUnchangedWhenSame() {
        let existingDoc = StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "user-1",
            assignments: ["exp__0": "control"]
        )
        let context = makeEvalContext(stickyDocs: ["id||user-1": existingDoc])
        let result = Utils.generateStickyBucketAssignmentDoc(
            context: context,
            attributeName: "id",
            attributeValue: "user-1",
            assignments: ["exp__0": "control"]
        )
        XCTAssertFalse(result.changed)
    }

    // MARK: - getStickyBucketVariation

    func testGetStickyBucketVariationNoAssignmentsReturnsMinusOne() {
        let context = makeEvalContext()
        let result = Utils.getStickyBucketVariation(
            context: context,
            experimentKey: "my-exp",
            meta: [VariationMeta(json: ["key": "control"]), VariationMeta(json: ["key": "variant"])]
        )
        XCTAssertEqual(result.variation, -1)
        XCTAssertNil(result.versionIsBlocked)
    }

    func testGetStickyBucketVariationReturnsAssignedVariation() {
        let doc = StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "user-1",
            assignments: ["my-exp__0": "variant"]
        )
        let context = makeEvalContext(stickyDocs: ["id||user-1": doc])
        let meta = [
            VariationMeta(json: ["key": "control"]),
            VariationMeta(json: ["key": "variant"])
        ]
        let result = Utils.getStickyBucketVariation(
            context: context,
            experimentKey: "my-exp",
            meta: meta
        )
        XCTAssertEqual(result.variation, 1)
        XCTAssertNil(result.versionIsBlocked)
    }

    func testGetStickyBucketVariationBlockedByMinVersion() {
        let doc = StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "user-1",
            assignments: ["my-exp__0": "control"]
        )
        let context = makeEvalContext(stickyDocs: ["id||user-1": doc])
        let result = Utils.getStickyBucketVariation(
            context: context,
            experimentKey: "my-exp",
            experimentBucketVersion: 1,
            minExperimentBucketVersion: 1,
            meta: [VariationMeta(json: ["key": "control"])]
        )
        XCTAssertEqual(result.variation, -1)
        XCTAssertEqual(result.versionIsBlocked, true)
    }

    // MARK: - deriveStickyBucketIdentifierAttributes

    func testDeriveStickyBucketAttributesFromFeatureRules() {
        // variations must be non-nil for the rule to be processed
        let rule = FeatureRule(
            variations: [JSON("a"), JSON("b")],
            hashAttribute: "userId",
            fallBackAttribute: "deviceId"
        )
        let feature = Feature(defaultValue: nil, rules: [rule])
        let context = makeEvalContext(features: ["my-feature": feature])
        let attrs = Utils.deriveStickyBucketIdentifierAttributes(context: context, data: nil)
        XCTAssertTrue(attrs.contains("userId"))
        XCTAssertTrue(attrs.contains("deviceId"))
    }

    func testDeriveStickyBucketAttributesDefaultsToId() {
        let rule = FeatureRule(variations: [JSON("a"), JSON("b")])
        let feature = Feature(defaultValue: nil, rules: [rule])
        let context = makeEvalContext(features: ["f": feature])
        let attrs = Utils.deriveStickyBucketIdentifierAttributes(context: context, data: nil)
        XCTAssertTrue(attrs.contains("id"))
    }

    func testDeriveStickyBucketAttributesFromExperiments() {
        let experiment = Experiment(
            key: "exp",
            variations: [JSON("a"), JSON("b")],
            hashAttribute: "email",
            fallBackAttribute: "phone"
        )
        let context = makeEvalContext(experiments: [experiment])
        let attrs = Utils.deriveStickyBucketIdentifierAttributes(context: context, data: nil)
        XCTAssertTrue(attrs.contains("email"))
        XCTAssertTrue(attrs.contains("phone"))
    }

    // MARK: - propagateStickyAssignments

    func testPropagateStickyAssignmentsCopiesChildToParent() {
        let childDoc = StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "user-1",
            assignments: ["exp__0": "variant"]
        )
        let childContext = makeEvalContext(stickyDocs: ["id||user-1": childDoc])
        let parentContext = makeEvalContext(stickyDocs: nil)

        Utils.propagateStickyAssignments(from: childContext, to: parentContext)

        XCTAssertEqual(
            parentContext.userContext.stickyBucketAssignmentDocs?["id||user-1"]?.assignments["exp__0"],
            "variant"
        )
    }

    func testPropagateStickyAssignmentsMergesWithExistingParentDoc() {
        let childDoc = StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "user-1",
            assignments: ["exp-b__0": "variant"]
        )
        let parentDoc = StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "user-1",
            assignments: ["exp-a__0": "control"]
        )
        let childContext = makeEvalContext(stickyDocs: ["id||user-1": childDoc])
        let parentContext = makeEvalContext(stickyDocs: ["id||user-1": parentDoc])

        Utils.propagateStickyAssignments(from: childContext, to: parentContext)

        let merged = parentContext.userContext.stickyBucketAssignmentDocs?["id||user-1"]?.assignments
        XCTAssertEqual(merged?["exp-a__0"], "control")
        XCTAssertEqual(merged?["exp-b__0"], "variant")
    }

    func testPropagateStickyAssignmentsSkipsEmptyChild() {
        let childContext = makeEvalContext(stickyDocs: nil)
        let parentContext = makeEvalContext(stickyDocs: nil)

        Utils.propagateStickyAssignments(from: childContext, to: parentContext)

        XCTAssertNil(parentContext.userContext.stickyBucketAssignmentDocs)
    }

    // MARK: - initializeEvalContext (deprecated)

    func testInitializeEvalContextCreatesValidContext() {
        let context = Context(
            apiHost: "https://host.com",
            streamingHost: nil,
            clientKey: "key",
            encryptionKey: nil,
            isEnabled: true,
            attributes: JSON(["id": "user-1"]),
            forcedVariations: JSON([:]),
            isQaMode: false,
            trackingClosure: { _, _ in },
            features: [:],
            backgroundSync: false
        )
        let evalContext = Utils.initializeEvalContext(context: context)
        XCTAssertEqual(evalContext.userContext.attributes["id"].stringValue, "user-1")
        XCTAssertTrue(evalContext.options.isEnabled)
        XCTAssertFalse(evalContext.options.isQaMode)
    }
}
