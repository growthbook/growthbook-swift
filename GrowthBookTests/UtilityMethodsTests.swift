import XCTest

@testable import GrowthBook

class UtilityMethodsTests: XCTestCase {

    private func makeSDK(clientKey: String = "utility-methods-test") -> GrowthBookSDK {
        let payload = """
        {
          "features": {
            "enabled-flag":  {"defaultValue": true},
            "disabled-flag": {"defaultValue": false},
            "int-flag":      {"defaultValue": 7}
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

    // MARK: - isOff

    func testIsOffForDisabledFeature() {
        let sdk = makeSDK()
        XCTAssertTrue(sdk.isOff(feature: "disabled-flag"))
        XCTAssertFalse(sdk.isOn(feature: "disabled-flag"))
    }

    func testIsOffForEnabledFeature() {
        let sdk = makeSDK()
        XCTAssertFalse(sdk.isOff(feature: "enabled-flag"))
        XCTAssertTrue(sdk.isOn(feature: "enabled-flag"))
    }

    func testIsOffMirrorsIsOn() {
        let sdk = makeSDK()
        for key in ["enabled-flag", "disabled-flag", "int-flag"] {
            XCTAssertEqual(sdk.isOff(feature: key), !sdk.isOn(feature: key), "isOff must be the negation of isOn for \(key)")
        }
    }

    // MARK: - getAllFeatureResults

    func testGetAllFeatureResultsCount() {
        let results = makeSDK().getAllFeatureResults()
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(Set(results.keys), ["enabled-flag", "disabled-flag", "int-flag"])
    }

    func testGetAllFeatureResultsValues() {
        let results = makeSDK().getAllFeatureResults()
        XCTAssertEqual(results["enabled-flag"]?.isOn, true)
        XCTAssertEqual(results["disabled-flag"]?.isOff, true)
        XCTAssertEqual(results["int-flag"]?.value?.int, 7)
    }

    func testGetAllFeatureResultsMatchesEvalFeature() {
        let sdk = makeSDK()
        let all = sdk.getAllFeatureResults()
        // Each aggregated result must match an individual evalFeature call.
        for key in all.keys {
            XCTAssertEqual(all[key]?.value, sdk.evalFeature(id: key).value)
            XCTAssertEqual(all[key]?.isOn, sdk.evalFeature(id: key).isOn)
        }
    }
}
