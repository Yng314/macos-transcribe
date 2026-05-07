import AVFoundation
import Foundation

enum RecordingControllerError: LocalizedError {
    case microphoneAccessDenied
    case recorderCreationFailed
    case stopWithoutActiveRecording

    var errorDescription: String? {
        switch self {
        case .microphoneAccessDenied:
            return "Microphone access denied"
        case .recorderCreationFailed:
            return "Failed to create audio recorder"
        case .stopWithoutActiveRecording:
            return "No active recording to stop"
        }
    }
}

struct RecordingSessionResult {
    let fileURL: URL
    let duration: TimeInterval
}

@MainActor
final class RecordingController: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var startedAt: Date?
    private var currentFileURL: URL?

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    func microphoneAuthorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    func microphoneAuthorizationStatusDescription() -> String {
        switch microphoneAuthorizationStatus() {
        case .authorized:
            return "authorized"
        case .denied:
            return "denied"
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        @unknown default:
            return "unknown"
        }
    }

    func requestMicrophonePermissionIfNeeded() async -> Bool {
        let status = microphoneAuthorizationStatus()
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await requestMicrophoneAccess()
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func toggleRecording() async throws -> RecordingSessionResult? {
        if isRecording {
            return try stopRecording()
        }

        try await startRecording()
        return nil
    }

    func startRecording() async throws {
        let allowed = await requestMicrophoneAccess()
        guard allowed else {
            throw RecordingControllerError.microphoneAccessDenied
        }

        let outputURL = makeOutputURL()
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = false

        guard recorder.prepareToRecord() else {
            throw RecordingControllerError.recorderCreationFailed
        }

        guard recorder.record() else {
            throw RecordingControllerError.recorderCreationFailed
        }

        self.recorder = recorder
        currentFileURL = outputURL
        startedAt = Date()
    }

    func stopRecording() throws -> RecordingSessionResult {
        guard let recorder, recorder.isRecording else {
            throw RecordingControllerError.stopWithoutActiveRecording
        }

        recorder.stop()

        let duration = Date().timeIntervalSince(startedAt ?? Date())
        let fileURL = currentFileURL ?? recorder.url

        self.recorder = nil
        currentFileURL = nil
        startedAt = nil

        return RecordingSessionResult(fileURL: fileURL, duration: duration)
    }

    private func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    private func makeOutputURL() -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")

        return FileManager.default.temporaryDirectory
            .appendingPathComponent("dictation-replacement-\(timestamp)")
            .appendingPathExtension("m4a")
    }
}
