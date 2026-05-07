import Foundation

enum KeyMappingManagerError: LocalizedError {
    case commandFailed(command: String, output: String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let command, let output):
            return "Key mapping command failed: \(command) \(output)"
        }
    }
}

final class KeyMappingManager {
    private let hidutilPath = "/usr/bin/hidutil"
    private let applyPayload = #"{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0xC000000CF,"HIDKeyboardModifierMappingDst":0x70000006D}]}"#
    private let clearPayload = #"{"UserKeyMapping":[]}"#

    func applyDictationKeyRemap() throws {
        try runHidutil(with: applyPayload)
    }

    func clearUserKeyMappings() throws {
        try runHidutil(with: clearPayload)
    }

    private func runHidutil(with payload: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: hidutilPath)
        process.arguments = ["property", "--set", payload]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw KeyMappingManagerError.commandFailed(command: "\(hidutilPath) property --set ...", output: output)
        }
    }
}
