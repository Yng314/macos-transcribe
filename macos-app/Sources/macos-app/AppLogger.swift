import Foundation

final class AppLogger {
    private let logURL: URL

    init() {
        let logsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Transcribe", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)

        if let logsDirectory {
            try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
            self.logURL = logsDirectory.appendingPathComponent("app.log")
        } else {
            self.logURL = FileManager.default.temporaryDirectory.appendingPathComponent("transcribe-app.log")
        }
    }

    func log(_ message: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let line = "\(formatter.string(from: Date())) \(message)\n"
        let data = Data(line.utf8)

        if FileManager.default.fileExists(atPath: logURL.path) {
            if let handle = try? FileHandle(forWritingTo: logURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        } else {
            try? data.write(to: logURL)
        }
    }
}
