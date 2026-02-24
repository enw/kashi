import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct MeetingDetailView: View {
    @Bindable var meeting: Meeting
    var isLive: Bool
    @StateObject private var ollama = OllamaService()

    var body: some View {
        TabView {
            transcriptTab
            notesTab
            summaryTab
            chatTab
        }
        .tabViewStyle(.automatic)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Copy as Markdown") { copyMeetingAsMarkdown() }
                    Button("Export…") { exportMeeting() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    private func copyMeetingAsMarkdown() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(meetingMarkdown(), forType: .string)
    }

    private func exportMeeting() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(meeting.title).md"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? meetingMarkdown().write(to: url, atomically: true, encoding: .utf8)
        }
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
        NoteEditorView(text: $meeting.notesMarkdown)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem { Label("Notes", systemImage: "note.text") }
    }

    private var summaryTab: some View {
        AISummaryView(meeting: meeting, ollama: ollama)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem { Label("Summary", systemImage: "sparkles") }
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
