import Foundation

enum TranscriptionServiceError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid transcription response"
        case .apiError(let statusCode, let message):
            return "OpenAI transcription failed (\(statusCode)): \(message)"
        case .emptyTranscript:
            return "OpenAI returned an empty transcript"
        }
    }
}

struct TranscriptionResult {
    let text: String
    let elapsedSeconds: TimeInterval
}

actor TranscriptionService {
    private let config: AppConfig
    private let session: URLSession

    init(config: AppConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func transcribe(fileURL: URL) async throws -> TranscriptionResult {
        let endpoint = config.openAIBaseURL.appendingPathComponent("audio/transcriptions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("Bearer \(config.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let started = Date()
        request.httpBody = try makeMultipartBody(fileURL: fileURL, boundary: boundary)

        let (data, response) = try await session.data(for: request)
        let elapsed = Date().timeIntervalSince(started)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
            throw TranscriptionServiceError.apiError(statusCode: httpResponse.statusCode, message: message)
        }

        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            throw TranscriptionServiceError.emptyTranscript
        }

        return TranscriptionResult(text: text, elapsedSeconds: elapsed)
    }

    private func makeMultipartBody(fileURL: URL, boundary: String) throws -> Data {
        let fileData = try Data(contentsOf: fileURL)
        let mimeType = mimeType(for: fileURL.pathExtension.lowercased())
        var body = Data()

        func append(_ string: String) {
            body.append(Data(string.utf8))
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        append("gpt-4o-mini-transcribe\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n")
        append("text\r\n")

        if !config.transcriptionPrompt.isEmpty {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
            append("\(config.transcriptionPrompt)\r\n")
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        append("\r\n")

        append("--\(boundary)--\r\n")
        return body
    }

    private func mimeType(for pathExtension: String) -> String {
        switch pathExtension {
        case "m4a":
            return "audio/m4a"
        case "wav":
            return "audio/wav"
        case "mp3":
            return "audio/mpeg"
        default:
            return "application/octet-stream"
        }
    }
}
