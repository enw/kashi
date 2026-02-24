import Foundation

/// Client for Ollama's OpenAI-compatible API. Uses 127.0.0.1 by default to avoid
/// proxy PAC / DNS issues that can break "localhost" (NSURLErrorDomain -1003).
final class OllamaService: ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var errorMessage: String?

    /// Base URL for Ollama (e.g. http://127.0.0.1:11434). Set from Settings.
    var baseURL: URL {
        get { _baseURL }
        set { _baseURL = newValue }
    }
    private var _baseURL: URL
    /// Model name. Set from Settings.
    var model: String {
        get { _model }
        set { _model = newValue }
    }
    private var _model: String
    private let session: URLSession

    static let defaultBaseURL: URL = URL(string: "http://127.0.0.1:11434")!

    init(baseURL: URL? = nil, model: String = "llama3.2") {
        self._baseURL = baseURL ?? Self.defaultBaseURL
        self._model = model
        let config = URLSessionConfiguration.default
        // Bypass proxy for localhost/127.0.0.1 to avoid NSURLErrorDomain -1003 when PAC is used.
        config.connectionProxyDictionary = [
            kCFNetworkProxiesExceptionsList as String: ["127.0.0.1", "localhost"]
        ]
        self.session = URLSession(configuration: config)
    }

    func checkAvailability() async {
        let url = baseURL.appending(path: "api/tags")
        do {
            let (_, response) = try await session.data(from: url)
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            await MainActor.run {
                isAvailable = ok
                errorMessage = ok ? nil : "Ollama returned an error"
            }
        } catch {
            await MainActor.run {
                isAvailable = false
                errorMessage = "Ollama not reachable: \(error.localizedDescription)"
            }
        }
    }

    /// Stream a chat completion from Ollama (native /api/chat).
    func streamChat(
        model useModel: String? = nil,
        system: String? = nil,
        messages: [(role: String, content: String)],
        temperature: Double = 0.7
    ) -> AsyncThrowingStream<String, Error> {
        let url = baseURL.appending(path: "api/chat")
        let modelName = useModel ?? model
        return AsyncThrowingStream { continuation in
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
                "model": modelName,
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
