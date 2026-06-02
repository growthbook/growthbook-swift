import Foundation

/// Holds all registered plugins and dispatches lifecycle and evaluation events to each one.
public final class PluginRegistry {

    public static let empty = PluginRegistry(plugins: [])

    private let plugins: [GrowthBookPlugin]

    public init(plugins: [GrowthBookPlugin]) {
        self.plugins = plugins
    }

    func initialize(clientKey: String) {
        for plugin in plugins { plugin.initialize(clientKey: clientKey) }
    }

    func onExperimentViewed(experiment: Experiment, result: ExperimentResult, attributes: JSON?) {
        for plugin in plugins { plugin.onExperimentViewed(experiment: experiment, result: result, attributes: attributes) }
    }

    func onFeatureEvaluated(featureKey: String, result: FeatureResult, attributes: JSON?) {
        for plugin in plugins { plugin.onFeatureEvaluated(featureKey: featureKey, result: result, attributes: attributes) }
    }

    func close() {
        for plugin in plugins { plugin.close() }
    }
}
