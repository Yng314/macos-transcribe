import AppKit

@MainActor
final class StatusBarController {
    weak var delegate: StatusBarControllerDelegate?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let statusMenuItem = NSMenuItem(title: "Status: Starting…", action: nil, keyEquivalent: "")
    private let transcriptMenuItem = NSMenuItem(
        title: "Last transcript: none",
        action: #selector(copyTranscript),
        keyEquivalent: ""
    )
    private let retryLastRecordingMenuItem = NSMenuItem(
        title: "Retry Last Recording",
        action: #selector(retryLastRecording),
        keyEquivalent: ""
    )
    private let muteWhileRecordingMenuItem = NSMenuItem(
        title: "Mute speaker while recording",
        action: #selector(toggleMuteWhileRecording),
        keyEquivalent: ""
    )

    private var lastTranscript = ""
    private var transcriptPreviewText = "Last transcript: none"
    private var transcriptFeedbackTask: Task<Void, Never>?

    init() {
        if let button = statusItem.button {
            button.image = Self.loadStatusIcon()
            button.imagePosition = .imageOnly
        }

        statusMenuItem.isEnabled = false
        statusMenuItem.image = Self.makeMenuSymbol("waveform")

        transcriptMenuItem.target = self
        transcriptMenuItem.image = Self.makeMenuSymbol("doc.on.doc")
        transcriptMenuItem.isEnabled = false

        retryLastRecordingMenuItem.target = self
        retryLastRecordingMenuItem.image = Self.makeMenuSymbol("arrow.clockwise")
        retryLastRecordingMenuItem.isEnabled = false

        muteWhileRecordingMenuItem.target = self
        muteWhileRecordingMenuItem.image = Self.makeMenuSymbol("speaker.slash.fill")

        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(transcriptMenuItem)
        menu.addItem(retryLastRecordingMenuItem)
        menu.addItem(muteWhileRecordingMenuItem)
        menu.addItem(.separator())

        let settingsMenuItem = menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsMenuItem.target = self
        settingsMenuItem.image = Self.makeMenuSymbol("gearshape")

        let onboardingMenuItem = menu.addItem(
            withTitle: "Setup Guide…",
            action: #selector(openOnboarding),
            keyEquivalent: ""
        )
        onboardingMenuItem.target = self
        onboardingMenuItem.image = Self.makeMenuSymbol("questionmark.circle")

        let quitMenuItem = menu.addItem(
            withTitle: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitMenuItem.image = Self.makeMenuSymbol("xmark.circle")

        statusItem.menu = menu
    }

    func update(isRecording: Bool, lastEventDescription: String) {
        statusMenuItem.title = "Status: \(lastEventDescription)"
    }

    func updateTranscript(_ text: String) {
        lastTranscript = text
        let compact = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = compact.isEmpty ? "none" : compact
        transcriptPreviewText = "Last transcript: \(preview)"
        transcriptMenuItem.title = transcriptPreviewText
        transcriptMenuItem.isEnabled = !compact.isEmpty
        transcriptMenuItem.image = Self.makeMenuSymbol("doc.on.doc")
    }

    func updateMuteWhileRecording(_ enabled: Bool) {
        muteWhileRecordingMenuItem.state = enabled ? .on : .off
    }

    func updateRetryLastRecording(enabled: Bool) {
        retryLastRecordingMenuItem.isEnabled = enabled
    }

    @objc
    private func copyTranscript() {
        guard !lastTranscript.isEmpty else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lastTranscript, forType: .string)
        showTranscriptCopiedFeedback()
    }

    @objc
    private func openSettings() {
        delegate?.statusBarControllerDidRequestOpenSettings(self)
    }

    @objc
    private func openOnboarding() {
        delegate?.statusBarControllerDidRequestOpenOnboarding(self)
    }

    @objc
    private func toggleMuteWhileRecording() {
        delegate?.statusBarControllerDidToggleMuteWhileRecording(self)
    }

    @objc
    private func retryLastRecording() {
        delegate?.statusBarControllerDidRequestRetryLastRecording(self)
    }

    private static func loadStatusIcon() -> NSImage? {
        guard
            let iconURL = Bundle.main.resourceURL?.appendingPathComponent("menubar-icon.png"),
            let sourceImage = NSImage(contentsOf: iconURL)
        else {
            return nil
        }

        let targetHeight: CGFloat = 18
        let aspectRatio = sourceImage.size.width / max(sourceImage.size.height, 1)
        let targetSize = NSSize(width: round(targetHeight * aspectRatio), height: targetHeight)
        let image = NSImage(size: targetSize)
        image.isTemplate = true
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        sourceImage.draw(in: NSRect(origin: .zero, size: targetSize))
        image.unlockFocus()
        return image
    }

    private static func makeMenuSymbol(_ symbolName: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }

    private func showTranscriptCopiedFeedback() {
        transcriptFeedbackTask?.cancel()
        transcriptMenuItem.title = "Copied ✓"
        transcriptMenuItem.image = Self.makeMenuSymbol("checkmark")

        transcriptFeedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else {
                return
            }

            transcriptMenuItem.title = transcriptPreviewText
            transcriptMenuItem.image = Self.makeMenuSymbol("doc.on.doc")
        }
    }
}

@MainActor
protocol StatusBarControllerDelegate: AnyObject {
    func statusBarControllerDidRequestOpenSettings(_ controller: StatusBarController)
    func statusBarControllerDidRequestOpenOnboarding(_ controller: StatusBarController)
    func statusBarControllerDidRequestRetryLastRecording(_ controller: StatusBarController)
    func statusBarControllerDidToggleMuteWhileRecording(_ controller: StatusBarController)
}
