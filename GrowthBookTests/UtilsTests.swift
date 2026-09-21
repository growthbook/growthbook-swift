import XCTest

@testable import GrowthBook

class UtilsTests: XCTestCase {
    
    func testHash() throws {
        guard let evalConditions = TestHelper().getFNVHashData() else { return }
        var failedScenarios: [String] = []
        var passedScenarios: [String] = []
        for item in evalConditions {
            let seed = item.arrayValue[0].stringValue
            let testContext = item.arrayValue[1].stringValue//jsonPrimitive.content
            let hashVersion = item.arrayValue[2].floatValue
            let experiment = item.arrayValue[3].floatValue
            
            let result = Utils.hash(seed: seed, value: testContext, version: hashVersion) ?? 0.0
                        
            let status = item[0].stringValue + "\nExpected Result - " + item[3].stringValue + "\nActual result - " + String(result) + "\n"
                        
            if experiment == result {
                passedScenarios.append(status)
            } else {
                failedScenarios.append(status)
            }
        }
        
        logger.info("TOTAL TESTS - \(evalConditions.count)")
        logger.info("Passed TESTS - \(passedScenarios.count)")
        logger.info("Failed TESTS - \(failedScenarios.count)")
        
        XCTAssertTrue(failedScenarios.count == 0)
    }
    
    func testBucketRange() throws {
        guard let evalConditions = TestHelper().getBucketRangeData() else { return }
        var failedScenarios: [String] = []
        var passedScenarios: [String] = []
        for item in evalConditions {
            let numVariations = item.arrayValue[1].arrayValue[0].int
            let coverage = item.arrayValue[1].arrayValue[1].float
            var weights: [Float]? = nil
            if item.arrayValue[1].arrayValue[2] != JSON.null {
                weights = JSON.convertToArrayString(jsonArray: item.arrayValue[1].arrayValue[2].arrayValue).map({ value in
                    Float(value) ?? 0.0
                })
            }
            
            let bucketRange = Utils.getBucketRanges(numVariations: numVariations ?? 1, coverage: coverage ?? 1, weights: weights ?? [])
            
            
            let status = "\(item.arrayValue[0].stringValue) \nExpected Result - \(item.arrayValue[2].stringValue) \nActual result - \(JSON(bucketRange).stringValue) \n"
            
            if isCompareBucket(expectedResults: JSON.convertToTwoArrayFloat(jsonArray: item.arrayValue[2].arrayValue), calculatedResults: bucketRange) {
                passedScenarios.append(status)
            } else {
                failedScenarios.append(status)
            }
        }
        
        logger.info("TOTAL TESTS - \(evalConditions.count)")
        logger.info("Passed TESTS - \(passedScenarios.count)")
        logger.info("Failed TESTS - \(failedScenarios.count)")
        
        XCTAssertTrue(failedScenarios.count == 0)
    }
    
    func isCompareBucket(expectedResults: [[Float]], calculatedResults: [BucketRange]) -> Bool {
        let pairExpectedResults = getPairedData(items: expectedResults)
        
        if pairExpectedResults.count != expectedResults.count {
            return false
        }
        
        var result = true
        for i in 0..<pairExpectedResults.count {
            let source = pairExpectedResults[i]
            let target = calculatedResults[i]
            
            if (source.number1 != target.number1 || source.number2 != target.number2) {
                result = false
                break
            }
        }
        
        return result
    }
    
    func getPairedData(items: [[Float]]) -> [BucketRange] {
        var pairExpectedResults: [BucketRange] = []
        
        for item in items {
            let pair = (item[0], item[1])
            pairExpectedResults.append(BucketRange(number1: pair.0, number2: pair.1))
        }
        return pairExpectedResults
    }
    
    func testChooseVariation() throws {
        guard let evalConditions = TestHelper().getChooseVariationData() else { return }
        var failedScenarios: [String] = []
        var passedScenarios: [String] = []
        for item in evalConditions {
            let hash = item.arrayValue[1].float
            let rangeData = getPairedData(items: JSON.convertToTwoArrayFloat(jsonArray: item.arrayValue[2].arrayValue))
            
            let result = Utils.chooseVariation(n: hash ?? 0, ranges: rangeData)
            
            let status = item.arrayValue[0].stringValue + "\nExpected Result - " + item.arrayValue[3].stringValue + "\nActual result - " + String(result) + "\n"
            
            if item.arrayValue[3].stringValue == String(result) {
                passedScenarios.append(status)
            } else {
                failedScenarios.append(status)
            }
        }
        
        logger.info("TOTAL TESTS - \(evalConditions.count)")
        logger.info("Passed TESTS - \(passedScenarios.count)")
        logger.info("Failed TESTS - \(failedScenarios.count)")
        
        XCTAssertTrue(failedScenarios.count == 0)
    }
    
    func testInNameSpace() throws {
        guard let evalConditions = TestHelper().getInNameSpaceData() else { return }
        var failedScenarios: [String] = []
        var passedScenarios: [String] = []
        for item in evalConditions {
            let userId = item.arrayValue[1].stringValue
            let jsonArray = item.arrayValue[2].arrayValue
            guard let namespace = Utils.getGBNameSpace(namespace: jsonArray) else { continue }
            
            let result = Utils.inNamespace(userId: userId, namespace: namespace)
            
            let status = item.arrayValue[0].stringValue + "\nExpected Result - " + item.arrayValue[3].stringValue + "\nActual result - " + String(result) + "\n"
            
            
            if item.arrayValue[3].stringValue == String(result) {
                passedScenarios.append(status)
            } else {
                failedScenarios.append(status)
            }
        }
        
        logger.info("TOTAL TESTS - \(evalConditions.count)")
        logger.info("Passed TESTS - \(passedScenarios.count)")
        logger.info("Failed TESTS - \(failedScenarios.count)")
        
        XCTAssertTrue(failedScenarios.count == 0)
    }
    
    func testEqualWeights() throws {
        guard let evalConditions = TestHelper().getEqualWeightsData() else { return }
        var failedScenarios: [String] = []
        var passedScenarios: [String] = []
        for item in evalConditions {
            
            let numVariations = item.arrayValue[0].intValue
            
            let result = Utils.getEqualWeights(numVariations: numVariations)
            
            let status =  "Expected Result - \(item.arrayValue[1].stringValue) \nActual result - \(result) \n"
            
            var resultTest = true
            
            if item.arrayValue[1].arrayValue.count != result.count {
                resultTest = false
            } else {
                for i in 0..<result.count {
                    let source = item.arrayValue[1].arrayValue[i].floatValue
                    let target = result[i]
                    
                    if source != target {
                        resultTest = false
                        break
                    }
                }
            }
            
            if resultTest {
                passedScenarios.append(status)
            } else {
                failedScenarios.append(status)
            }
        }
        
        logger.info("TOTAL TESTS - \(evalConditions.count)")
        logger.info("Passed TESTS - \(passedScenarios.count)")
        logger.info("Failed TESTS - \(failedScenarios.count)")
        
        XCTAssertTrue(failedScenarios.count == 0)
    }
    
    func testEdgeCases() throws {
        XCTAssertFalse(Utils.inNamespace(userId: "4242", namespace: NameSpace("", 0.0, 0.0)))
        
        var items = [JSON]()
        items.append(JSON(1))
        
        XCTAssertTrue(Utils.getGBNameSpace(namespace: items) == nil)
    }
    
    func testPaddedVersionString() throws {
        let startValue = "v1.2.3-rc.1+build123"
        let expectedValue = "    1-    2-    3-rc-    1"
        let endValue = Utils.paddedVersionString(input: startValue)

        XCTAssertEqual(endValue, expectedValue)
    }

    /// Numeric parts wider than the padding target used to trap in `String(repeating:count:)`
    func testPaddedVersionStringWithOversizedNumericParts() throws {
        XCTAssertEqual(Utils.paddedVersionString(input: "123456789"), "123456789")
        XCTAssertEqual(Utils.paddedVersionString(input: "10222.1.1"), "10222-    1-    1-~")
        XCTAssertEqual(Utils.paddedVersionString(input: "20260910.1.0-rc.123456"), "20260910-    1-    0-rc-123456")
    }

    /// Only a leading `v` is stripped - a `v` inside a pre-release tag must survive
    func testPaddedVersionStringKeepsInnerLetterV() throws {
        XCTAssertEqual(Utils.paddedVersionString(input: "1.2.3-dev"), "    1-    2-    3-dev")
        XCTAssertEqual(Utils.paddedVersionString(input: "1.0.0-alpha.v1"), "    1-    0-    0-alpha-v1")
    }

    /// Empty parts are kept, so the part count (and the `~` suffix) matches the other SDKs
    func testPaddedVersionStringKeepsEmptyParts() throws {
        XCTAssertEqual(Utils.paddedVersionString(input: "1..2"), "    1--    2-~")
        XCTAssertEqual(Utils.paddedVersionString(input: "-1.2.3"), "-    1-    2-    3")
    }

    /// Non-ASCII digits are pre-release tags, not numbers
    func testPaddedVersionStringDoesNotPadNonAsciiDigits() throws {
        XCTAssertEqual(Utils.paddedVersionString(input: "1.2.3-٣"), "    1-    2-    3-٣")
    }

    func testPaddedVersionStringCoercesNonStringValues() throws {
        XCTAssertEqual(Utils.paddedVersionString(input: JSON(2)), "    2")
        XCTAssertEqual(Utils.paddedVersionString(input: JSON(1.5)), "    1-    5")
        XCTAssertEqual(Utils.paddedVersionString(input: JSON("1.2.3")), "    1-    2-    3-~")
        XCTAssertEqual(Utils.paddedVersionString(input: JSON("")), "    0")
        XCTAssertEqual(Utils.paddedVersionString(input: JSON(true)), "    0")
        XCTAssertEqual(Utils.paddedVersionString(input: JSON.null), "    0")
        XCTAssertEqual(Utils.paddedVersionString(input: JSON([1, 2])), "    0")
    }

    /// `JSON` is ExpressibleByStringLiteral, so a bare string literal binds to the `String`
    /// overload rather than the JSON one. The two must agree, or a caller gets a different answer
    /// depending on a type inference they never see.
    func testPaddedVersionStringOverloadsAgreeOnTheEmptyString() throws {
        let fromString = Utils.paddedVersionString(input: "")
        XCTAssertEqual(fromString, "    0", "An empty version string is \"0\", as in the JS reference")
        XCTAssertEqual(fromString, Utils.paddedVersionString(input: JSON("")))
    }

    /// A numeric part at or beyond the target width is returned unchanged rather than trapping on
    /// a negative repeat count. Kept next to the padding itself so the guard cannot drift away
    /// from the subtraction it protects, which is how the original crash arose.
    func testPaddedVersionStringDoesNotTrapOnOversizedSegments() throws {
        XCTAssertEqual(Utils.paddedVersionString(input: "12345"), "12345")
        XCTAssertEqual(Utils.paddedVersionString(input: "123456"), "123456")
        XCTAssertEqual(Utils.paddedVersionString(input: "20260910.1.0"), "20260910-    1-    0-~")
    }
    
    func testDecrypt() throws {
        guard let testCases = TestHelper().getDecryptData() else { return }
        
        for jsonElement in testCases {
            guard let test = jsonElement.arrayObject,
                  let payload = test[1] as? String,
                  let key = test[2] as? String else {
                continue
            }
            let expectedElem = test[3]
            
            do {
                if let expected = test[3] as? String {
                    let actual = try DecryptionUtils.decrypt(payload: payload, encryptionKey: key).trimmingCharacters(in: .whitespacesAndNewlines)
                    XCTAssertEqual(expected, actual)
                }
            } catch let error as DecryptionException {
                print("message \(error.errorMessage)")
                
                if expectedElem is NSNull {
                    XCTAssertTrue(true)
                }
            } catch {
                XCTFail("An unexpected error occurred: \(error)")
            }
        }
    }
    
}
