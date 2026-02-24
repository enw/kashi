import SwiftUI
import SwiftData

struct MeetingChatView: View {
    @Bindable var meeting: Meeting
    let ollama: OllamaService
    @State private var question = ""
    @State private var answer = ""
    @State private var isStreaming = false

    private var transcriptContext: String {
        NoteStructuringService.transcriptText(from: meeting.segments)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                if !answer.isEmpty {
                    Text(answer)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))

            HStack {
                TextField("Ask about this meeting…", text: $question)
                    .textFieldStyle(.roundedBorder)
                Button("Ask") {
                    askQuestion()
                }
                .disabled(question.isEmpty || isStreaming)
            }
            .padding(8)
        }
    }

    private func askQuestion() {
        let q = question
        question = ""
        answer = ""
        isStreaming = true
        Task {
            defer { isStreaming = false }
            var full = ""
            do {
                for try await delta in ollama.streamChat(
                    model: "llama3.2",
                    system: "Answer based only on the following meeting transcript. Be concise.",
                    messages: [
                        (role: "user", content: "Transcript:\n\(transcriptContext)\n\nQuestion: \(q)")
                    ]
                ) {
                    full += delta
                    answer = full
                }
            } catch {
                answer = "Error: \(error.localizedDescription)"
            }
        }
    }
}
