import SwiftUI
import SwiftData

struct AISummaryView: View {
    @Bindable var meeting: Meeting
    @ObservedObject var ollama: OllamaService
    @StateObject private var structuring: NoteStructuringService
    @State private var selectedTemplateId = "general"
    @State private var isGenerating = false

    init(meeting: Meeting, ollama: OllamaService) {
        self.meeting = meeting
        self.ollama = ollama
        _structuring = StateObject(wrappedValue: NoteStructuringService(ollama: ollama))
    }

    private var transcriptText: String {
        NoteStructuringService.transcriptText(from: meeting.segments)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !ollama.isAvailable {
                Text("Ollama is not running. Start it with `ollama serve` and pull a model (e.g. `ollama pull llama3.2`).")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                HStack {
                    Picker("Template", selection: $selectedTemplateId) {
                        ForEach(TemplateService.all) { t in
                            Text(t.name).tag(t.id)
                        }
                    }
                    .frame(width: 180)
                    Button("Generate summary") {
                        generateSummary()
                    }
                    .disabled(meeting.segments.isEmpty || isGenerating)
                }
                .padding(.horizontal)

                if structuring.isGenerating {
                    ProgressView()
                        .padding()
                }
                if let summary = meeting.aiSummaryMarkdown, !summary.isEmpty {
                    ScrollView {
                        MarkdownTextView(markdown: summary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                }
            }
        }
        .task { await ollama.checkAvailability() }
    }

    private func generateSummary() {
        guard let template = TemplateService.template(id: selectedTemplateId) else { return }
        isGenerating = true
        Task {
            defer { isGenerating = false }
            do {
                let result = try await structuring.generateStructuredNotes(
                    transcript: transcriptText,
                    notes: meeting.notesMarkdown,
                    template: template,
                    model: ollama.model
                )
                await MainActor.run { meeting.aiSummaryMarkdown = result }
            } catch {
                await MainActor.run { meeting.aiSummaryMarkdown = "Error: \(error.localizedDescription)" }
            }
        }
    }
}
