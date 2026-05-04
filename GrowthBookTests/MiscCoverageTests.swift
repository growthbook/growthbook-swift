import XCTest
@testable import GrowthBook

// MARK: - FeaturesDataModel

class FeaturesDataModelTests: XCTestCase {

    func testInitWithAllFields() {
        let model = FeaturesDataModel(
            features: ["flag": Feature(defaultValue: JSON(true))],
            encryptedFeatures: "enc-features",
            dateUpdated: "2024-01-01",
            savedGroups: JSON(["group": ["a", "b"]]),
            encryptedSavedGroups: "enc-groups",
            experiments: [],
            encryptedExperiments: "enc-exp"
        )
        XCTAssertNotNil(model.features)
        XCTAssertEqual(model.encryptedFeatures, "enc-features")
        XCTAssertEqual(model.dateUpdated, "2024-01-01")
        XCTAssertNotNil(model.savedGroups)
        XCTAssertEqual(model.encryptedSavedGroups, "enc-groups")
        XCTAssertNotNil(model.experiments)
        XCTAssertEqual(model.encryptedExperiments, "enc-exp")
    }

    func testDefaultInit() {
        let model = FeaturesDataModel()
        XCTAssertNil(model.features)
        XCTAssertNil(model.encryptedFeatures)
        XCTAssertNil(model.savedGroups)
    }

    func testCodableDecode() throws {
        let json = """
        {"features":{"flag":{"defaultValue":true}},"dateUpdated":"2024-01-01","savedGroups":{"g":["1","2"]}}
        """.data(using: .utf8)!
        let model = try JSONDecoder().decode(FeaturesDataModel.self, from: json)
        XCTAssertNotNil(model.features?["flag"])
        XCTAssertEqual(model.dateUpdated, "2024-01-01")
        XCTAssertNotNil(model.savedGroups)
    }
}

// MARK: - StickyAssignmentsDocument JSON init

class StickyAssignmentsDocumentJsonInitTests: XCTestCase {

    func testInitWithJsonAssignments() {
        let jsonAssignments: [String: JSON] = [
            "exp__0": JSON("control"),
            "exp2__0": JSON("variant")
        ]
        let doc = StickyAssignmentsDocument(
            attributeName: "id",
            attributeValue: "user-1",
            assignments: jsonAssignments
        )
        XCTAssertEqual(doc.attributeName, "id")
        XCTAssertEqual(doc.attributeValue, "user-1")
        XCTAssertEqual(doc.assignments["exp__0"], "control")
        XCTAssertEqual(doc.assignments["exp2__0"], "variant")
    }

    func testInitWithJsonAssignmentsEmpty() {
        let doc = StickyAssignmentsDocument(
            attributeName: "id",
            attributeValue: "u",
            assignments: [String: JSON]()
        )
        XCTAssertTrue(doc.assignments.isEmpty)
    }

    func testInitWithJsonAssignmentsBoolValue() {
        let jsonAssignments: [String: JSON] = ["flag__0": JSON(true)]
        let doc = StickyAssignmentsDocument(
            attributeName: "id",
            attributeValue: "u",
            assignments: jsonAssignments
        )
        XCTAssertEqual(doc.assignments["flag__0"], "true")
    }
}

// MARK: - Context URL methods

class ContextURLTests: XCTestCase {

    private func makeContext(apiHost: String? = "https://cdn.growthbook.io", clientKey: String? = "sdk-key", streamingHost: String? = nil) -> Context {
        Context(
            apiHost: apiHost,
            streamingHost: streamingHost,
            clientKey: clientKey,
            encryptionKey: nil,
            isEnabled: true,
            attributes: JSON([:]),
            forcedVariations: nil,
            isQaMode: false,
            trackingClosure: { _, _ in }
        )
    }

    // getFeaturesURL

    func testGetFeaturesURLWithValidValues() {
        let ctx = makeContext()
        XCTAssertEqual(ctx.getFeaturesURL(), "https://cdn.growthbook.io/api/features/sdk-key")
    }

    func testGetFeaturesURLNilApiHost() {
        let ctx = makeContext(apiHost: nil)
        XCTAssertNil(ctx.getFeaturesURL())
    }

    func testGetFeaturesURLNilClientKey() {
        let ctx = makeContext(clientKey: nil)
        XCTAssertNil(ctx.getFeaturesURL())
    }

    // getRemoteEvalUrl

    func testGetRemoteEvalUrlWithValidValues() {
        let ctx = makeContext()
        XCTAssertEqual(ctx.getRemoteEvalUrl(), "https://cdn.growthbook.io/api/eval/sdk-key")
    }

    func testGetRemoteEvalUrlNilApiHost() {
        XCTAssertNil(makeContext(apiHost: nil).getRemoteEvalUrl())
    }

    func testGetRemoteEvalUrlNilClientKey() {
        XCTAssertNil(makeContext(clientKey: nil).getRemoteEvalUrl())
    }

    // getSSEUrl

    func testGetSSEUrlUsesStreamingHostWhenSet() {
        let ctx = makeContext(streamingHost: "https://streaming.growthbook.io")
        XCTAssertEqual(ctx.getSSEUrl(), "https://streaming.growthbook.io/sub/sdk-key")
    }

    func testGetSSEUrlFallsBackToApiHost() {
        let ctx = makeContext()
        XCTAssertEqual(ctx.getSSEUrl(), "https://cdn.growthbook.io/sub/sdk-key")
    }

    func testGetSSEUrlNilBothHosts() {
        let ctx = makeContext(apiHost: nil)
        XCTAssertNil(ctx.getSSEUrl())
    }

    func testGetSSEUrlNilClientKey() {
        XCTAssertNil(makeContext(clientKey: nil).getSSEUrl())
    }
}

// MARK: - Formatter

class FormatterTests: XCTestCase {

    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private func callFormat(components: [Component], format: String = "%@") -> String {
        let formatter = Formatter(format, components)
        return formatter.format(
            level: .info,
            items: ["hello"],
            separator: " ",
            terminator: "",
            file: "/path/to/MyFile.swift",
            line: 42,
            column: 5,
            function: "testFunc()",
            date: date
        )
    }

    // MARK: Components in log format

    func testMessageComponent() {
        let result = callFormat(components: [.message])
        XCTAssertEqual(result, "hello")
    }

    func testLevelComponent() {
        let result = callFormat(components: [.level])
        XCTAssertTrue(result.lowercased().contains("info"))
    }

    func testLineComponent() {
        let result = callFormat(components: [.line])
        XCTAssertEqual(result, "42")
    }

    func testColumnComponent() {
        let result = callFormat(components: [.column])
        XCTAssertEqual(result, "5")
    }

    func testFunctionComponent() {
        let result = callFormat(components: [.function])
        XCTAssertEqual(result, "testFunc()")
    }

    func testDateComponent() {
        let result = callFormat(components: [.date("yyyy")])
        XCTAssertFalse(result.isEmpty)
    }

    func testLocationComponent() {
        let result = callFormat(components: [.location])
        XCTAssertTrue(result.contains("MyFile.swift"))
        XCTAssertTrue(result.contains("42"))
    }

    func testFileFullPathWithExtension() {
        let result = callFormat(components: [.file(fullPath: true, fileExtension: true)])
        XCTAssertTrue(result.contains("/path/to/MyFile.swift"))
    }

    func testFileShortNameNoExtension() {
        let result = callFormat(components: [.file(fullPath: false, fileExtension: false)])
        XCTAssertEqual(result, "MyFile")
    }

    func testFileShortNameWithExtension() {
        let result = callFormat(components: [.file(fullPath: false, fileExtension: true)])
        XCTAssertEqual(result, "MyFile.swift")
    }

    func testBlockComponentReturnsValue() {
        let result = callFormat(components: [.block({ "block-value" })])
        XCTAssertEqual(result, "block-value")
    }

    func testBlockComponentReturnsNilFallback() {
        let result = callFormat(components: [.block({ nil })])
        XCTAssertEqual(result, "")
    }

    func testMultipleItemsSeparator() {
        let formatter = Formatter("%@", [.message])
        let result = formatter.format(
            level: .debug,
            items: ["a", "b", "c"],
            separator: "-",
            terminator: "",
            file: "f.swift",
            line: 1,
            column: 1,
            function: "f()",
            date: date
        )
        XCTAssertEqual(result, "a-b-c")
    }

    func testTerminatorAppended() {
        let formatter = Formatter("%@", [.message])
        let result = formatter.format(
            level: .debug,
            items: ["msg"],
            separator: " ",
            terminator: "\n",
            file: "f.swift",
            line: 1,
            column: 1,
            function: "f()",
            date: date
        )
        XCTAssertTrue(result.hasSuffix("\n"))
    }

    // MARK: measure format overload

    func testMeasureFormatAllComponents() {
        let formatter = Formatter("%@ %@ %@ %@ %@ %@", [
            .date("yyyy"),
            .file(fullPath: false, fileExtension: false),
            .function,
            .line,
            .level,
            .message
        ])
        let result = formatter.format(
            description: "my-measure",
            average: 0.123,
            relativeStandardDeviation: 5.0,
            file: "/path/to/File.swift",
            line: 10,
            column: 1,
            function: "myFunc()",
            date: date
        )
        XCTAssertTrue(result.contains("0.123"))
        XCTAssertTrue(result.contains("STDEV"))
        XCTAssertTrue(result.contains("MEASURE"))
    }

    func testMeasureFormatLocationAndBlockComponents() {
        let formatter = Formatter("%@ %@", [
            .location,
            .block({ "extra" })
        ])
        let result = formatter.format(
            description: nil,
            average: 1.0,
            relativeStandardDeviation: 0.5,
            file: "/path/to/File.swift",
            line: 5,
            column: 1,
            function: "f()",
            date: date
        )
        XCTAssertTrue(result.contains("File.swift:5"))
        XCTAssertTrue(result.contains("extra"))
    }

    // MARK: description property

    func testDescriptionProperty() {
        let formatter = Formatter("[%@] %@", [.level, .message])
        let desc = formatter.description
        XCTAssertTrue(desc.contains("LEVEL"))
        XCTAssertTrue(desc.contains("MESSAGE"))
    }

    // MARK: Predefined formatters

    func testDefaultFormatterProducesOutput() {
        let result = Formatters.default.format(
            level: .warning,
            items: ["test"],
            separator: " ",
            terminator: "",
            file: "F.swift",
            line: 1,
            column: 1,
            function: "f()",
            date: date
        )
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.lowercased().contains("warning") || result.contains("WARNING"))
    }

    func testMinimalFormatterProducesOutput() {
        let result = Formatters.minimal.format(
            level: .error,
            items: ["err"],
            separator: " ",
            terminator: "",
            file: "F.swift",
            line: 1,
            column: 1,
            function: "f()",
            date: date
        )
        XCTAssertTrue(result.contains("err"))
    }

    func testDetailedFormatterProducesOutput() {
        let result = Formatters.detailed.format(
            level: .debug,
            items: ["detail"],
            separator: " ",
            terminator: "",
            file: "/path/F.swift",
            line: 99,
            column: 1,
            function: "myFunc()",
            date: date
        )
        XCTAssertTrue(result.contains("detail"))
        XCTAssertTrue(result.contains("99"))
    }
}
