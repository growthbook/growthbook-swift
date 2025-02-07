import Foundation

internal class ExperimentHelper {
    static let shared = ExperimentHelper()
    
    private var trackedExperiments: Protected<Set<String>> = .init([])

    func isTracked(_ experiment: Experiment, _ result: ExperimentResult) -> Bool {
        let experimentKey = experiment.key
        
        let key = (result.hashAttribute ?? "") + String(result.valueHash ?? "") + experimentKey + String(result.variationId)

        let isTracked = trackedExperiments.write { trackedExperiments in
            if trackedExperiments.contains(key) { return true }

            trackedExperiments.insert(key)

            return false
        }

        return isTracked
    }
}
