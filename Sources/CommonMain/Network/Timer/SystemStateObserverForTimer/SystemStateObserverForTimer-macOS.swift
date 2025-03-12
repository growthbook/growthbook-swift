//
//  File.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 3/11/25.
//

import Foundation

#if os(macOS)
import Cocoa
import IOKit.pwr_mgt

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

    static func isSystemReadyForTimerSetup() -> Bool {
        let idleSleepAssertion: UnsafeMutablePointer<IOPMAssertionID> = .allocate(capacity: 1)
        defer { idleSleepAssertion.deinitialize(count: 1) }
        let sleepStatus = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoIdleSleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), "Check if system is asleep" as CFString, idleSleepAssertion)

        if sleepStatus == kIOReturnSuccess {
            return false // System is not asleep
        } else {
            return true // System is asleep
        }
    }

    init(notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter) {
        self.notificationCenter = notificationCenter
        self.mutableState = .init(MutableState(canScheduleTimer: Self.isSystemReadyForTimerSetup()))
        setupSystemStateObservers()
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    /// Subscribes to sleep mode notifications.
    private func setupSystemStateObservers() {
        // Observe sleep mode for macOS.
        notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWakeUp),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
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

    /// Changes changeCanSchedule to `true`
    ///
    ///Called when the system wakes up.
    @objc private func systemDidWakeUp() {
        changeCanScheduleTimerValue(to: true)
    }

    /// Changes changeCanSchedule to `false`
    ///
    /// Called when the system goes to sleep.
    @objc private func systemWillSleep() {
        changeCanScheduleTimerValue(to: false)
    }
}
#endif
