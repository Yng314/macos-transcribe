import AppKit
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, StatusBarControllerDelegate, SettingsWindowControllerDelegate {
    private let statusBarController = StatusBarController()
    private let logger = AppLogger()
    private let keyMappingManager = KeyMappingManager()
    private let hotKeyManager = HotKeyManager()
    private let recordingController = RecordingController()
    private let mouseFollowerIndicator = MouseFollowerIndicator()
    private let soundEffectPlayer = SoundEffectPlayer()
    private let systemAudioOutputController = SystemAudioOutputController()
    private let targetApplicationTracker = TargetApplicationTracker()
    private let textInsertionService = TextInsertionService()
    private let settingsWindowController = SettingsWindowController()
    private lazy var onboardingWindowController = OnboardingWindowController(
        recordingController: recordingController,
        textInsertionService: textInsertionService,
        openSettingsHandler: { [weak self] in
            self?.settingsWindowController.show()
        }
    )
    private var transcriptionService: TranscriptionService?
    private var startupErrorMessage: String?
    private var preferences = AppConfig.loadPreferences()
    private var retryableRecordingURL: URL?

    override init() {
        self.transcriptionService = nil
        self.startupErrorMessage = nil
        super.init()
        statusBarController.delegate = self
        settingsWindowController.delegate = self

        do {
            let config = try AppConfig.load()
            self.transcriptionService = TranscriptionService(config: config)
            self.startupErrorMessage = nil
        } catch {
            self.startupErrorMessage = error.localizedDescription
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try keyMappingManager.applyDictationKeyRemap()
        } catch {
            statusBarController.update(isRecording: false, lastEventDescription: "Key mapping error: \(error.localizedDescription)")
            logger.log("Key mapping error: \(error.localizedDescription)")
            return
        }

        let initialStatus = startupErrorMessage == nil ? "Listening for F18" : "Config error: \(startupErrorMessage!)"
        statusBarController.update(isRecording: false, lastEventDescription: initialStatus)
        statusBarController.updateMuteWhileRecording(preferences.muteSpeakerWhileRecording)
        statusBarController.updateRetryLastRecording(enabled: false)
        logger.log("Dictation key mapped to F18")
        logger.log(initialStatus)
        onboardingWindowController.showIfNeeded()

        do {
            try hotKeyManager.register(keyCode: UInt32(kVK_F18), modifiers: 0) { [weak self] in
                Task { @MainActor in
                    await self?.handleHotKeyPress()
                }
            }
        } catch {
            statusBarController.update(
                isRecording: false,
                lastEventDescription: "Hotkey registration failed: \(error.localizedDescription)"
            )
            logger.log("Hotkey registration failed: \(error.localizedDescription)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
        mouseFollowerIndicator.hide()
        systemAudioOutputController.restoreBeforeStopCue()
        do {
            try keyMappingManager.clearUserKeyMappings()
        } catch {
            // App is terminating anyway, so keep shutdown path simple.
        }
    }

    func statusBarControllerDidRequestOpenSettings(_ controller: StatusBarController) {
        settingsWindowController.show()
    }

    func statusBarControllerDidRequestOpenOnboarding(_ controller: StatusBarController) {
        onboardingWindowController.showIfNeeded()
    }

    func statusBarControllerDidRequestRetryLastRecording(_ controller: StatusBarController) {
        guard let fileURL = retryableRecordingURL else {
            return
        }

        Task { @MainActor in
            await retryLastRecording(at: fileURL)
        }
    }

    func statusBarControllerDidToggleMuteWhileRecording(_ controller: StatusBarController) {
        preferences.muteSpeakerWhileRecording.toggle()
        statusBarController.updateMuteWhileRecording(preferences.muteSpeakerWhileRecording)
        do {
            try AppConfig.savePreferences(preferences)
            logger.log("Mute while recording \(preferences.muteSpeakerWhileRecording ? "enabled" : "disabled")")
        } catch {
            logger.log("Failed to save preferences: \(error.localizedDescription)")
        }
    }

    func settingsWindowControllerDidSave(config: AppConfig) {
        transcriptionService = TranscriptionService(config: config)
        startupErrorMessage = nil
        statusBarController.update(isRecording: false, lastEventDescription: "Listening for F18")
        logger.log("Configuration updated")
        onboardingWindowController.showIfNeeded()
    }

    private func handleHotKeyPress() async {
        do {
            let result = try await recordingController.toggleRecording()

            if let result {
                let filePath = result.fileURL.path
                let fileExists = FileManager.default.fileExists(atPath: filePath)
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: filePath)[.size] as? NSNumber)?.intValue ?? -1
                mouseFollowerIndicator.showTranscribing()
                if preferences.muteSpeakerWhileRecording {
                    systemAudioOutputController.restoreBeforeStopCue()
                }
                soundEffectPlayer.playRecordingStopped()
                statusBarController.update(
                    isRecording: false,
                    lastEventDescription: "Transcribing \(result.fileURL.lastPathComponent)…"
                )
                retryableRecordingURL = result.fileURL
                statusBarController.updateRetryLastRecording(enabled: true)
                logger.log(
                    "Recording saved \(result.fileURL.lastPathComponent) \(String(format: "%.1f", result.duration))s \(fileExists ? "ok" : "missing") size=\(fileSize)"
                )
                try await transcribeRecording(at: result.fileURL)
            } else {
                targetApplicationTracker.captureCurrentTarget(excluding: ProcessInfo.processInfo.processIdentifier)
                mouseFollowerIndicator.showRecording()
                soundEffectPlayer.playRecordingStarted()
                if preferences.muteSpeakerWhileRecording {
                    systemAudioOutputController.muteAfterStartCue()
                }
                statusBarController.update(isRecording: true, lastEventDescription: "Recording… Press F18 to stop")
                logger.log("Recording started")
            }
        } catch {
            mouseFollowerIndicator.hide()
            if preferences.muteSpeakerWhileRecording, !recordingController.isRecording {
                systemAudioOutputController.restoreBeforeStopCue()
            }
            statusBarController.update(
                isRecording: recordingController.isRecording,
                lastEventDescription: "Recording error: \(error.localizedDescription)"
            )
            logger.log("Error: \(error.localizedDescription)")
        }
    }

    private func transcribeRecording(at fileURL: URL) async throws {
        guard let transcriptionService else {
            settingsWindowController.show()
            throw startupErrorMessage.map { AppConfigError.invalidOpenAIBaseURL($0) } ?? AppConfigError.missingOpenAIAPIKey
        }

        do {
            let result = try await transcriptionService.transcribe(fileURL: fileURL)
            targetApplicationTracker.reactivateTargetIfNeeded()
            let insertionResult = try textInsertionService.insert(result.text)
            mouseFollowerIndicator.hide()
            statusBarController.update(
                isRecording: false,
                lastEventDescription: "Inserted via \(insertionResult.method.rawValue) (\(String(format: "%.1f", result.elapsedSeconds))s)"
            )
            statusBarController.updateTranscript(result.text)
            clearRetryableRecordingIfMatching(fileURL)
            logger.log(
                "Transcript ready in \(String(format: "%.1f", result.elapsedSeconds))s via \(insertionResult.method.rawValue)"
            )
        } catch {
            mouseFollowerIndicator.hide()
            statusBarController.update(
                isRecording: false,
                lastEventDescription: "Transcription failed. Retry Last Recording is available."
            )
            retryableRecordingURL = fileURL
            statusBarController.updateRetryLastRecording(enabled: true)
            logger.log("Transcription/insertion failure: \(error.localizedDescription)")
            throw error
        }
    }

    private func retryLastRecording(at fileURL: URL) async {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            retryableRecordingURL = nil
            statusBarController.updateRetryLastRecording(enabled: false)
            statusBarController.update(
                isRecording: false,
                lastEventDescription: "Last recording file is no longer available"
            )
            logger.log("Retry skipped because recording file is missing")
            return
        }

        mouseFollowerIndicator.showTranscribing()
        statusBarController.update(
            isRecording: false,
            lastEventDescription: "Retrying \(fileURL.lastPathComponent)…"
        )
        logger.log("Retrying recording \(fileURL.lastPathComponent)")

        do {
            try await transcribeRecording(at: fileURL)
        } catch {
            statusBarController.update(
                isRecording: false,
                lastEventDescription: "Transcription failed. Retry Last Recording is available."
            )
            logger.log("Retry failed: \(error.localizedDescription)")
        }
    }

    private func clearRetryableRecordingIfMatching(_ fileURL: URL) {
        guard retryableRecordingURL == fileURL else {
            deleteFileIfExists(at: fileURL)
            return
        }

        retryableRecordingURL = nil
        statusBarController.updateRetryLastRecording(enabled: false)
        deleteFileIfExists(at: fileURL)
    }

    private func deleteFileIfExists(at fileURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            logger.log("Failed to delete temporary recording: \(error.localizedDescription)")
        }
    }
}
