import Foundation

/// Holds all registered plugins and dispatches lifecycle and evaluation events to each one.
public final class PluginRegistry {

    public static let empty = PluginRegistry(plugins: [])

    private let plugins: [GrowthBookPlugin]

    /// Guards `isClosed` only. Plugins are called outside it, so a plugin that blocks on a network
    /// request cannot stall an unrelated evaluation.
    private let lock = NSLock()
    private var isClosed = false

    public init(plugins: [GrowthBookPlugin]) {
        self.plugins = plugins
    }

    private var isOpen: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !isClosed
    }

    func initialize(clientKey: String) {
        guard isOpen else { return }
        for plugin in plugins { plugin.initialize(clientKey: clientKey) }
    }

    func onExperimentViewed(experiment: Experiment, result: ExperimentResult, attributes: JSON?) {
        guard isOpen else { return }
        for plugin in plugins { plugin.onExperimentViewed(experiment: experiment, result: result, attributes: attributes) }
    }

    func onFeatureEvaluated(featureKey: String, result: FeatureResult, attributes: JSON?) {
        guard isOpen else { return }
        for plugin in plugins { plugin.onFeatureEvaluated(featureKey: featureKey, result: result, attributes: attributes) }
    }

    func flush() {
        guard isOpen else { return }
        for plugin in plugins { plugin.flush() }
    }

    /// Ends the registry. Later events are dropped here rather than left to each plugin: stopping
    /// the tracking plugin's timer still let evaluations refill its buffer, and a full batch sent
    /// another request long after the app asked the SDK to shut down.
    ///
    /// Idempotent, because `deinit` closes too and an app that closed explicitly would otherwise
    /// have its plugins shut down twice.
    func close() {
        lock.lock()
        let wasOpen = !isClosed
        isClosed = true
        lock.unlock()

        guard wasOpen else { return }
        for plugin in plugins { plugin.close() }
    }
}
