import AppKit
@preconcurrency import ApplicationServices
import Carbon
import Foundation

enum TextInsertionMethod: String {
    case accessibility
    case pasteboardFallback
}

struct TextInsertionResult {
    let method: TextInsertionMethod
}

private struct ClipboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]
    let hasContents: Bool

    static func capture(from pasteboard: NSPasteboard) -> ClipboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }

        return ClipboardSnapshot(items: items, hasContents: !items.isEmpty)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        guard hasContents else {
            return
        }

        let restoredItems = items.map { storedItem -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in storedItem {
                item.setData(data, forType: type)
            }
            return item
        }

        pasteboard.writeObjects(restoredItems)
    }
}

enum TextInsertionError: LocalizedError {
    case accessibilityPermissionDenied
    case noFocusedElement
    case unsupportedFocusedElement
    case pasteSimulationFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "Accessibility permission denied"
        case .noFocusedElement:
            return "No focused text input element found"
        case .unsupportedFocusedElement:
            return "Focused element does not support direct text insertion"
        case .pasteSimulationFailed:
            return "Failed to simulate Command+V"
        }
    }
}

@MainActor
final class TextInsertionService {
    func accessibilityPermissionStatus() -> Bool {
        ensureAccessibilityPermission(prompt: false)
    }

    func requestAccessibilityPermissionPrompt() -> Bool {
        ensureAccessibilityPermission(prompt: true)
    }

    func insert(_ text: String) throws -> TextInsertionResult {
        let sanitizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedText.isEmpty else {
            throw TextInsertionError.unsupportedFocusedElement
        }

        if try insertViaAccessibility(sanitizedText) {
            return TextInsertionResult(method: .accessibility)
        }

        try insertViaPasteboardFallback(sanitizedText)
        return TextInsertionResult(method: .pasteboardFallback)
    }

    private func insertViaAccessibility(_ text: String) throws -> Bool {
        guard ensureAccessibilityPermission(prompt: true) else {
            return false
        }

        let systemElement = AXUIElementCreateSystemWide()
        var focusedObject: CFTypeRef?
        let focusedStatus = AXUIElementCopyAttributeValue(
            systemElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        )

        guard focusedStatus == .success, let focusedObject, CFGetTypeID(focusedObject) == AXUIElementGetTypeID() else {
            return false
        }

        let focusedElement = unsafeDowncast(focusedObject, to: AXUIElement.self)
        var valueObject: CFTypeRef?
        let valueStatus = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXValueAttribute as CFString,
            &valueObject
        )

        guard valueStatus == .success, let valueObject, let currentValue = valueObject as? String else {
            return false
        }

        var selectedRangeObject: CFTypeRef?
        let selectedRangeStatus = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeObject
        )

        guard selectedRangeStatus == .success,
              let selectedRangeObject,
              CFGetTypeID(selectedRangeObject) == AXValueGetTypeID()
        else {
            return false
        }

        let selectedRangeValue = unsafeDowncast(selectedRangeObject, to: AXValue.self)
        guard AXValueGetType(selectedRangeValue) == .cfRange else {
            return false
        }

        var range = CFRange()
        guard AXValueGetValue(selectedRangeValue, .cfRange, &range) else {
            return false
        }

        let nsValue = currentValue as NSString
        guard range.location >= 0,
              range.length >= 0,
              range.location <= nsValue.length,
              range.location + range.length <= nsValue.length
        else {
            return false
        }

        let replacementRange = NSRange(location: range.location, length: range.length)
        let updatedValue = nsValue.replacingCharacters(in: replacementRange, with: text)

        let setValueStatus = AXUIElementSetAttributeValue(
            focusedElement,
            kAXValueAttribute as CFString,
            updatedValue as CFTypeRef
        )

        guard setValueStatus == .success else {
            return false
        }

        var newRange = CFRange(location: range.location + (text as NSString).length, length: 0)
        if let newRangeValue = AXValueCreate(.cfRange, &newRange) {
            _ = AXUIElementSetAttributeValue(
                focusedElement,
                kAXSelectedTextRangeAttribute as CFString,
                newRangeValue
            )
        }

        return true
    }

    private func insertViaPasteboardFallback(_ text: String) throws {
        let pasteboard = NSPasteboard.general
        let snapshot = ClipboardSnapshot.capture(from: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let insertedChangeCount = pasteboard.changeCount

        guard let commandDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let commandUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        else {
            throw TextInsertionError.pasteSimulationFailed
        }

        commandDown.flags = .maskCommand
        commandUp.flags = .maskCommand
        commandDown.post(tap: .cghidEventTap)
        commandUp.post(tap: .cghidEventTap)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard pasteboard.changeCount == insertedChangeCount else {
                return
            }
            snapshot.restore(to: pasteboard)
        }
    }

    private func ensureAccessibilityPermission(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
