import AppKit
import Foundation

@MainActor
final class TargetApplicationTracker {
    private(set) var targetApp: NSRunningApplication?

    func captureCurrentTarget(excluding processIdentifier: pid_t) {
        targetApp = NSWorkspace.shared.frontmostApplication
        if targetApp?.processIdentifier == processIdentifier {
            targetApp = nil
        }
    }

    func reactivateTargetIfNeeded() {
        guard let targetApp else {
            return
        }

        _ = targetApp.activate(options: [.activateIgnoringOtherApps])
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
    }
}
