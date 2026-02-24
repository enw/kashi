import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \Meeting.date, order: .reverse) private var meetings: [Meeting]
    @StateObject private var audioCapture = AudioCaptureService()
    @StateObject private var transcription = TranscriptionService()
    @State private var systemCapture: SystemAudioCaptureService?
    @State private var hasRequestedPermission = false
    @State private var currentMeeting: Meeting?
    @State private var selectedMeetingId: UUID?
    @State private var sessionStartTime: Date?
    @StateObject private var calendarService = CalendarService()
    @State private var showExportRangeSheet = false
    @State private var showGlobalActions = false
    @State private var isImporting = false

    private var selectedMeeting: Meeting? {
        meetings.first { $0.id == selectedMeetingId }
    }

    var body: some View {
        NavigationSplitView {
            MeetingSidebarView(
                meetings: meetings,
                selectedMeetingId: $selectedMeetingId,
                currentMeetingId: currentMeeting?.id,
                calendarService: calendarService,
                onStartNew: startSession,
                onExportRange: { showExportRangeSheet = true },
                onShowActions: {
                    showGlobalActions = true
                    selectedMeetingId = nil
                },
                onExportData: exportData,
                onImportData: { importData() }
            )
            .frame(minWidth: 220)
            .sheet(isPresented: $showExportRangeSheet) {
                ExportRangeSheet(meetings: meetings) {
                    showExportRangeSheet = false
                }
            }
        } detail: {
            detailContent
                .frame(minWidth: 600, minHeight: 400)
        }
        .task {
            guard !hasRequestedPermission else { return }
            hasRequestedPermission = true
            _ = await audioCapture.requestPermission()
            _ = await calendarService.requestAccess()
            calendarService.fetchUpcomingEvents()
            await transcription.loadModel()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            calendarService.fetchUpcomingEvents()
        }
        .onDisappear {
            stopSession()
            audioCapture.stop()
            transcription.stopAndClear()
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if showGlobalActions {
            GlobalActionItemsView()
        } else if let meeting = selectedMeeting, meeting.id == currentMeeting?.id {
            LiveSessionView(
                transcription: transcription,
                meeting: meeting,
                audioCapture: audioCapture,
                onStart: startSession,
                onStop: stopSession
            )
        } else if let meeting = selectedMeeting {
            MeetingDetailView(meeting: meeting, isLive: false)
        } else {
            VStack(spacing: 16) {
                Text("No meeting selected")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Start a new session or select a meeting from the sidebar.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func startSession() {
        let meeting = Meeting(
            title: "Meeting \(Date().formatted(date: .abbreviated, time: .shortened))",
            date: Date()
        )
        modelContext.insert(meeting)
        currentMeeting = meeting
        selectedMeetingId = meeting.id
        sessionStartTime = Date()

        transcription.onSegmentFinalized = { [meeting, modelContext] segment in
            let persisted = MeetingTranscriptSegment(
                text: segment.text,
                speaker: segment.speaker,
                timestamp: segment.timestamp,
                meeting: meeting
            )
            modelContext.insert(persisted)
            meeting.segments.append(persisted)
            try? modelContext.save()
        }
        transcription.clearTranscript()

        audioCapture.onAudioBuffer = { [weak transcription] samples in
            DispatchQueue.main.async {
                transcription?.appendAudio(samples, speaker: .me)
            }
        }
        try? audioCapture.start()

        if #available(macOS 14.2, *) {
            let sys = SystemAudioCaptureService()
            sys.onAudioBuffer = { [weak transcription] samples in
                DispatchQueue.main.async {
                    transcription?.appendAudio(samples, speaker: .others)
                }
            }
            sys.start()
            systemCapture = sys
        }
    }

    private func stopSession() {
        audioCapture.stop()
        if #available(macOS 14.2, *) {
            systemCapture?.stop()
            systemCapture = nil
        }
        transcription.flushSegment()
        transcription.onSegmentFinalized = nil

        if let meeting = currentMeeting, let start = sessionStartTime {
            meeting.durationSeconds = Date().timeIntervalSince(start)
            try? modelContext.save()
        }
        currentMeeting = nil
    }

    private func exportData() {
        do {
            let data = try ImportExportService.exportAll(modelContext: modelContext)
            let panel = NSSavePanel()
            panel.allowedFileTypes = ["json"]
            panel.nameFieldStringValue = "Kashi-export.json"
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                try? data.write(to: url)
            }
        } catch {
            // For now, ignore export errors; could surface via UI later.
        }
    }

    private func importData() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["json"]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                try ImportExportService.importFrom(data: data, into: modelContext)
            } catch {
                // For now, ignore import errors; could surface via UI later.
            }
        }
    }

}

#Preview {
    ContentView()
        .frame(width: 900, height: 600)
        .modelContainer(for: [Meeting.self, MeetingTranscriptSegment.self, Person.self, Team.self, ActionItem.self], inMemory: true)
        .environmentObject(AppState.shared)
}
