import Foundation

@testable import GrowthBook

class TestHelper {
    var testData: JSON? {
        get {
            loadTestData()
        }
    }

    func getEvalConditionData() -> [JSON]? {
        let array = testData?.dictionaryValue["evalCondition"]
        return array?.arrayValue
    }

    func getRunExperimentData() -> [JSON]? {
        let array = testData?.dictionaryValue["run"]
        return array?.arrayValue
    }

    func getFNVHashData() -> [JSON]? {
        let array = testData?.dictionaryValue["hash"]
        return array?.arrayValue
    }

    func getFeatureData() -> [JSON]? {
        let array = testData?.dictionaryValue["feature"]
        return array?.arrayValue
    }

    func getBucketRangeData() -> [JSON]? {
        let array = testData?.dictionaryValue["getBucketRange"]
        return array?.arrayValue
    }

    func getInNameSpaceData() -> [JSON]? {
        let array = testData?.dictionaryValue["inNamespace"]
        return array?.arrayValue
    }

    func getChooseVariationData() -> [JSON]? {
        let array = testData?.dictionaryValue["chooseVariation"]
        return array?.arrayValue
    }

    func getEqualWeightsData() -> [JSON]? {
        let array = testData?.dictionaryValue["getEqualWeights"] 
        return array?.arrayValue
    }
    
    func getDecryptData() -> [JSON]? {
        testData?.dictionaryValue["decrypt"]?.arrayValue
    }

    private func loadTestData() -> JSON? {
        let bundle = Bundle(for: type(of: self))
        guard
            let path = bundle.path(forResource: "json", ofType: "json"),
            let data = FileManager.default.contents(atPath: path)
        else { return nil }

        let test = try? JSON(data: data)

        return test
    }
}

struct ContextTest: Codable {
    var attributes: JSON = JSON()
    var isQaMode: Bool = false
    var isEnabled: Bool = true
    var forcedVariations: JSON? = nil

    init(json: [String: JSON]) {
        if let attributes = json["attributes"] {
            self.attributes = attributes
        }
        if let qaMode = json["qaMode"] {
            self.isQaMode = qaMode.boolValue
        }
        if let enabled = json["enabled"] {
            self.isEnabled = enabled.boolValue
        }
        if let forcedVariations = json["forcedVariations"] {
            self.forcedVariations = forcedVariations
        }
    }
}

struct FeaturesTest: Codable {
    var features: Features? = nil
    var attributes: JSON = JSON()

    init(json: [String: JSON]) {
        if let features = json["features"] {
            self.features = TestHelper.convertToFeaturesModel(dict: features.dictionaryValue)
        }
        if let attributes = json["attributes"] {
            self.attributes = attributes
        }
    }
}

class FeatureResultTest {
    let value: JSON
    let isOn: Bool
    let isOff: Bool
    let source: String
    var experiment: Experiment? = nil
    var experimentResult: ExperimentResultTest? = nil

    init(value: JSON, isOn: Bool, isOff: Bool, source: String, experiment: Experiment? = nil, experimentResult: ExperimentResultTest? = nil) {
        self.value = value
        self.isOn = isOn
        self.isOff = isOff
        self.source = source
        self.experiment = experiment
        self.experimentResult = experimentResult
    }

    init(json: [String: JSON]) {
        if let value = json["value"] {
            self.value = value
        } else {
            self.value = JSON()
        }
        if let on = json["on"] {
            self.isOn = on.boolValue
        } else {
            self.isOn = true
        }
        if let off = json["off"] {
            self.isOff = off.boolValue
        } else {
            self.isOff = false
        }
        if let source = json["source"] {
            self.source = source.stringValue
        } else {
            self.source = ""
        }
        if let experiment = json["experiment"] {
            self.experiment = Experiment(json: experiment.dictionaryValue)
        }
        if let experimentResult = json["experimentResult"] {
            self.experimentResult = ExperimentResultTest(json: experimentResult.dictionaryValue)
        }
    }
}

class ExperimentResultTest {
    /// Whether or not the user is part of the experiment
    let inExperiment: Bool
    /// The array index of the assigned variation
    let variationId: Int
    /// The array value of the assigned variation
    let value: JSON
    /// The user attribute used to assign a variation
    var hashAttribute: String? = nil
    ///  The value of that attribute
    var hashValue: String? = nil

    init(inExperiment: Bool, variationId: Int, value: JSON, hashAttribute: String? = nil, hashValue: String? = nil) {
        self.inExperiment = inExperiment
        self.variationId = variationId
        self.value = value
        self.hashAttribute = hashAttribute
        self.hashValue = hashValue
    }

    init(json: [String: JSON]) {
        if let inExperiment = json["inExperiment"] {
            self.inExperiment = inExperiment.boolValue
        } else {
            self.inExperiment = false
        }
        if let variationId = json["variationId"] {
            self.variationId = variationId.intValue
        } else {
            self.variationId = 0
        }
        if let value = json["value"] {
            self.value = value
        } else {
            self.value = JSON()
        }
        if let hashAttribute = json["hashAttribute"] {
            self.hashAttribute = hashAttribute.string
        }
        if let hashValue = json["hashValue"] {
            self.hashValue = hashValue.string
        }
    }
}

extension TestHelper {
    static func convertToFeaturesModel(dict: [String: JSON]) -> Features {
        var newDict: [String: Feature] = [:]
        if let feature = dict["feature"] {

            if let data = try? feature.rawData() {

                let decoder = JSONDecoder()

                if let jsonPetitions = try? decoder.decode(Feature.self, from: data) {
                    newDict["feature"] = jsonPetitions
                }
            }
        }
        return newDict
    }
}
