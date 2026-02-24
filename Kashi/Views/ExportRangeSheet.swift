import SwiftUI

enum ExportRangeFormat: String, CaseIterable {
    case transcriptOnly = "Transcripts only"
    case summaryOnly = "Summaries only"
    case full = "Full (transcript + notes + summary)"
}

struct ExportRangeSheet: View {
    var meetings: [Meeting]
    var onDismiss: () -> Void

    @State private var fromDate: Date
    @State private var toDate: Date
    @State private var format: ExportRangeFormat = .full

    init(meetings: [Meeting], onDismiss: @escaping () -> Void) {
        self.meetings = meetings
        self.onDismiss = onDismiss
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        _fromDate = State(initialValue: weekAgo)
        _toDate = State(initialValue: now)
    }

    private var filteredMeetings: [Meeting] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: fromDate)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: toDate)) ?? toDate
        return meetings.filter { m in m.date >= start && m.date < end }
    }

    private var exportContent: String {
        var content = "# Meetings export\n\n"
        content += "From \(fromDate.formatted(date: .abbreviated, time: .omitted)) to \(toDate.formatted(date: .abbreviated, time: .omitted))\n\n"
        content += "---\n\n"
        for meeting in filteredMeetings.sorted(by: { $0.date > $1.date }) {
            content += meetingExportContent(meeting)
            content += "\n---\n\n"
        }
        return content
    }

    private func meetingExportContent(_ meeting: Meeting) -> String {
        switch format {
        case .transcriptOnly:
            return rawTranscriptForMeeting(meeting)
        case .summaryOnly:
            return summaryForMeeting(meeting)
        case .full:
            return fullMarkdownForMeeting(meeting)
        }
    }

    private func rawTranscriptForMeeting(_ meeting: Meeting) -> String {
        var text = "## \(meeting.title)\n\n"
        text += "Date: \(meeting.date.formatted(date: .long, time: .shortened))\n\n"
        for seg in meeting.segments.sorted(by: { $0.timestamp < $1.timestamp }) {
            let who = seg.speaker == .me ? "Me" : "Others"
            text += "**\(who):** \(seg.text)\n\n"
        }
        return text
    }

    private func summaryForMeeting(_ meeting: Meeting) -> String {
        var text = "## \(meeting.title)\n\n"
        text += "Date: \(meeting.date.formatted(date: .long, time: .shortened))\n\n"
        text += meeting.aiSummaryMarkdown ?? "(No summary)"
        text += "\n\n"
        return text
    }

    private func fullMarkdownForMeeting(_ meeting: Meeting) -> String {
        var md = "## \(meeting.title)\n\n"
        md += "Date: \(meeting.date.formatted(date: .long, time: .shortened))\n\n"
        md += "### Transcript\n\n"
        for seg in meeting.segments.sorted(by: { $0.timestamp < $1.timestamp }) {
            let who = seg.speaker == .me ? "Me" : "Others"
            md += "**\(who):** \(seg.text)\n\n"
        }
        if !meeting.notesMarkdown.isEmpty {
            md += "### Notes\n\n\(meeting.notesMarkdown)\n\n"
        }
        if let s = meeting.aiSummaryMarkdown, !s.isEmpty {
            md += "### Summary\n\n\(s)\n\n"
        }
        return md
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export date range")
                .font(.headline)
            HStack {
                DatePicker("From", selection: $fromDate, displayedComponents: .date)
                DatePicker("To", selection: $toDate, displayedComponents: .date)
            }
            Picker("Format", selection: $format) {
                ForEach(ExportRangeFormat.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.radioGroup)
            Text("\(filteredMeetings.count) meeting(s) in range")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { onDismiss() }
                Button("Export…") {
                    exportToFile()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 400)
    }

    private func exportToFile() {
        let defaultName = "Meetings \(fromDate.formatted(date: .abbreviated, time: .omitted)) to \(toDate.formatted(date: .abbreviated, time: .omitted)).md"
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = defaultName
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? exportContent.write(to: url, atomically: true, encoding: .utf8)
            onDismiss()
        }
    }
}
