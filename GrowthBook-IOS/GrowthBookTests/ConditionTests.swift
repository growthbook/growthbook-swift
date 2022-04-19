import XCTest
import SwiftyJSON
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
    }
}
