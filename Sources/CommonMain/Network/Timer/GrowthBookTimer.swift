import Foundation

protocol TimerInterface: Sendable {
    init(
        systemStateObserverForTimer: SystemStateObserverForTimerInterface,
        timerInterval: TimeInterval,
        timerAction: @escaping @Sendable () -> Void
    )

    func enable()
    func disable()
    func rescheduleNotEarlierThan(in seconds: Int)
}

final class CrossPlatformTimer: Sendable {
    private class MutableState {
        var isEnabled: Bool = false
        var timer: DispatchSourceTimer?
        var lastExecutionTime: Date?
        var runNotEarlierThan: Date?

        init(timer: DispatchSourceTimer? = nil, lastExecutionTime: Date? = nil, runNotEarlierThan: Date? = nil) {
            self.timer = timer
            self.lastExecutionTime = lastExecutionTime
            self.runNotEarlierThan = runNotEarlierThan
        }

        deinit {
            timer?.cancel()
            timer = .none
        }
    }

    private let mutableState: Protected<MutableState>

    // Timer closure
    private let timerAction: @Sendable () -> Void

    private let systemStateObserverForTimer: SystemStateObserverForTimerInterface
    private let timerInterval: TimeInterval

    init(
        systemStateObserverForTimer: SystemStateObserverForTimerInterface = SystemStateObserverForTimer(),
        timerInterval: TimeInterval = 60.0 * 60.0,
        timerAction: @escaping @Sendable () -> Void
    ) {
        self.systemStateObserverForTimer = systemStateObserverForTimer
        self.timerInterval = timerInterval
        self.mutableState = .init(.init(timer: .none, lastExecutionTime: .none))
        self.timerAction =  timerAction
        systemStateObserverForTimer.delegate = self
        if systemStateObserverForTimer.canScheduleTimer {
            scheduleTimer()
        }
    }

    deinit {
        stopTimer()
    }

    // Start the timer
    private func scheduleTimer() {
        // Create a DispatchSourceTimer
        let timer: DispatchSourceTimer?
        let lastExecutionTime: Date?
        let runNotEarlierThan: Date?

        stopTimer()

        (timer, lastExecutionTime, runNotEarlierThan) = mutableState.write { mutableState in

            guard mutableState.isEnabled else { return (.none, .none, .none) }

            let timer: DispatchSourceTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
            mutableState.timer = timer
            return (timer, mutableState.lastExecutionTime, mutableState.runNotEarlierThan)
        }

        guard let timer else { return }

        let nowDate: Date = Date()
        let leftTimeInterval: TimeInterval = max(
            // Time interval reduced by time since the last fetch.
            // Handles cases when system is back alive from sleep and background mode.
            timerInterval - nowDate.timeIntervalSince(lastExecutionTime ?? nowDate),

            // Should not run earlier than specified date.
            runNotEarlierThan?.timeIntervalSince(nowDate) ?? 0.0,

            // Should not be negative
            0.0
        )

        logger.trace("Scheduling timer in \(leftTimeInterval) seconds")

        timer.schedule(deadline: .now() + leftTimeInterval, repeating: timerInterval)

        // Handle the timer firing
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.timerAction()
            self.mutableState.write(\.lastExecutionTime, Date())
        }

        // Start the timer
        timer.resume()
    }

    // Stop the timer
    private func stopTimer() {
        mutableState.write { mutableState in
            mutableState.timer?.cancel()
            mutableState.timer = .none
        }
    }
}

extension CrossPlatformTimer: SystemStateObserverForTimerDelegate {
    func systemDidBecomeActive() {
        scheduleTimer()
    }

    func systemWillBecomeInactive() {
        stopTimer()
    }
}

extension CrossPlatformTimer: TimerInterface {
    func rescheduleNotEarlierThan(in seconds: Int) {
        mutableState.write(\.runNotEarlierThan,  Date(timeIntervalSinceNow: TimeInterval(seconds)))
        scheduleTimer()
    }

    func enable() {
        mutableState.write(\.isEnabled, true)
        scheduleTimer()
    }

    func disable() {
        mutableState.write(\.isEnabled, false)
        stopTimer()
    }
}
