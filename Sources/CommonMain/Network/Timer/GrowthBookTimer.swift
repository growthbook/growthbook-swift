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
        var nextExecutionTime: Date?
        var runNotEarlierThan: Date?

        init(timer: DispatchSourceTimer? = nil, lastExecutionTime: Date? = nil, nextExecutionTime: Date? = nil, runNotEarlierThan: Date? = nil) {
            self.timer = timer
            self.lastExecutionTime = lastExecutionTime
            self.nextExecutionTime = nextExecutionTime
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

    private func nextExecutionTime(
        timeInterval: TimeInterval,
        lastExecutionTime: Date?,
        runNotEarlierThan: Date?
    ) -> TimeInterval
    {
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

        return leftTimeInterval.rounded(.up)
    }

    // Start the timer
    private func scheduleTimer() {
        // Create a DispatchSourceTimer
        let timer: DispatchSourceTimer?
        let fireTimerInSeconds: TimeInterval?

        stopTimer()

        (timer, fireTimerInSeconds) = mutableState.write { mutableState in

            guard mutableState.isEnabled else { return (.none, .none) }

            let timer: DispatchSourceTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
            mutableState.timer = timer
            let fireTimerInSeconds: TimeInterval = nextExecutionTime(
                timeInterval: timerInterval,
                lastExecutionTime: mutableState.lastExecutionTime,
                runNotEarlierThan: mutableState.runNotEarlierThan
            )
            mutableState.nextExecutionTime = Date().addingTimeInterval(fireTimerInSeconds)
            return (timer, fireTimerInSeconds)
        }

        guard let timer, let fireTimerInSeconds else { return }

        logger.trace("Scheduling timer in \(fireTimerInSeconds) seconds")

        timer.schedule(deadline: .now() + fireTimerInSeconds, repeating: timerInterval)

        // Handle the timer firing
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.mutableState.write(\.nextExecutionTime, Date().addingTimeInterval(timerInterval))
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
        let seconds = TimeInterval(seconds)
        if (mutableState.read(\.nextExecutionTime)?.timeIntervalSinceNow ?? 0.0) < seconds {
            mutableState.write(\.runNotEarlierThan,  Date(timeIntervalSinceNow: TimeInterval(seconds)))
            scheduleTimer()
        }
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
