import AppKit
import Foundation

@MainActor
final class SystemAudioOutputController {
    private struct OutputState {
        let muted: Bool
        let volume: Int
    }

    private var savedState: OutputState?

    func muteAfterStartCue() {
        guard savedState == nil else {
            return
        }

        let muted = readMuted()
        let volume = readVolume()
        savedState = OutputState(muted: muted, volume: volume)
        setMuted(true)
    }

    func restoreBeforeStopCue() {
        guard let savedState else {
            return
        }

        setVolume(savedState.volume)
        setMuted(savedState.muted)
        self.savedState = nil
    }

    private func readMuted() -> Bool {
        runAppleScript("output muted of (get volume settings)")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "true"
    }

    private func readVolume() -> Int {
        Int(
            runAppleScript("output volume of (get volume settings)")?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        ) ?? 0
    }

    private func setMuted(_ muted: Bool) {
        _ = runAppleScript("set volume output muted \(muted ? "true" : "false")")
    }

    private func setVolume(_ volume: Int) {
        let clamped = max(0, min(volume, 100))
        _ = runAppleScript("set volume output volume \(clamped)")
    }

    @discardableResult
    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)
        if let error {
            NSLog("AppleScript audio control error: %@", error)
        }
        return result?.stringValue
    }
}
