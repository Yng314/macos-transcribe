import AppKit

@MainActor
protocol SettingsWindowControllerDelegate: AnyObject {
    func settingsWindowControllerDidSave(config: AppConfig)
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    weak var delegate: SettingsWindowControllerDelegate?

    private enum Tab: Int {
        case personalization = 0
        case api = 1
    }

    private let sectionControl = NSSegmentedControl(labels: ["Personalization", "API"], trackingMode: .selectOne, target: nil, action: nil)
    private let personalizationContainer = NSView()
    private let apiContainer = NSView()
    private let apiKeyField = NSTextField()
    private let baseURLField = NSTextField()
    private let promptTextView = NSTextView()
    private let promptScrollView = NSScrollView()
    private let messageLabel = NSTextField(labelWithString: "")
    private let saveButton = NSButton(title: "Save", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    private var personalizationHeightConstraint: NSLayoutConstraint?
    private var apiHeightConstraint: NSLayoutConstraint?
    private var promptMinimumHeightConstraint: NSLayoutConstraint?

    init() {
        let contentRect = NSRect(x: 0, y: 0, width: 440, height: 380)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Transcribe Settings"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 200, height: 340)
        super.init(window: window)
        window.delegate = self
        setupUI()
        loadCurrentValues()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        loadCurrentValues()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        messageLabel.stringValue = ""
    }

    private func setupUI() {
        guard let contentView = window?.contentView else {
            return
        }

        let titleLabel = NSTextField(labelWithString: "Settings")
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        sectionControl.selectedSegment = Tab.personalization.rawValue
        sectionControl.target = self
        sectionControl.action = #selector(tabChanged)
        sectionControl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        sectionControl.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        apiKeyField.placeholderString = "sk-..."
        baseURLField.placeholderString = "https://api.bltcy.ai/v1"

        promptTextView.isRichText = false
        promptTextView.importsGraphics = false
        promptTextView.font = .systemFont(ofSize: 13)
        promptTextView.isAutomaticQuoteSubstitutionEnabled = false
        promptTextView.isAutomaticDashSubstitutionEnabled = false
        promptTextView.isAutomaticDataDetectionEnabled = false
        promptTextView.isAutomaticLinkDetectionEnabled = false
        promptTextView.textContainerInset = NSSize(width: 8, height: 8)

        promptScrollView.borderType = .bezelBorder
        promptScrollView.hasVerticalScroller = true
        promptScrollView.drawsBackground = true
        promptScrollView.documentView = promptTextView

        messageLabel.textColor = .secondaryLabelColor
        configureWrappingLabel(messageLabel, maxLines: 2)

        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(saveSettings)

        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(closeWindow)

        apiKeyField.translatesAutoresizingMaskIntoConstraints = false
        baseURLField.translatesAutoresizingMaskIntoConstraints = false
        promptScrollView.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [titleLabel, sectionControl, personalizationContainer, apiContainer, messageLabel])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        let buttonStack = NSStackView(views: [cancelButton, saveButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 10
        buttonStack.alignment = .centerY
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        personalizationContainer.translatesAutoresizingMaskIntoConstraints = false
        apiContainer.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        contentView.addSubview(buttonStack)

        let personalizationHeightConstraint = personalizationContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 180)
        let apiHeightConstraint = apiContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 180)
        self.personalizationHeightConstraint = personalizationHeightConstraint
        self.apiHeightConstraint = apiHeightConstraint

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            personalizationContainer.widthAnchor.constraint(equalTo: stack.widthAnchor),
            personalizationHeightConstraint,
            apiContainer.widthAnchor.constraint(equalTo: stack.widthAnchor),
            apiHeightConstraint,
            messageLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),

            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            buttonStack.topAnchor.constraint(greaterThanOrEqualTo: stack.bottomAnchor, constant: 16),
        ])

        setupPersonalizationUI()
        setupAPIUI()
        applyVisibleTab(.personalization)
    }

    private func setupPersonalizationUI() {
        let titleLabel = NSTextField(labelWithString: "Transcription Hint")
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)

        let helperLabel = NSTextField(
            labelWithString: "Add domain terms, names, or preferred spellings. This text will be sent as the transcription prompt for gpt-4o-mini-transcribe."
        )
        helperLabel.textColor = .secondaryLabelColor
        configureWrappingLabel(helperLabel, maxLines: 3)

        let exampleLabel = NSTextField(
            labelWithString: "Example: This transcript is about AI tools and software engineering. Important terms include OpenClaw, Codex, macOS, dictation, and transcription. Prefer these spellings when audio is similar."
        )
        exampleLabel.textColor = .secondaryLabelColor
        configureWrappingLabel(exampleLabel, maxLines: 4)

        let stack = NSStackView(views: [titleLabel, helperLabel, promptScrollView, exampleLabel])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        personalizationContainer.addSubview(stack)

        let promptMinimumHeightConstraint = promptScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 110)
        self.promptMinimumHeightConstraint = promptMinimumHeightConstraint
        promptScrollView.setContentHuggingPriority(.defaultLow, for: .vertical)
        promptScrollView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: personalizationContainer.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: personalizationContainer.trailingAnchor),
            stack.topAnchor.constraint(equalTo: personalizationContainer.topAnchor),
            stack.bottomAnchor.constraint(equalTo: personalizationContainer.bottomAnchor),
            promptScrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            promptMinimumHeightConstraint,
            helperLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            exampleLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func setupAPIUI() {
        let titleLabel = NSTextField(labelWithString: "OpenAI API")
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)

        let apiKeyLabel = NSTextField(labelWithString: "API Key")
        apiKeyLabel.font = .systemFont(ofSize: 13, weight: .medium)

        let baseURLLabel = NSTextField(labelWithString: "Base URL")
        baseURLLabel.font = .systemFont(ofSize: 13, weight: .medium)

        let helperLabel = NSTextField(
            labelWithString: "Saved to Application Support. Restart is not required."
        )
        helperLabel.textColor = .secondaryLabelColor
        configureWrappingLabel(helperLabel, maxLines: 2)

        let stack = NSStackView(views: [titleLabel, apiKeyLabel, apiKeyField, baseURLLabel, baseURLField, helperLabel])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        apiContainer.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: apiContainer.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: apiContainer.trailingAnchor),
            stack.topAnchor.constraint(equalTo: apiContainer.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: apiContainer.bottomAnchor),
            apiKeyField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            baseURLField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            helperLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func applyVisibleTab(_ tab: Tab) {
        personalizationContainer.isHidden = tab != .personalization
        apiContainer.isHidden = tab != .api
        personalizationHeightConstraint?.constant = tab == .personalization ? 180 : 0
        apiHeightConstraint?.constant = tab == .api ? 180 : 0
    }

    private func loadCurrentValues() {
        let draft = AppConfig.loadForSettings()
        apiKeyField.stringValue = draft.openAIAPIKey
        baseURLField.stringValue = draft.openAIBaseURL
        promptTextView.string = draft.transcriptionPrompt
        sectionControl.selectedSegment = Tab.personalization.rawValue
        applyVisibleTab(.personalization)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.stringValue = "Saved to Application Support. Restart is not required."
    }

    @objc
    private func tabChanged() {
        let selected = Tab(rawValue: sectionControl.selectedSegment) ?? .personalization
        applyVisibleTab(selected)
    }

    @objc
    private func saveSettings() {
        do {
            let config = try AppConfig.save(
                AppConfigDraft(
                    openAIAPIKey: apiKeyField.stringValue,
                    openAIBaseURL: baseURLField.stringValue,
                    transcriptionPrompt: promptTextView.string
                )
            )
            messageLabel.textColor = .systemGreen
            messageLabel.stringValue = "Saved."
            delegate?.settingsWindowControllerDidSave(config: config)
            closeWindow()
        } catch {
            messageLabel.textColor = .systemRed
            messageLabel.stringValue = error.localizedDescription
        }
    }

    @objc
    private func closeWindow() {
        window?.close()
    }

    private func configureWrappingLabel(_ label: NSTextField, maxLines: Int) {
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = maxLines
        label.usesSingleLineMode = false
        label.cell?.wraps = true
        label.cell?.isScrollable = false
        label.cell?.usesSingleLineMode = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
}
