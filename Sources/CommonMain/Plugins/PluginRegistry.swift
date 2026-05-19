import Foundation

/// Holds all registered plugins and dispatches lifecycle and evaluation events to each one.
///
/// Every dispatch method iterates the full plugin list so that a failure in one plugin
/// does not skip subsequent plugins. Add per-plugin error handling here as needed.
public final class PluginRegistry {

    public static let empty = PluginRegistry(plugins: [])

    private let plugins: [GrowthBookPlugin]

    public init(plugins: [GrowthBookPlugin]) {
        self.plugins = plugins
    }

    func initialize(clientKey: String) {
        plugins.forEach { $0.initialize(clientKey: clientKey) }
    }

    func onExperimentViewed(experiment: Experiment, result: ExperimentResult, attributes: JSON?) {
        plugins.forEach { $0.onExperimentViewed(experiment: experiment, result: result, attributes: attributes) }
    }

    func onFeatureEvaluated(featureKey: String, result: FeatureResult, attributes: JSON?) {
        plugins.forEach { $0.onFeatureEvaluated(featureKey: featureKey, result: result, attributes: attributes) }
    }

    func close() {
        plugins.forEach { $0.close() }
    }
}
