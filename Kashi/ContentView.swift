import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioCapture = AudioCaptureService()
    @StateObject private var transcription = TranscriptionService()
    @State private var systemCapture: SystemAudioCaptureService?
    @State private var hasRequestedPermission = false
    @State private var currentMeeting: Meeting?
    @State private var selectedMeeting: Meeting?
    @State private var sessionStartTime: Date?
    @StateObject private var calendarService = CalendarService()

    var body: some View {
        NavigationSplitView {
            MeetingSidebarView(
                selectedMeeting: $selectedMeeting,
                currentMeetingId: currentMeeting?.id,
                calendarService: calendarService,
                onStartNew: startSession
            )
            .frame(minWidth: 220)
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
        if let meeting = selectedMeeting, meeting.id == currentMeeting?.id {
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
        selectedMeeting = meeting
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
    }

}

#Preview {
    ContentView()
        .frame(width: 900, height: 600)
        .modelContainer(for: [Meeting.self, MeetingTranscriptSegment.self], inMemory: true)
}
