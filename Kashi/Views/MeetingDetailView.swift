import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct MeetingDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var meeting: Meeting
    var isLive: Bool
    var onDeleted: (() -> Void)?
    @AppStorage("ollamaBaseURL") private var ollamaBaseURL = "http://127.0.0.1:11434"
    @AppStorage("ollamaModel") private var ollamaModel = "llama3.2"
    @StateObject private var ollama = OllamaService()
    @State private var isEditingNotes = false
    @State private var showDeleteConfirm = false

    var body: some View {
        TabView {
            transcriptTab
            notesTab
            summaryTab
            actionsTab
            chatTab
        }
        .tabViewStyle(.automatic)
        .onAppear { applyOllamaSettings() }
        .onChange(of: ollamaBaseURL) { _, _ in applyOllamaSettings() }
        .onChange(of: ollamaModel) { _, _ in applyOllamaSettings() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Copy as Markdown") { copyMeetingAsMarkdown() }
                    Button("Export full meeting…") { exportMeeting() }
                    Divider()
                    Button("Download transcript…") { downloadTranscript() }
                    Button("Download summary…") { downloadSummary() }
                    if !isLive {
                        Divider()
                        Button("Delete Meeting…", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .confirmationDialog("Delete this meeting?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteMeeting()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The transcript and notes will be removed. Action items from this meeting will be kept but unlinked.")
        }
    }

    private func applyOllamaSettings() {
        ollama.baseURL = URL(string: ollamaBaseURL.trimmingCharacters(in: .whitespacesAndNewlines))
            ?? OllamaService.defaultBaseURL
        ollama.model = ollamaModel.isEmpty ? "llama3.2" : ollamaModel
    }

    private func copyMeetingAsMarkdown() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(meetingMarkdown(), forType: .string)
    }

    private func exportMeeting() {
        saveToFile(content: meetingMarkdown(), defaultName: "\(meeting.title).md")
    }

    private func downloadTranscript() {
        saveToFile(content: rawTranscriptText(), defaultName: "\(meeting.title) – transcript.md")
    }

    private func downloadSummary() {
        let summary = meeting.aiSummaryMarkdown ?? ""
        saveToFile(content: summary, defaultName: "\(meeting.title) – summary.md")
    }

    private func saveToFile(content: String, defaultName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = defaultName
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func deleteMeeting() {
        modelContext.delete(meeting)
        try? modelContext.save()
        onDeleted?()
    }

    private func rawTranscriptText() -> String {
        var text = "# \(meeting.title) – Transcript\n\n"
        text += "Date: \(meeting.date.formatted(date: .long, time: .shortened))\n\n"
        for seg in meeting.segments.sorted(by: { $0.timestamp < $1.timestamp }) {
            let who = seg.speaker == .me ? "Me" : "Others"
            text += "**\(who):** \(seg.text)\n\n"
        }
        return text
    }

    private func meetingMarkdown() -> String {
        var md = "# \(meeting.title)\n\n"
        md += "Date: \(meeting.date.formatted(date: .long, time: .shortened))\n\n"
        md += "## Transcript\n\n"
        for seg in meeting.segments.sorted(by: { $0.timestamp < $1.timestamp }) {
            let who = seg.speaker == .me ? "Me" : "Others"
            md += "**\(who):** \(seg.text)\n\n"
        }
        if !meeting.notesMarkdown.isEmpty {
            md += "## Notes\n\n\(meeting.notesMarkdown)\n\n"
        }
        if let summary = meeting.aiSummaryMarkdown, !summary.isEmpty {
            md += "## Summary\n\n\(summary)\n"
        }
        return md
    }

    private var transcriptTab: some View {
        ScrollView {
            TranscriptView(segments: meetingSegments)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tabItem { Label("Transcript", systemImage: "text.quote") }
    }

    private var notesTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                if isEditingNotes {
                    Button("Done") { isEditingNotes = false }
                } else {
                    Button("Edit") { isEditingNotes = true }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            if isEditingNotes {
                NoteEditorView(text: $meeting.notesMarkdown)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Group {
                        if meeting.notesMarkdown.isEmpty {
                            Text("No notes yet. Tap Edit to add notes (markdown supported).")
                                .foregroundStyle(.secondary)
                        } else {
                            MarkdownTextView(markdown: meeting.notesMarkdown)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tabItem { Label("Notes", systemImage: "note.text") }
    }

    private var summaryTab: some View {
        AISummaryView(meeting: meeting, ollama: ollama)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem { Label("Summary", systemImage: "sparkles") }
    }

    private var actionsTab: some View {
        MeetingActionItemsView(meeting: meeting)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem { Label("Actions", systemImage: "checklist") }
    }

    private var chatTab: some View {
        MeetingChatView(meeting: meeting, ollama: ollama)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
    }

    private var meetingSegments: [TranscriptSegment] {
        meeting.segments.sorted { $0.timestamp < $1.timestamp }.map { seg in
            TranscriptSegment(
                id: UUID(),
                text: seg.text,
                speaker: seg.speaker,
                timestamp: seg.timestamp
            )
        }
    }
}
