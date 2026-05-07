import AppKit
import Foundation

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let recordingController: RecordingController
    private let textInsertionService: TextInsertionService
    private let openSettingsHandler: () -> Void

    private let configStatusLabel = NSTextField(labelWithString: "")
    private let microphoneStatusLabel = NSTextField(labelWithString: "")
    private let accessibilityStatusLabel = NSTextField(labelWithString: "")
    private let summaryLabel = NSTextField(labelWithString: "")
    private let configButton = NSButton(title: "Open Settings", target: nil, action: nil)
    private let microphoneButton = NSButton(title: "Request Access", target: nil, action: nil)
    private let accessibilityButton = NSButton(title: "Open Accessibility", target: nil, action: nil)
    private let doneButton = NSButton(title: "Done", target: nil, action: nil)

    init(
        recordingController: RecordingController,
        textInsertionService: TextInsertionService,
        openSettingsHandler: @escaping () -> Void
    ) {
        self.recordingController = recordingController
        self.textInsertionService = textInsertionService
        self.openSettingsHandler = openSettingsHandler

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Transcribe"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        setupUI()
        refreshStatus()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func showIfNeeded() {
        refreshStatus()
        guard !isFullyReady else {
            return
        }

        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        refreshStatus()
    }

    private var isConfigReady: Bool {
        (try? AppConfig.load()) != nil
    }

    private var isMicrophoneReady: Bool {
        recordingController.microphoneAuthorizationStatus() == .authorized
    }

    private var isAccessibilityReady: Bool {
        textInsertionService.accessibilityPermissionStatus()
    }

    private var isFullyReady: Bool {
        isConfigReady && isMicrophoneReady && isAccessibilityReady
    }

    private var isMicrophoneDeniedOrRestricted: Bool {
        let status = recordingController.microphoneAuthorizationStatus()
        return status == .denied || status == .restricted
    }

    private func setupUI() {
        guard let contentView = window?.contentView else {
            return
        }

        let titleLabel = NSTextField(labelWithString: "Finish setup before first use")
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)

        let subtitleLabel = NSTextField(labelWithString: "Transcribe needs API config, microphone access, and Accessibility access to replace Dictation.")
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.lineBreakMode = .byWordWrapping

        for label in [configStatusLabel, microphoneStatusLabel, accessibilityStatusLabel, summaryLabel] {
            label.maximumNumberOfLines = 2
            label.lineBreakMode = .byWordWrapping
        }

        summaryLabel.textColor = .secondaryLabelColor

        configButton.target = self
        configButton.action = #selector(openSettings)
        microphoneButton.target = self
        microphoneButton.action = #selector(requestMicrophoneAccess)
        accessibilityButton.target = self
        accessibilityButton.action = #selector(openAccessibilitySettings)
        doneButton.target = self
        doneButton.action = #selector(donePressed)

        let configRow = makeRow(title: "API Configuration", statusLabel: configStatusLabel, button: configButton)
        let microphoneRow = makeRow(title: "Microphone", statusLabel: microphoneStatusLabel, button: microphoneButton)
        let accessibilityRow = makeRow(title: "Accessibility", statusLabel: accessibilityStatusLabel, button: accessibilityButton)

        let stack = NSStackView(views: [
            titleLabel,
            subtitleLabel,
            configRow,
            microphoneRow,
            accessibilityRow,
            summaryLabel,
        ])
        stack.orientation = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        contentView.addSubview(doneButton)
        doneButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),

            doneButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            doneButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            doneButton.topAnchor.constraint(greaterThanOrEqualTo: stack.bottomAnchor, constant: 16),
        ])
    }

    private func makeRow(title: String, statusLabel: NSTextField, button: NSButton) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)

        statusLabel.textColor = .secondaryLabelColor

        let textStack = NSStackView(views: [titleLabel, statusLabel])
        textStack.orientation = .vertical
        textStack.spacing = 4

        let row = NSStackView(views: [textStack, button])
        row.orientation = .horizontal
        row.distribution = .fill
        row.alignment = .centerY
        row.spacing = 12

        button.setContentHuggingPriority(.required, for: .horizontal)
        return row
    }

    private func refreshStatus() {
        configStatusLabel.stringValue = isConfigReady ? "Configured" : "API Key and Base URL are not saved yet."
        configStatusLabel.textColor = isConfigReady ? .systemGreen : .secondaryLabelColor

        let microphoneReady = isMicrophoneReady
        let microphoneStatus = recordingController.microphoneAuthorizationStatusDescription()
        microphoneStatusLabel.stringValue = microphoneReady
            ? "Granted (\(microphoneStatus))"
            : "Microphone permission is still required (\(microphoneStatus))."
        microphoneStatusLabel.textColor = microphoneReady ? .systemGreen : .secondaryLabelColor

        let accessibilityReady = isAccessibilityReady
        accessibilityStatusLabel.stringValue = accessibilityReady ? "Granted" : "Accessibility is required to insert text into other apps."
        accessibilityStatusLabel.textColor = accessibilityReady ? .systemGreen : .secondaryLabelColor

        summaryLabel.stringValue = isFullyReady
            ? "Everything is ready. You can close this window."
            : "You can close this window and keep using the app. Missing permissions may affect recording or text insertion."

        doneButton.isEnabled = true
        accessibilityButton.title = isAccessibilityReady ? "Refresh" : "Open Accessibility"
        if isMicrophoneReady {
            microphoneButton.title = "Refresh"
        } else if isMicrophoneDeniedOrRestricted {
            microphoneButton.title = "Open Microphone"
        } else {
            microphoneButton.title = "Request Access"
        }
        configButton.title = isConfigReady ? "Open Settings" : "Open Settings"
    }

    @objc
    private func openSettings() {
        openSettingsHandler()
        refreshStatus()
    }

    @objc
    private func requestMicrophoneAccess() {
        Task { @MainActor in
            if isMicrophoneDeniedOrRestricted {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            } else {
                _ = await recordingController.requestMicrophonePermissionIfNeeded()
            }
            refreshStatus()
        }
    }

    @objc
    private func openAccessibilitySettings() {
        _ = textInsertionService.requestAccessibilityPermissionPrompt()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        refreshStatus()
    }

    @objc
    private func handleAppDidBecomeActive() {
        refreshStatus()
    }

    @objc
    private func donePressed() {
        refreshStatus()
        window?.close()
    }
}
