import Foundation

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
final class SystemStateObserverForTimer: SystemStateObserverForTimerInterface, Sendable {

    private class MutableState {
        weak var delegate: (any SystemStateObserverForTimerDelegate)?
        var canScheduleTimer: Bool

        init(delegate: (any SystemStateObserverForTimerDelegate)? = nil, canScheduleTimer: Bool) {
            self.delegate = delegate
            self.canScheduleTimer = canScheduleTimer
        }
    }

    private let mutableState: Protected<MutableState>

    private let notificationCenter: NotificationCenter

    var delegate: (any SystemStateObserverForTimerDelegate)? {
        get { mutableState.read(\.delegate) }
        set { updateDelegate(to: newValue) }
    }

    var canScheduleTimer: Bool { mutableState.read(\.canScheduleTimer) }


    deinit {
        notificationCenter.removeObserver(self)
    }

    /// Updates delegate to a new value and asks old delegates to stop timer,
    /// and new timer receives request based on the current `canScheduleTimer` value.
    ///
    /// - Parameter newValue: A new delegate value.
    private func updateDelegate(to newValue: (any SystemStateObserverForTimerDelegate)?) {
        let (oldDelegate, canScheduleTimer) = mutableState.write {
            let oldDelegate = $0.delegate
            $0.delegate = newValue
            return (oldDelegate, $0.canScheduleTimer)
        }
        notify(delegate: oldDelegate, canScheduleTimer: false)
        notify(delegate: newValue, canScheduleTimer: canScheduleTimer)
    }

    /// Asks the delegate to stop or start timer based on a `canScheduleTimer` value.
    ///
    /// - Parameters:
    ///   - delegate: A delegate to notify.
    ///   - canScheduleTimer: A `Bool` representing if delegate must schedule timer or stop it.
    private func notify(delegate: (any SystemStateObserverForTimerDelegate)?, canScheduleTimer: Bool) {
        guard let delegate = delegate else { return }

        if canScheduleTimer {
            delegate.systemDidBecomeActive()
        } else {
            delegate.systemWillBecomeInactive()
        }
    }

    /// Changes the `canScheduleTimer` property to a new value and notifies delegate if needed.
    ///
    /// - Parameter newValue: A new value for the `canScheduleTimer`.
    private func changeCanScheduleTimerValue(to newValue: Bool) {
        let (delegate, valueDidChange) = mutableState.write { mutableState in
            let valueDidChange: Bool = mutableState.canScheduleTimer != newValue
            mutableState.canScheduleTimer = newValue
            return (mutableState.delegate, valueDidChange)
        }

        guard valueDidChange else { return }

        notify(delegate: delegate, canScheduleTimer: newValue)
    }

    static func isSystemReadyForTimerSetup() -> Bool {
        UIApplication.shared.applicationState == .active
    }

    // Custom iOS logic

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        self.mutableState = .init(MutableState(canScheduleTimer: Self.isSystemReadyForTimerSetup()))
        setupSystemStateObservers()
    }

    /// Subscribes to app state notifications.
    private func setupSystemStateObservers() {
        notificationCenter.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(appDidEnterForeground),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    /// Changes changeCanSchedule to `true`
    ///
    /// Called when the app becomes active.
    @objc private func appDidEnterForeground() {
        changeCanScheduleTimerValue(to: true)
    }

    /// Changes changeCanSchedule to `false`
    ///
    /// Called when the app goes to background.
    @objc private func appDidEnterBackground() {
        changeCanScheduleTimerValue(to: false)
    }
}
#endif
