import Foundation

struct AppConfig {
    let openAIAPIKey: String
    let openAIBaseURL: URL
    let transcriptionPrompt: String

    static func load() throws -> AppConfig {
        if let persisted = try loadPersistedConfig() {
            return persisted
        }

        var values = ProcessInfo.processInfo.environment

        if let dotenvURL = dotenvURL() {
            let dotenvValues = try loadDotenvValues(from: dotenvURL)
            for (key, value) in dotenvValues where values[key] == nil {
                values[key] = value
            }
        }

        guard let apiKey = values["OPENAI_API_KEY"], !apiKey.isEmpty else {
            throw AppConfigError.missingOpenAIAPIKey
        }

        let baseURLString = values["OPENAI_BASE_URL"] ?? "https://api.bltcy.ai/v1"
        guard let baseURL = URL(string: baseURLString) else {
            throw AppConfigError.invalidOpenAIBaseURL(baseURLString)
        }

        let transcriptionPrompt = values["OPENAI_TRANSCRIPTION_PROMPT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return AppConfig(
            openAIAPIKey: apiKey,
            openAIBaseURL: baseURL,
            transcriptionPrompt: transcriptionPrompt
        )
    }

    static func loadForSettings() -> AppConfigDraft {
        if let persisted = try? loadPersistedConfig() {
            return AppConfigDraft(
                openAIAPIKey: persisted.openAIAPIKey,
                openAIBaseURL: persisted.openAIBaseURL.absoluteString,
                transcriptionPrompt: persisted.transcriptionPrompt
            )
        }

        var values = ProcessInfo.processInfo.environment

        if let dotenvURL = dotenvURL(), let dotenvValues = try? loadDotenvValues(from: dotenvURL) {
            for (key, value) in dotenvValues where values[key] == nil {
                values[key] = value
            }
        }

        return AppConfigDraft(
            openAIAPIKey: values["OPENAI_API_KEY"] ?? "",
            openAIBaseURL: values["OPENAI_BASE_URL"] ?? "https://api.bltcy.ai/v1",
            transcriptionPrompt: values["OPENAI_TRANSCRIPTION_PROMPT"] ?? ""
        )
    }

    static func save(_ draft: AppConfigDraft) throws -> AppConfig {
        let normalizedAPIKey = draft.openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAPIKey.isEmpty else {
            throw AppConfigError.missingOpenAIAPIKey
        }

        let normalizedBaseURL = draft.openAIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = URL(string: normalizedBaseURL), !normalizedBaseURL.isEmpty else {
            throw AppConfigError.invalidOpenAIBaseURL(draft.openAIBaseURL)
        }

        let normalizedPrompt = draft.transcriptionPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        let config = AppConfig(
            openAIAPIKey: normalizedAPIKey,
            openAIBaseURL: baseURL,
            transcriptionPrompt: normalizedPrompt
        )
        try FileManager.default.createDirectory(at: appSupportDirectory(), withIntermediateDirectories: true)
        let payload = PersistedAppConfig(
            openAIAPIKey: config.openAIAPIKey,
            openAIBaseURL: config.openAIBaseURL.absoluteString,
            transcriptionPrompt: config.transcriptionPrompt
        )
        let data = try JSONEncoder().encode(payload)
        try data.write(to: configFileURL(), options: .atomic)
        return config
    }

    static func configFileURL() -> URL {
        appSupportDirectory().appendingPathComponent("config.json")
    }

    static func loadPreferences() -> AppPreferences {
        guard let persisted = try? loadPersistedPreferences() else {
            return AppPreferences()
        }
        return persisted
    }

    static func savePreferences(_ preferences: AppPreferences) throws {
        try FileManager.default.createDirectory(at: appSupportDirectory(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(preferences)
        try data.write(to: preferencesFileURL(), options: .atomic)
    }

    static func appSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Transcribe", isDirectory: true)
    }

    private static func dotenvURL() -> URL? {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            cwd.appendingPathComponent(".env"),
            cwd.deletingLastPathComponent().appendingPathComponent(".env"),
        ]

        return candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }

    private static func loadDotenvValues(from url: URL) throws -> [String: String] {
        let text = try String(contentsOf: url, encoding: .utf8)
        var values: [String: String] = [:]

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }

            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else {
                continue
            }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            values[key] = value
        }

        return values
    }

    private static func loadPersistedConfig() throws -> AppConfig? {
        let url = configFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        let persisted = try JSONDecoder().decode(PersistedAppConfig.self, from: data)
        guard let baseURL = URL(string: persisted.openAIBaseURL) else {
            throw AppConfigError.invalidOpenAIBaseURL(persisted.openAIBaseURL)
        }
        guard !persisted.openAIAPIKey.isEmpty else {
            throw AppConfigError.missingOpenAIAPIKey
        }

        return AppConfig(
            openAIAPIKey: persisted.openAIAPIKey,
            openAIBaseURL: baseURL,
            transcriptionPrompt: persisted.transcriptionPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }

    private static func preferencesFileURL() -> URL {
        appSupportDirectory().appendingPathComponent("preferences.json")
    }

    private static func loadPersistedPreferences() throws -> AppPreferences? {
        let url = preferencesFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AppPreferences.self, from: data)
    }
}

struct AppConfigDraft {
    var openAIAPIKey: String
    var openAIBaseURL: String
    var transcriptionPrompt: String
}

private struct PersistedAppConfig: Codable {
    let openAIAPIKey: String
    let openAIBaseURL: String
    let transcriptionPrompt: String?
}

struct AppPreferences: Codable {
    var muteSpeakerWhileRecording = false
}

enum AppConfigError: LocalizedError {
    case missingOpenAIAPIKey
    case invalidOpenAIBaseURL(String)

    var errorDescription: String? {
        switch self {
        case .missingOpenAIAPIKey:
            return "Missing OPENAI_API_KEY"
        case .invalidOpenAIBaseURL(let url):
            return "Invalid OPENAI_BASE_URL: \(url)"
        }
    }
}
