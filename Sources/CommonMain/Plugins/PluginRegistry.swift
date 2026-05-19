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
        for plugin in plugins {
            safeCall(plugin, "initialize") { $0.initialize(clientKey: clientKey) }
        }
    }

    func onExperimentViewed(experiment: Experiment, result: ExperimentResult, attributes: JSON?) {
        for plugin in plugins {
            safeCall(plugin, "onExperimentViewed") { $0.onExperimentViewed(experiment: experiment, result: result, attributes: attributes) }
        }
    }

    func onFeatureEvaluated(featureKey: String, result: FeatureResult, attributes: JSON?) {
        for plugin in plugins {
            safeCall(plugin, "onFeatureEvaluated") { $0.onFeatureEvaluated(featureKey: featureKey, result: result, attributes: attributes) }
        }
    }

    func close() {
        for plugin in plugins {
            safeCall(plugin, "close") { $0.close() }
        }
    }

    private func safeCall(_ plugin: GrowthBookPlugin, _ method: String, _ block: (GrowthBookPlugin) -> Void) {
        block(plugin)
    }
}
