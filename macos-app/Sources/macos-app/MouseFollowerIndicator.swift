import AppKit
import QuartzCore
import Foundation

@MainActor
final class MouseFollowerIndicator {
    private enum State {
        case recording
        case transcribing
    }

    private let panel: NSPanel
    private let containerView: NSView
    private let backgroundView: NSView
    private let micImageView: NSImageView
    private let spinner: NSProgressIndicator
    private var displayLink: CVDisplayLink?
    private var currentState: State = .recording

    init() {
        let size = NSSize(width: 24, height: 24)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false

        containerView = NSView(frame: NSRect(origin: .zero, size: size))
        backgroundView = MouseFollowerIndicator.makeBackgroundView(frame: containerView.bounds, size: size)

        micImageView = NSImageView(frame: containerView.bounds.insetBy(dx: 4, dy: 4))
        micImageView.imageScaling = .scaleProportionallyUpOrDown
        if let image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Recording") {
            let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            micImageView.image = image.withSymbolConfiguration(configuration)
        }
        micImageView.contentTintColor = .systemBlue

        spinner = NSProgressIndicator(frame: NSRect(x: 6, y: 6, width: 12, height: 12))
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false

        containerView.addSubview(backgroundView)
        containerView.addSubview(micImageView)
        containerView.addSubview(spinner)
        panel.contentView = containerView

        apply(state: .recording)
    }

    func showRecording() {
        apply(state: .recording)
        showPanelIfNeeded()
    }

    func showTranscribing() {
        apply(state: .transcribing)
        showPanelIfNeeded()
    }

    func hide() {
        stopDisplayLink()
        spinner.stopAnimation(nil)
        panel.orderOut(nil)
    }

    private func showPanelIfNeeded() {
        updatePosition()
        panel.orderFrontRegardless()
        startDisplayLink()
    }

    private func apply(state: State) {
        currentState = state
        switch state {
        case .recording:
            micImageView.isHidden = false
            spinner.stopAnimation(nil)
        case .transcribing:
            micImageView.isHidden = true
            spinner.startAnimation(nil)
        }
    }

    private func updatePosition() {
        let frame = panel.frame
        let mouse = NSEvent.mouseLocation
        let x = mouse.x + 14
        let y = mouse.y - (frame.height / 2)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func startDisplayLink() {
        guard displayLink == nil else {
            return
        }

        var newDisplayLink: CVDisplayLink?
        guard CVDisplayLinkCreateWithActiveCGDisplays(&newDisplayLink) == kCVReturnSuccess,
              let newDisplayLink
        else {
            return
        }

        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo in
            guard let userInfo else {
                return kCVReturnSuccess
            }

            let indicator = Unmanaged<MouseFollowerIndicator>.fromOpaque(userInfo).takeUnretainedValue()
            Task { @MainActor in
                indicator.updatePosition()
            }
            return kCVReturnSuccess
        }

        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard CVDisplayLinkSetOutputCallback(newDisplayLink, callback, userInfo) == kCVReturnSuccess,
              CVDisplayLinkStart(newDisplayLink) == kCVReturnSuccess
        else {
            return
        }

        displayLink = newDisplayLink
    }

    private func stopDisplayLink() {
        guard let displayLink else {
            return
        }

        CVDisplayLinkStop(displayLink)
        self.displayLink = nil
    }

    private static func makeBackgroundView(frame: NSRect, size: NSSize) -> NSView {
        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView(frame: frame)
            glassView.autoresizingMask = [.width, .height]
            glassView.alphaValue = 0.9
            glassView.wantsLayer = true
            glassView.layer?.cornerRadius = size.width / 2
            glassView.layer?.masksToBounds = true
            return glassView
        } else {
            let visualEffectView = NSVisualEffectView(frame: frame)
            visualEffectView.autoresizingMask = [.width, .height]
            visualEffectView.material = .hudWindow
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.alphaValue = 0.9
            visualEffectView.wantsLayer = true
            visualEffectView.layer?.cornerRadius = size.width / 2
            visualEffectView.layer?.masksToBounds = true
            return visualEffectView
        }
    }
}
