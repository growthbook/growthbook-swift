import Foundation

@testable import GrowthBook

class TestHelper {
    var testData: JSON? {
        get {
            loadTestData()
        }
    }
    
    func getStickyBucketingData() -> [JSON]? {
        let array = testData?.dictionaryValue["stickyBucket"]
        return array?.arrayValue
    }
    
    func getServerSideEvent() -> [JSON]? {
        let array = testData?.dictionaryValue["backgroundsync"]
        return array?.arrayValue
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
    var features: [String: Feature] = [:]
    var isQaMode: Bool = false
    var isEnabled: Bool = true
    var url: String? = nil
    var forcedVariations: JSON? = nil
    var savedGroups: JSON? = nil

    init(json: [String: JSON]) {
        if let attributes = json["attributes"] {
            self.attributes = attributes
        }
        if let url = json["url"] {
            self.url = url.stringValue
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
        if let features = try? json["features"]?.rawData() {
            if let features = try? JSONDecoder().decode(Features.self, from: features) {
                self.features = features
            }
        }
        if let savedGroups = json["savedGroups"] {
            self.savedGroups = savedGroups
        }
    }
}

struct FeaturesTest: Codable {
    var features: Features? = nil
    var attributes: JSON = JSON()
    var forcedVariations: JSON? = nil
    var savedGroups: JSON?
    var stickyBucketAssignmentDocs: [String: StickyAssignmentsDocument]? = nil

    init(json: [String: JSON], stickyBucketingJson: [JSON]? = nil) {
        if let features = json["features"] {
            self.features = TestHelper.convertToFeaturesModel(dict: features.dictionaryValue)
        }
        
        if let attributes = json["attributes"] {
            self.attributes = attributes
        }
        
        if let forcedVariations = json["forcedVariations"] {
            self.forcedVariations = forcedVariations
        }
        
        if let savedGroups = json["savedGroups"] {
            self.savedGroups = savedGroups
        }
        
        if let stickyBucketingJson = stickyBucketingJson {
            var docArray: [StickyAssignmentsDocument] = []
            var newDict: [String: StickyAssignmentsDocument] = [:]

            stickyBucketingJson.forEach { value in
                let doc = StickyAssignmentsDocument(attributeName: value.dictionaryValue["attributeName"]?.stringValue ?? "", attributeValue: value.dictionaryValue["attributeValue"]?.stringValue ?? "", assignments: value.dictionaryValue["assignments"]?.dictionaryValue ?? [:])
                docArray.append(doc)
            }
            
            docArray.forEach { value in
                let key = "\(value.attributeName)||\(value.attributeValue)"
                newDict[key] = value
            }
            
            self.stickyBucketAssignmentDocs = newDict
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
    let ruleId: String?

    init(value: JSON, isOn: Bool, isOff: Bool, source: String, experiment: Experiment? = nil, experimentResult: ExperimentResultTest? = nil, ruleId: String? = nil) {
        self.value = value
        self.isOn = isOn
        self.isOff = isOff
        self.source = source
        self.experiment = experiment
        self.experimentResult = experimentResult
        self.ruleId = ruleId
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
        if let ruleId = json["ruleId"] {
            self.ruleId = ruleId.stringValue
        } else {
            self.ruleId = ""
        }
    }
}

class ExperimentResultTest {
    /// Whether or not the user is part of the experiment
    let inExperiment: Bool?
    /// The array index of the assigned variation
    let variationId: Int?
    /// The array value of the assigned variation
    let value: JSON?
    /// The user attribute used to assign a variation
    let hashAttribute: String?
    /// The value of that attribute
    let hashValue: String?
    /// The unique key for the assigned variation
    let key: String?
    /// The human-readable name of the assigned variation
    var name: String?
    /// The hash value used to assign a variation (float from `0` to `1`)
    var bucket: Float?
    /// Used for holdout groups
    var passthrough: Bool?
    /// If a hash was used to assign a variation
    let hashUsed: Bool?
    /// The id of the feature (if any) that the experiment came from
    let featureId: String?
    /// If sticky bucketing was used to assign a variation
    let stickyBucketUsed: Bool?

    init(inExperiment: Bool,
         variationId: Int,
         value: JSON,
         hashAttribute: String? = nil,
         hashValue: String? = nil,
         key: String,
         name: String? = nil,
         bucket: Float? = nil,
         passthrough: Bool? = nil,
         hashUsed: Bool? = nil,
         featureId: String? = nil,
         stickyBucketUsed: Bool? = nil) {
        self.inExperiment = inExperiment
        self.variationId = variationId
        self.value = value
        self.hashAttribute = hashAttribute
        self.hashValue = hashValue
        self.key = key
        self.name = name
        self.bucket = bucket
        self.passthrough = passthrough
        self.hashUsed = hashUsed
        self.featureId = featureId
        self.stickyBucketUsed = stickyBucketUsed
    }
    
    init(json: [String: JSON]) {
        inExperiment = json["inExperiment"]?.boolValue
        variationId = json["variationId"]?.intValue
        value = json["value"]
        hashAttribute = json["hashAttribute"]?.stringValue
        hashValue = json["hashValue"]?.stringValue
        key = json["key"]?.stringValue
        name = json["name"]?.stringValue
        bucket = json["bucket"]?.floatValue
        passthrough = json["passthrough"]?.boolValue
        hashUsed = json["hashUsed"]?.boolValue
        featureId = json["featureId"]?.stringValue
        stickyBucketUsed = json["stickyBucketUsed"]?.boolValue
    }
}

extension TestHelper {
    static func convertToFeaturesModel(dict: [String: JSON]) -> Features {
        var newDict: [String: Feature] = [:]
        
        dict.forEach { (key, value) in
            newDict[key] = Feature(json: value.dictionaryValue)
        }
        
        return newDict
    }
}
