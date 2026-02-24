import Foundation

/// Client for Ollama's OpenAI-compatible API (localhost:11434).
final class OllamaService: ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var errorMessage: String?

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.baseURL = baseURL
        self.session = URLSession.shared
    }

    func checkAvailability() async {
        do {
            let (_, response) = try await session.data(from: baseURL.appending(path: "api/tags"))
            isAvailable = (response as? HTTPURLResponse)?.statusCode == 200
            await MainActor.run { errorMessage = isAvailable ? nil : "Ollama returned an error" }
        } catch {
            await MainActor.run {
                isAvailable = false
                errorMessage = "Ollama not reachable: \(error.localizedDescription)"
            }
        }
    }

    /// Stream a chat completion from Ollama (native /api/chat).
    func streamChat(
        model: String = "llama3.2",
        system: String? = nil,
        messages: [(role: String, content: String)],
        temperature: Double = 0.7
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let url = baseURL.appending(path: "api/chat")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            var allMessages: [[String: String]] = []
            if let system = system, !system.isEmpty {
                allMessages.append(["role": "system", "content": system])
            }
            for m in messages {
                allMessages.append(["role": m.role, "content": m.content])
            }

            let body: [String: Any] = [
                "model": model,
                "messages": allMessages,
                "stream": true,
                "options": ["temperature": temperature]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.finish(throwing: error)
                    return
                }
                guard let data = data,
                      let http = response as? HTTPURLResponse,
                      http.statusCode == 200 else {
                    continuation.finish(throwing: OllamaError.requestFailed)
                    return
                }
                Self.parseOllamaStream(data: data) { delta in
                    continuation.yield(delta)
                }
                continuation.finish()
            }
            task.resume()

            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    /// Non-streaming completion (for simpler use cases).
    func complete(
        model: String = "llama3.2",
        system: String? = nil,
        prompt: String,
        temperature: Double = 0.7
    ) async throws -> String {
        var full = ""
        for try await delta in streamChat(model: model, system: system, messages: [(role: "user", content: prompt)], temperature: temperature) {
            full += delta
        }
        return full
    }

    /// Parse Ollama NDJSON stream: each line is a JSON object with optional message.content.
    private static func parseOllamaStream(data: Data, yield: (String) -> Void) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        for line in text.split(separator: "\n") {
            guard let json = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
                  let message = obj["message"] as? [String: Any],
                  let content = message["content"] as? String, !content.isEmpty else { continue }
            yield(content)
        }
    }
}

enum OllamaError: LocalizedError {
    case requestFailed
    var errorDescription: String? { "Ollama request failed." }
}
