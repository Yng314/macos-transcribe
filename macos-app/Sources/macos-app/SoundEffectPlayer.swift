import AppKit
import Foundation

@MainActor
final class SoundEffectPlayer {
    private enum SoundPath {
        static let beginRecord = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/begin_record.caf"
        static let endRecord = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/end_record.caf"
    }

    private var activeSounds: [NSSound] = []

    func playRecordingStarted() {
        playSound(at: SoundPath.beginRecord)
    }

    func playRecordingStopped() {
        playSound(at: SoundPath.endRecord)
    }

    private func playSound(at path: String) {
        let url = URL(fileURLWithPath: path)
        guard let sound = NSSound(contentsOf: url, byReference: true) else {
            print("Sound load failed: \(path)")
            return
        }

        activeSounds.append(sound)
        sound.play()

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            self.activeSounds.removeAll { $0 == sound }
        }
    }
}
