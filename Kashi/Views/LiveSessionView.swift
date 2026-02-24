import SwiftUI
import SwiftData

struct LiveSessionView: View {
    @ObservedObject var transcription: TranscriptionService
    @Bindable var meeting: Meeting
    let audioCapture: AudioCaptureService
    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 0) {
                SessionControlsView(
                    audioCapture: audioCapture,
                    transcription: transcription,
                    onStart: onStart,
                    onStop: onStop
                )
                if let msg = transcription.errorMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
                TranscriptView(segments: transcription.segments)
                    .frame(minWidth: 320)
            }
            .frame(minWidth: 360)
            VStack(alignment: .leading, spacing: 0) {
                Text("Notes")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)
                NoteEditorView(text: $meeting.notesMarkdown)
                    .frame(minWidth: 240)
            }
            .frame(minWidth: 280)
        }
    }
}
