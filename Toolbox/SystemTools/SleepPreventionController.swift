import Foundation
import IOKit.pwr_mgt

enum SleepPreventionMode: String, CaseIterable, Identifiable {
    case system
    case display

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "Prevent System Sleep"
        case .display: "Prevent Display Sleep"
        }
    }

    var detail: String {
        switch self {
        case .system: "Keeps background work running while allowing the display to sleep."
        case .display: "Keeps the display awake and also prevents idle system sleep."
        }
    }

    var assertionType: CFString {
        switch self {
        case .system: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString
        case .display: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString
        }
    }
}

enum SleepPreventionDuration: String, CaseIterable, Identifiable {
    case thirtyMinutes
    case oneHour
    case twoHours
    case indefinitely

    var id: Self { self }

    var title: String {
        switch self {
        case .thirtyMinutes: "30 Minutes"
        case .oneHour: "1 Hour"
        case .twoHours: "2 Hours"
        case .indefinitely: "Until Turned Off"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .thirtyMinutes: 30 * 60
        case .oneHour: 60 * 60
        case .twoHours: 2 * 60 * 60
        case .indefinitely: nil
        }
    }
}

enum SleepPreventionError: LocalizedError {
    case assertionCreationFailed(IOReturn)

    var errorDescription: String? {
        switch self {
        case let .assertionCreationFailed(code):
            "macOS could not enable sleep prevention (error \(code))."
        }
    }
}

@MainActor
final class SleepPreventionController: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var activeMode: SleepPreventionMode?
    @Published private(set) var remainingSeconds: TimeInterval?
    @Published private(set) var errorMessage: String?

    private var assertionID: IOPMAssertionID = 0
    private var deadline: Date?
    private var countdownTask: Task<Void, Never>?

    deinit {
        countdownTask?.cancel()
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
        }
    }

    func start(mode: SleepPreventionMode, duration: SleepPreventionDuration) {
        stop()

        var newAssertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            mode.assertionType,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Toolbox Sleep Prevention" as CFString,
            &newAssertionID
        )

        guard result == kIOReturnSuccess else {
            errorMessage = SleepPreventionError.assertionCreationFailed(result).localizedDescription
            return
        }

        assertionID = newAssertionID
        isActive = true
        activeMode = mode
        errorMessage = nil

        if let seconds = duration.seconds {
            let deadline = Date.now.addingTimeInterval(seconds)
            self.deadline = deadline
            remainingSeconds = seconds
            startCountdown()
        } else {
            deadline = nil
            remainingSeconds = nil
        }
    }

    func stop() {
        countdownTask?.cancel()
        countdownTask = nil
        deadline = nil
        remainingSeconds = nil
        releaseAssertion()
        isActive = false
        activeMode = nil
    }

    private func startCountdown() {
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let deadline else { return }
                let remaining = max(0, deadline.timeIntervalSinceNow)
                remainingSeconds = remaining
                if remaining <= 0 {
                    stop()
                    return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func releaseAssertion() {
        guard assertionID != 0 else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }
}
