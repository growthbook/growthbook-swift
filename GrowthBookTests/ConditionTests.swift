import XCTest

@testable import GrowthBook

class ConditionTests: XCTestCase {

    var evalConditions: [JSON]?

    override func setUp() {
        evalConditions = TestHelper().getEvalConditionData()
    }

    func testConditions() throws {
        guard let evalConditions = evalConditions else { return }
        var failedScenarios: [String] = []
        var passedScenarios: [String] = []

        for item in evalConditions {
            let evaluator = ConditionEvaluator()
            
            let result = evaluator.isEvalCondition(attributes: item[2], conditionObj: item[1])

            let status = item.arrayValue[0].stringValue + "\nExpected Result - " + item.arrayValue[3].stringValue + "\nActual result - " + String(result) + "\n\n"

            if item[3].boolValue == result {
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

    func testInValidConditionObj() throws {
        let evaluator = ConditionEvaluator()

        XCTAssertFalse(evaluator.isEvalCondition(attributes: JSON(), conditionObj: [JSON()]))

        XCTAssertFalse(evaluator.isOperatorObject(obj: JSON([:])))

        XCTAssertTrue(evaluator.getType(obj: nil) == AttributeType.gbUnknown.rawValue)

        XCTAssertTrue(evaluator.getPath(obj: JSON("test"), key: "key") == nil)

        XCTAssertTrue(evaluator.isEvalConditionValue(conditionValue: JSON([:]), attributeValue: nil) == false)

        XCTAssertTrue(evaluator.isEvalOperatorCondition(operatorKey: "$lte", attributeValue: JSON("abc"), conditionValue: JSON("abc")))

        XCTAssertTrue(evaluator.isEvalOperatorCondition(operatorKey: "$gte", attributeValue: JSON("abc"), conditionValue: JSON("abc")))
        
        XCTAssertTrue(evaluator.isEvalOperatorCondition(operatorKey: "$vlt", attributeValue: "0.9.0", conditionValue: "0.10.0"))
        
        XCTAssertTrue(evaluator.isEvalOperatorCondition(operatorKey: "$in", attributeValue: JSON("abc"), conditionValue: [JSON("abc")]))
        
        XCTAssertFalse(evaluator.isEvalOperatorCondition(operatorKey: "$nin", attributeValue: JSON("abc"), conditionValue: [JSON("abc")]))
    }

    func testConditionFailAttributeDoesNotExist() throws {
        let attributes = """
                     {"country":"IN"}
                 """.trimmingCharacters(in: .whitespaces)

        let condition = """
                     {"brand":"KZ"}
                 """.trimmingCharacters(in: .whitespaces)

        XCTAssertEqual(false, ConditionEvaluator().isEvalCondition(attributes: JSON(parseJSON: attributes), conditionObj: JSON(parseJSON: condition)))
    }

    func testConditionDoesNotExistAttributeExist() throws {
        let attributes = """
                    {"userId":"1199"}
                  """.trimmingCharacters(in: .whitespaces)

        let condition = """
                     {
                       "userId": {
                         "$exists": false
                       }
                     }
                 """.trimmingCharacters(in: .whitespaces)

        XCTAssertEqual(false, ConditionEvaluator().isEvalCondition(attributes: JSON(parseJSON: attributes), conditionObj: JSON(parseJSON: condition)))
    }

    func testConditionExistAttributeExist() throws {
        let attributes = """
                     {"userId":"1199"}
                 """.trimmingCharacters(in: .whitespaces)

        let condition = """
                     {
                       "userId": {
                         "$exists": true
                       }
                     }
                 """.trimmingCharacters(in: .whitespaces)

        XCTAssertEqual(true, ConditionEvaluator().isEvalCondition(attributes: JSON(parseJSON: attributes), conditionObj: JSON(parseJSON: condition)))
    }

    func testConditionExistAttributeDoesNotExist() throws {
        let attributes = """
                     {"user_id_not_exist":"1199"}
                 """.trimmingCharacters(in: .whitespaces)

        let condition = """
                     {
                       "userId": {
                         "${'$'}exists": true
                       }
                     }
                 """.trimmingCharacters(in: .whitespaces)

        XCTAssertEqual(false, ConditionEvaluator().isEvalCondition(attributes: JSON(parseJSON: attributes), conditionObj: JSON(parseJSON: condition)))
    }
}
