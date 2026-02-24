import SwiftUI
import SwiftData

struct MeetingSidebarView: View {
    var meetings: [Meeting]
    @Binding var selectedMeetingId: UUID?
    var currentMeetingId: UUID?
    var calendarService: CalendarService?
    var onStartNew: (() -> Void)?
    var onExportRange: (() -> Void)?
    var onShowActions: (() -> Void)?
    var onExportData: (() -> Void)?
    var onImportData: (() -> Void)?

    var body: some View {
        List(selection: $selectedMeetingId) {
            Section {
                HStack(spacing: 10) {
                    KashiLogoView(size: 28)
                    Text("Kashi")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            if let calendar = calendarService {
                UpcomingMeetingsView(calendar: calendar)
            }
            Section("Meetings") {
                if let onExportData = onExportData {
                    Button(action: onExportData) {
                        Label("Export data…", systemImage: "square.and.arrow.up.on.square")
                    }
                }
                if let onImportData = onImportData {
                    Button(action: onImportData) {
                        Label("Import data…", systemImage: "square.and.arrow.down.on.square")
                    }
                }
                if let onShowActions = onShowActions {
                    Button(action: onShowActions) {
                        Label("Action items", systemImage: "checklist")
                    }
                }
                if let onExportRange = onExportRange {
                    Button(action: onExportRange) {
                        Label("Export range…", systemImage: "square.and.arrow.down")
                    }
                }
                if let onStartNew = onStartNew {
                    Button(action: onStartNew) {
                        Label("New meeting", systemImage: "plus.circle.fill")
                    }
                }
                ForEach(meetings) { meeting in
                    MeetingRowView(meeting: meeting, isCurrent: meeting.id == currentMeetingId)
                        .tag(meeting.id)
                }
            }
        }
        .listStyle(.sidebar)
    }
}

struct MeetingRowView: View {
    let meeting: Meeting
    let isCurrent: Bool

    private var title: String {
        meeting.title.isEmpty ? "Untitled" : meeting.title
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text(meeting.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if isCurrent {
                Spacer()
                Text("Live")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MeetingSidebarView(meetings: [], selectedMeetingId: .constant(nil), currentMeetingId: nil, calendarService: nil, onStartNew: nil, onExportRange: nil, onShowActions: nil, onExportData: nil, onImportData: nil)
        .frame(width: 220)
        .modelContainer(for: [Meeting.self, MeetingTranscriptSegment.self, Person.self, Team.self, ActionItem.self], inMemory: true)
}
