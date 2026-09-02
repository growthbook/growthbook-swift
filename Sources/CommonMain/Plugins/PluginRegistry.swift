import Foundation

/// Holds all registered plugins and dispatches lifecycle and evaluation events to each one.
///
/// The registry itself owns no mutable state — the plugin list is fixed at init — which is what
/// makes the shared `empty` instance safe and lets the type carry `@unchecked Sendable`. The
/// conformance says nothing about the plugins themselves: the SDK calls them from whichever thread
/// applied an update or ran an experiment, so a plugin that keeps state has to guard it, exactly as
/// `GrowthBookTrackingPlugin` does with its own queue.
public final class PluginRegistry: @unchecked Sendable {

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
