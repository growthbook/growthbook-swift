import Foundation

/// Holds all registered plugins and dispatches lifecycle and evaluation events to each one.
///
/// Every dispatch method iterates the full plugin list so that a failure in one plugin
/// does not skip subsequent plugins. Add per-plugin error handling here as needed.
final class PluginRegistry {

    static let empty = PluginRegistry(plugins: [])

    private let plugins: [GrowthBookPlugin]

    init(plugins: [GrowthBookPlugin]) {
        self.plugins = plugins
    }

    func initialize(clientKey: String) {
        plugins.forEach { $0.initialize(clientKey: clientKey) }
    }

    func onExperimentViewed(experiment: Experiment, result: ExperimentResult) {
        plugins.forEach { $0.onExperimentViewed(experiment: experiment, result: result) }
    }

    func onFeatureEvaluated(featureKey: String, result: FeatureResult) {
        plugins.forEach { $0.onFeatureEvaluated(featureKey: featureKey, result: result) }
    }

    func close() {
        plugins.forEach { $0.close() }
    }
}
