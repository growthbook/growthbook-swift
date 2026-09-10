import XCTest

@testable import GrowthBook

class TypedFeatureValueTests: XCTestCase {

    private struct PaymentConfig: Decodable, Equatable {
        let provider: String
        let retries: Int
    }

    /// Builds an offline SDK from a preloaded features payload (no network).
    private func makeSDK(clientKey: String = "typed-value-test") -> GrowthBookSDK {
        let payload = """
        {
          "features": {
            "int-flag":    {"defaultValue": 42},
            "string-flag": {"defaultValue": "hello"},
            "bool-flag":   {"defaultValue": true},
            "double-flag": {"defaultValue": 3.5},
            "object-flag": {"defaultValue": {"provider": "stripe", "retries": 3}},
            "array-flag":  {"defaultValue": ["a", "b", "c"]}
          }
        }
        """.data(using: .utf8)!

        return GrowthBookBuilder(
            apiHost: "https://example.com",
            clientKey: clientKey,
            attributes: [:],
            features: payload,
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: nil, error: nil))
        .initializer()
    }

    // MARK: - Primitive overloads

    func testInt() {
        XCTAssertEqual(makeSDK().getFeatureValue(feature: "int-flag", as: Int.self, default: 0), 42)
    }

    func testString() {
        XCTAssertEqual(makeSDK().getFeatureValue(feature: "string-flag", as: String.self, default: ""), "hello")
    }

    func testBool() {
        XCTAssertTrue(makeSDK().getFeatureValue(feature: "bool-flag", as: Bool.self, default: false))
    }

    func testDouble() {
        XCTAssertEqual(makeSDK().getFeatureValue(feature: "double-flag", as: Double.self, default: 0), 3.5)
    }

    // MARK: - Generic Decodable overload

    func testDecodableObject() {
        let cfg = makeSDK().getFeatureValue(
            feature: "object-flag",
            as: PaymentConfig.self,
            default: PaymentConfig(provider: "none", retries: 0)
        )
        XCTAssertEqual(cfg, PaymentConfig(provider: "stripe", retries: 3))
    }

    func testDecodableArray() {
        let arr = makeSDK().getFeatureValue(feature: "array-flag", as: [String].self, default: [])
        XCTAssertEqual(arr, ["a", "b", "c"])
    }

    // MARK: - Fallbacks

    func testMissingFeatureReturnsDefault() {
        XCTAssertEqual(makeSDK().getFeatureValue(feature: "nope", as: Int.self, default: 99), 99)
    }

    func testTypeMismatchReturnsDefault() {
        // "string-flag" holds a String; asking for Int must fall back to the default.
        XCTAssertEqual(makeSDK().getFeatureValue(feature: "string-flag", as: Int.self, default: -1), -1)
    }

    func testDecodableMismatchReturnsDefault() {
        // "int-flag" is a scalar; decoding into a struct must fall back to the default.
        let fallback = PaymentConfig(provider: "fallback", retries: -1)
        let cfg = makeSDK().getFeatureValue(feature: "int-flag", as: PaymentConfig.self, default: fallback)
        XCTAssertEqual(cfg, fallback)
    }

    // MARK: - Backward compatibility

    func testLegacyJSONOverloadStillWorks() {
        // The original JSON-returning API must remain unchanged.
        let value = makeSDK().getFeatureValue(feature: "int-flag", default: JSON(0))
        XCTAssertEqual(value.int, 42)
    }
}
