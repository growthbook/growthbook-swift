import Foundation

internal class ExperimentHelper {
    static let shared = ExperimentHelper()
    
    private var trackedExperiments: Set<String> = Set<String>()
    private let queue = DispatchQueue(label: "experimentHelper.queue")
    
    func isTracked(_ experiment: Experiment, _ result: ExperimentResult) -> Bool {
        let experimentKey = experiment.key
        
        let key = (result.hashAttribute ?? "") + String(result.valueHash ?? "") + experimentKey + String(result.variationId)

        return queue.sync {
    
            if trackedExperiments.contains(key) { return true }
            
            trackedExperiments.insert(key)
            
            return false
        }
    }
}
