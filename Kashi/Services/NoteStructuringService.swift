import Foundation

/// Uses Ollama to turn a raw transcript + notes into structured markdown.
@MainActor
final class NoteStructuringService: ObservableObject {
    @Published private(set) var isGenerating = false
    @Published private(set) var errorMessage: String?

    private let ollama: OllamaService
    private var currentTask: Task<Void, Never>?

    init(ollama: OllamaService = OllamaService()) {
        self.ollama = ollama
    }

    /// Build full transcript text from meeting segments (Me / Others).
    static func transcriptText(from segments: [MeetingTranscriptSegment]) -> String {
        segments.sorted { $0.timestamp < $1.timestamp }.map { seg in
            let who = seg.speaker == .me ? "Me" : "Others"
            return "[\(who)] \(seg.text)"
        }.joined(separator: "\n")
    }

    /// Generate structured notes and return the markdown string.
    func generateStructuredNotes(
        transcript: String,
        notes: String,
        template: MeetingTemplate,
        model: String = "llama3.2"
    ) async throws -> String {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        let userContent = """
        ## Raw transcript
        \(transcript)

        ## Manual notes
        \(notes.isEmpty ? "(none)" : notes)

        Produce the structured meeting notes in markdown as requested.
        """

        var result = ""
        for try await delta in ollama.streamChat(
            model: model,
            system: template.systemPrompt,
            messages: [(role: "user", content: userContent)]
        ) {
            result += delta
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func cancel() {
        currentTask?.cancel()
    }
}
