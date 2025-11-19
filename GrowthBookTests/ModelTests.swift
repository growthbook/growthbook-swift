import XCTest
@testable import GrowthBook

class GlobalConfigTests: XCTestCase {
    
    func testGlobalConfig_isImmutable() {
        // Arrange
        let config = GlobalConfig(
            apiHost: "https://test.com",
            clientKey: "test-key",
            encryptionKey: "enc-key",
            isEnabled: true,
            isQaMode: false,
            backgroundSync: true,
            remoteEval: true,
            trackingClosure: { _, _ in },
            stickyBucketService: nil
        )
        
        // Assert - all properties should be let (immutable)
        // This is checked by the compiler, but we can verify the values
        XCTAssertEqual(config.apiHost, "https://test.com")
        XCTAssertEqual(config.clientKey, "test-key")
        XCTAssertEqual(config.encryptionKey, "enc-key")
        XCTAssertTrue(config.isEnabled)
        XCTAssertFalse(config.isQaMode)
        XCTAssertTrue(config.backgroundSync)
        XCTAssertTrue(config.remoteEval)
    }
    
    func testGlobalConfig_initialization() {
        // Arrange & Act
        let config = GlobalConfig(
            apiHost: "https://api.example.com",
            clientKey: "client-123",
            encryptionKey: nil,
            isEnabled: false,
            isQaMode: true,
            backgroundSync: false,
            remoteEval: false,
            trackingClosure: { experiment, result in
                // Test closure
            },
            stickyBucketService: nil
        )
        
        // Assert
        XCTAssertNotNil(config)
        XCTAssertEqual(config.apiHost, "https://api.example.com")
        XCTAssertEqual(config.clientKey, "client-123")
        XCTAssertNil(config.encryptionKey)
        XCTAssertFalse(config.isEnabled)
        XCTAssertTrue(config.isQaMode)
        XCTAssertFalse(config.backgroundSync)
        XCTAssertFalse(config.remoteEval)
    }
    
    func testGlobalConfig_defaultValues() {
        // Arrange & Act
        let config = GlobalConfig(
            apiHost: nil,
            clientKey: nil,
            encryptionKey: nil,
            isEnabled: true,
            isQaMode: false,
            backgroundSync: false,
            remoteEval: false,
            trackingClosure: { _, _ in }
        )
        
        // Assert - check default values
        XCTAssertNil(config.apiHost)
        XCTAssertNil(config.clientKey)
        XCTAssertNil(config.encryptionKey)
        XCTAssertNil(config.stickyBucketService)
    }
    
    func testGlobalConfig_trackingClosure() {
        // Arrange
        var trackedExperiment: Experiment?
        var trackedResult: ExperimentResult?
        
        let config = GlobalConfig(
            apiHost: nil,
            clientKey: nil,
            encryptionKey: nil,
            isEnabled: true,
            isQaMode: false,
            backgroundSync: false,
            remoteEval: false,
            trackingClosure: { experiment, result in
                trackedExperiment = experiment
                trackedResult = result
            }
        )
        
        // Act
        let testExperiment = Experiment(key: "test-exp", variations: [JSON("var1"), JSON("var2")])
        let testResult = ExperimentResult(inExperiment: true, variationId: 0, value: JSON("var1"), key: "test-exp")
        config.trackingClosure(testExperiment, testResult)
        
        // Assert
        XCTAssertNotNil(trackedExperiment)
        XCTAssertNotNil(trackedResult)
        XCTAssertEqual(trackedExperiment?.key, "test-exp")
        XCTAssertEqual(trackedResult?.variationId, 0)
    }
}

class EvaluationDataTests: XCTestCase {
    
    func testEvaluationData_isMutable() {
        // Arrange
        var data = EvaluationData(
            streamingHost: "https://streaming.test.com",
            attributes: JSON(["id": "user1"]),
            forcedVariations: nil
        )
        
        // Act
        data.attributes = JSON(["id": "user2", "name": "Test"])
        data.features = ["feature1": Feature(defaultValue: JSON("value1"))]
        data.streamingHost = "https://new-streaming.test.com"
        data.savedGroups = JSON(["group1": "value1"])
        data.url = "https://test.com/page"
        data.forcedFeatureValues = JSON(["feature1": "forced-value"])
        
        // Assert
        XCTAssertEqual(data.attributes["id"].stringValue, "user2")
        XCTAssertEqual(data.attributes["name"].stringValue, "Test")
        XCTAssertEqual(data.features.count, 1)
        XCTAssertEqual(data.streamingHost, "https://new-streaming.test.com")
        XCTAssertNotNil(data.savedGroups)
        XCTAssertEqual(data.url, "https://test.com/page")
        XCTAssertNotNil(data.forcedFeatureValues)
    }
    
    func testEvaluationData_defaultValues() {
        // Arrange & Act
        let data = EvaluationData(
            streamingHost: nil,
            attributes: JSON(),
            forcedVariations: nil
        )
        
        // Assert
        XCTAssertNil(data.streamingHost)
        XCTAssertEqual(data.attributes.count, 0)
        XCTAssertNil(data.forcedVariations)
        XCTAssertEqual(data.features.count, 0)
        XCTAssertNil(data.savedGroups)
        XCTAssertNil(data.url)
        XCTAssertNil(data.forcedFeatureValues)
        XCTAssertNil(data.stickyBucketAssignmentDocs)
        XCTAssertNil(data.stickyBucketIdentifierAttributes)
    }
    
    func testEvaluationData_initializationWithAllProperties() {
        // Arrange
        let features: Features = [
            "feature1": Feature(defaultValue: JSON("value1")),
            "feature2": Feature(defaultValue: JSON("value2"))
        ]
        let attributes = JSON(["id": "user123", "name": "Test User"])
        let forcedVariations = JSON(["exp1": 1, "exp2": 0])
        let forcedFeatureValues = JSON(["feature1": "forced"])
        let savedGroups = JSON(["group1": "value1"])
        let stickyDocs: [String: StickyAssignmentsDocument] = [
            "id||user123": StickyAssignmentsDocument(
                attributeName: "id",
                attributeValue: "user123",
                assignments: ["exp1": "var1"]
            )
        ]
        
        // Act
        let data = EvaluationData(
            streamingHost: "https://streaming.test.com",
            attributes: attributes,
            forcedVariations: forcedVariations,
            stickyBucketAssignmentDocs: stickyDocs,
            stickyBucketIdentifierAttributes: ["id", "email"],
            features: features,
            savedGroups: savedGroups,
            url: "https://test.com",
            forcedFeatureValues: forcedFeatureValues
        )
        
        // Assert
        XCTAssertEqual(data.streamingHost, "https://streaming.test.com")
        XCTAssertEqual(data.attributes["id"].stringValue, "user123")
        XCTAssertEqual(data.features.count, 2)
        XCTAssertNotNil(data.forcedVariations)
        XCTAssertNotNil(data.forcedFeatureValues)
        XCTAssertNotNil(data.savedGroups)
        XCTAssertEqual(data.url, "https://test.com")
        XCTAssertNotNil(data.stickyBucketAssignmentDocs)
        XCTAssertEqual(data.stickyBucketIdentifierAttributes?.count, 2)
    }
    
    func testEvaluationData_canModifyFeatures() {
        // Arrange
        var data = EvaluationData(
            streamingHost: nil,
            attributes: JSON(),
            forcedVariations: nil
        )
        
        // Act
        data.features = ["initial": Feature(defaultValue: JSON("initial-value"))]
        XCTAssertEqual(data.features.count, 1)
        
        data.features["new-feature"] = Feature(defaultValue: JSON("new-value"))
        XCTAssertEqual(data.features.count, 2)
        
        data.features.removeValue(forKey: "initial")
        XCTAssertEqual(data.features.count, 1)
        
        // Assert
        XCTAssertNotNil(data.features["new-feature"])
        XCTAssertNil(data.features["initial"])
    }
    
    func testEvaluationData_canModifyAttributes() {
        // Arrange
        var data = EvaluationData(
            streamingHost: nil,
            attributes: JSON(["id": "user1"]),
            forcedVariations: nil
        )
        
        // Act
        data.attributes["name"] = JSON("Test User")
        data.attributes["email"] = JSON("test@example.com")
        
        // Assert
        XCTAssertEqual(data.attributes["id"].stringValue, "user1")
        XCTAssertEqual(data.attributes["name"].stringValue, "Test User")
        XCTAssertEqual(data.attributes["email"].stringValue, "test@example.com")
    }
    
    func testEvaluationData_stickyBucketAssignmentDocs() {
        // Arrange
        var data = EvaluationData(
            streamingHost: nil,
            attributes: JSON(),
            forcedVariations: nil
        )
        
        // Act
        let doc = StickyAssignmentsDocument(
            attributeName: "id",
            attributeValue: "user123",
            assignments: ["exp1": "var1", "exp2": "var2"]
        )
        data.stickyBucketAssignmentDocs = ["id||user123": doc]
        
        // Assert
        XCTAssertNotNil(data.stickyBucketAssignmentDocs)
        XCTAssertEqual(data.stickyBucketAssignmentDocs?.count, 1)
        XCTAssertEqual(data.stickyBucketAssignmentDocs?["id||user123"]?.attributeName, "id")
        XCTAssertEqual(data.stickyBucketAssignmentDocs?["id||user123"]?.attributeValue, "user123")
        XCTAssertEqual(data.stickyBucketAssignmentDocs?["id||user123"]?.assignments.count, 2)
    }
}

