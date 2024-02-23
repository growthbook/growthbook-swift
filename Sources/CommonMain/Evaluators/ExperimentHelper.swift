import Foundation

internal class ExperimentHelper {
    static let shared = ExperimentHelper()
    
    private var trackedExperiments: Set<String> = Set<String>()
    
    func isTracked(_ experiment: Experiment, _ result: ExperimentResult) -> Bool {
        let experimentKey = experiment.key
        
        let key = (result.hashAttribute ?? "") + String(result.valueHash ?? "") + experimentKey + String(result.variationId)

        if trackedExperiments.contains(key) { return true }
        
        trackedExperiments.insert(key)
        
        return false
    }
}
