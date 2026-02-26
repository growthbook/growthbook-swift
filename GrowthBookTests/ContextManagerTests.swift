import XCTest
@testable import GrowthBook

class ContextManagerTests: XCTestCase {
    
    var globalConfig: GlobalConfig!
    var evalData: EvaluationData!
    var contextManager: ContextManager!
    
    override func setUp() {
        super.setUp()
        
        globalConfig = GlobalConfig(
            apiHost: "https://test.com",
            clientKey: "test-key",
            encryptionKey: "test-encryption-key",
            isEnabled: true,
            isQaMode: false,
            backgroundSync: false,
            remoteEval: false,
            trackingClosure: { _, _ in },
            stickyBucketService: nil
        )
        
        evalData = EvaluationData(
            streamingHost: "https://streaming.test.com",
            attributes: JSON(["id": "user123", "name": "Test User"]),
            forcedVariations: nil,
            stickyBucketAssignmentDocs: nil,
            stickyBucketIdentifierAttributes: nil,
            features: [:],
            savedGroups: nil,
            url: nil,
            forcedFeatureValues: nil
        )
        
        contextManager = ContextManager(globalConfig: globalConfig, evalData: evalData)
    }
    
    override func tearDown() {
        globalConfig = nil
        evalData = nil
        contextManager = nil
        super.tearDown()
    }
    
    // MARK: - getEvalContext Tests
    
    func testGetEvalContext_createsValidContext() {
        // Act
        let context = contextManager.getEvalContext()
        
        // Assert
        XCTAssertNotNil(context)
        XCTAssertEqual(context.userContext.attributes["id"].stringValue, "user123")
        XCTAssertEqual(context.userContext.attributes["name"].stringValue, "Test User")
        XCTAssertTrue(context.options.isEnabled)
        XCTAssertFalse(context.options.isQaMode)
        XCTAssertEqual(context.globalContext.features.count, 0)
    }
    
    func testGetEvalContext_cachesContext() {
        // Act
        let context1 = contextManager.getEvalContext()
        let context2 = contextManager.getEvalContext()
        
        // Assert - should be the same object (caching)
        XCTAssertTrue(context1 === context2, "Context should be cached and reused")
    }
    
    func testGetEvalContext_createsNewStackContext() {
        // Act
        let context1 = contextManager.getEvalContext()
        context1.stackContext.evaluatedFeatures.insert("feature1")
        
        let context2 = contextManager.getEvalContext()
        
        // Assert - stackContext should be new on each call
        // But since it's cached, they will be the same
        // Let's verify that after cache invalidation a new one is created
        contextManager.updateEvalData { _ in }
        let context3 = contextManager.getEvalContext()
        
        XCTAssertTrue(context1 === context2, "Should use cached context")
        XCTAssertFalse(context1 === context3, "Should create new context after cache invalidation")
        XCTAssertTrue(context3.stackContext.evaluatedFeatures.isEmpty, "New context should have empty stack")
    }
    
    // MARK: - updateEvalData Tests
    
    func testUpdateEvalData_updatesData() {
        // Arrange
        let newFeatures: Features = [
            "test-feature": Feature(defaultValue: JSON("test-value"))
        ]
        
        // Act
        contextManager.updateEvalData { data in
            data.features = newFeatures
        }
        
        // Assert
        let updatedData = contextManager.getEvaluationData()
        XCTAssertEqual(updatedData.features.count, 1)
        XCTAssertNotNil(updatedData.features["test-feature"])
    }
    
    func testUpdateEvalData_updatesAttributes() {
        // Arrange
        let newAttributes = JSON(["id": "new-user", "email": "test@example.com"])
        
        // Act
        contextManager.updateEvalData { data in
            data.attributes = newAttributes
        }
        
        // Assert
        let updatedData = contextManager.getEvaluationData()
        XCTAssertEqual(updatedData.attributes["id"].stringValue, "new-user")
        XCTAssertEqual(updatedData.attributes["email"].stringValue, "test@example.com")
    }
    
    func testUpdateEvalData_invalidatesCache() {
        // Arrange
        let context1 = contextManager.getEvalContext()
        
        // Act
        contextManager.updateEvalData { data in
            data.attributes = JSON(["new": "value"])
        }
        let context2 = contextManager.getEvalContext()
        
        // Assert - should be different objects (cache invalidated)
        XCTAssertFalse(context1 === context2, "Cache should be invalidated after update")
        XCTAssertEqual(context2.userContext.attributes["new"].stringValue, "value")
    }
    
    func testUpdateEvalData_updatesMultipleProperties() {
        // Act
        contextManager.updateEvalData { data in
            data.features = ["feature1": Feature(defaultValue: JSON("value1"))]
            data.attributes = JSON(["attr": "value"])
            data.savedGroups = JSON(["group1": "value1"])
        }
        
        // Assert
        let updatedData = contextManager.getEvaluationData()
        XCTAssertEqual(updatedData.features.count, 1)
        XCTAssertEqual(updatedData.attributes["attr"].stringValue, "value")
        XCTAssertNotNil(updatedData.savedGroups)
    }
    
    // MARK: - syncFromEvaluation Tests
    
    func testSyncFromEvaluation_syncsStickyBucketAssignmentDocs() {
        // Arrange
        let evalContext = contextManager.getEvalContext()
        
        // Create a new document for sticky bucket
        let doc = StickyAssignmentsDocument(
            attributeName: "id",
            attributeValue: "user123",
            assignments: ["exp1": "var1"]
        )
        evalContext.userContext.stickyBucketAssignmentDocs = ["id||user123": doc]
        
        // Act
        contextManager.syncFromEvaluation(evalContext)
        
        // Assert
        let updatedData = contextManager.getEvaluationData()
        XCTAssertNotNil(updatedData.stickyBucketAssignmentDocs)
        XCTAssertEqual(updatedData.stickyBucketAssignmentDocs?["id||user123"]?.attributeName, "id")
        XCTAssertEqual(updatedData.stickyBucketAssignmentDocs?["id||user123"]?.attributeValue, "user123")
    }
    
    func testSyncFromEvaluation_invalidatesCache() {
        // Arrange
        let context1 = contextManager.getEvalContext()
        let evalContext = contextManager.getEvalContext()
        
        // Act
        contextManager.syncFromEvaluation(evalContext)
        let context2 = contextManager.getEvalContext()
        
        // Assert
        XCTAssertFalse(context1 === context2, "Cache should be invalidated after sync")
    }
    
    func testSyncFromEvaluation_handlesNilStickyBucketDocs() {
        // Arrange
        let evalContext = contextManager.getEvalContext()
        evalContext.userContext.stickyBucketAssignmentDocs = nil
        
        // Act
        contextManager.syncFromEvaluation(evalContext)
        
        // Assert
        let updatedData = contextManager.getEvaluationData()
        XCTAssertNil(updatedData.stickyBucketAssignmentDocs)
    }
    
    // MARK: - getEvaluationData Tests
    
    func testGetEvaluationData_returnsCurrentData() {
        // Act
        let data = contextManager.getEvaluationData()
        
        // Assert
        XCTAssertEqual(data.attributes["id"].stringValue, "user123")
        XCTAssertEqual(data.streamingHost, "https://streaming.test.com")
    }
    
    func testGetEvaluationData_returnsReference() {
        // Act
        let data1 = contextManager.getEvaluationData()
        let data2 = contextManager.getEvaluationData()
        
        // Assert - should be the same object
        XCTAssertTrue(data1 === data2, "Should return the same instance")
    }
    
    // MARK: - getGlobalConfig Tests
    
    func testGetGlobalConfig_returnsConfig() {
        // Act
        let config = contextManager.getGlobalConfig()
        
        // Assert
        XCTAssertEqual(config.apiHost, "https://test.com")
        XCTAssertEqual(config.clientKey, "test-key")
        XCTAssertTrue(config.isEnabled)
    }
    
    func testGetGlobalConfig_returnsReference() {
        // Act
        let config1 = contextManager.getGlobalConfig()
        let config2 = contextManager.getGlobalConfig()
        
        // Assert - should be the same object
        XCTAssertTrue(config1 === config2, "Should return the same instance")
    }
    
    // MARK: - URL Methods Tests
    
    func testGetFeaturesURL_returnsCorrectURL() {
        // Act
        let url = contextManager.getFeaturesURL()
        
        // Assert
        XCTAssertEqual(url, "https://test.com/api/features/test-key")
    }
    
    func testGetFeaturesURL_returnsNilWhenMissingApiHost() {
        // Arrange
        let config = GlobalConfig(
            apiHost: nil,
            clientKey: "test-key",
            encryptionKey: nil,
            isEnabled: true,
            isQaMode: false,
            backgroundSync: false,
            remoteEval: false,
            trackingClosure: { _, _ in },
            stickyBucketService: nil
        )
        let manager = ContextManager(globalConfig: config, evalData: evalData)
        
        // Act
        let url = manager.getFeaturesURL()
        
        // Assert
        XCTAssertNil(url)
    }
    
    func testGetFeaturesURL_returnsNilWhenMissingClientKey() {
        // Arrange
        let config = GlobalConfig(
            apiHost: "https://test.com",
            clientKey: nil,
            encryptionKey: nil,
            isEnabled: true,
            isQaMode: false,
            backgroundSync: false,
            remoteEval: false,
            trackingClosure: { _, _ in },
            stickyBucketService: nil
        )
        let manager = ContextManager(globalConfig: config, evalData: evalData)
        
        // Act
        let url = manager.getFeaturesURL()
        
        // Assert
        XCTAssertNil(url)
    }
    
    func testGetRemoteEvalUrl_returnsCorrectURL() {
        // Act
        let url = contextManager.getRemoteEvalUrl()
        
        // Assert
        XCTAssertEqual(url, "https://test.com/api/eval/test-key")
    }
    
    func testGetSSEUrl_usesStreamingHost() {
        // Act
        let url = contextManager.getSSEUrl()
        
        // Assert
        XCTAssertEqual(url, "https://streaming.test.com/sub/test-key")
    }
    
    func testGetSSEUrl_fallsBackToApiHost() {
        // Arrange
        let data = EvaluationData(
            streamingHost: nil,
            attributes: JSON(),
            forcedVariations: nil
        )
        let manager = ContextManager(globalConfig: globalConfig, evalData: data)
        
        // Act
        let url = manager.getSSEUrl()
        
        // Assert
        XCTAssertEqual(url, "https://test.com/sub/test-key")
    }
    
    // MARK: - Integration Tests
    
    func testFullWorkflow_updateAndSync() {
        // Arrange
        _ = contextManager.getEvalContext()
        
        // Act - update data
        contextManager.updateEvalData { data in
            data.features = ["feature1": Feature(defaultValue: JSON("value1"))]
            data.attributes = JSON(["id": "new-user"])
        }
        
        // Get new context
        let updatedContext = contextManager.getEvalContext()
        
        // Sync sticky bucket
        let doc = StickyAssignmentsDocument(
            attributeName: "id",
            attributeValue: "new-user",
            assignments: ["exp1": "var1"]
        )
        updatedContext.userContext.stickyBucketAssignmentDocs = ["id||new-user": doc]
        contextManager.syncFromEvaluation(updatedContext)
        
        // Assert
        let finalData = contextManager.getEvaluationData()
        XCTAssertEqual(finalData.features.count, 1)
        XCTAssertEqual(finalData.attributes["id"].stringValue, "new-user")
        XCTAssertNotNil(finalData.stickyBucketAssignmentDocs)
    }
}

