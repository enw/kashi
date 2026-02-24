import SwiftUI

struct SessionControlsView: View {
    @ObservedObject var audioCapture: AudioCaptureService
    @ObservedObject var transcription: TranscriptionService
    var onStart: () -> Void
    var onStop: () -> Void

    private var isCapturing: Bool { audioCapture.isRunning }
    private var canStart: Bool {
        transcription.status == .ready || transcription.status == .idle
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button(action: {
                    if isCapturing { onStop() } else { onStart() }
                }) {
                    Label(
                        isCapturing ? "Stop" : "Start",
                        systemImage: isCapturing ? "stop.circle.fill" : "record.circle"
                    )
                    .font(.headline)
                    .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canStart && !isCapturing)
                .tint(isCapturing ? .red : .accentColor)

                if isCapturing {
                    AudioLevelView(level: audioCapture.audioLevel)
                }

                Spacer()

                StatusBadge(status: transcription.status)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding()
    }
}

struct AudioLevelView: View {
    let level: Float
    private let barCount = 5
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: i))
                    .frame(width: 4, height: CGFloat(8 + i * 4))
                    .scaleEffect(y: barScale(for: i), anchor: .bottom)
            }
        }
        .frame(height: 24)
        .animation(.easeInOut(duration: 0.1), value: level)
    }

    private func barScale(for index: Int) -> CGFloat {
        let threshold = Float(index + 1) / Float(barCount)
        return CGFloat(max(0.2, level >= threshold ? 1 : level / threshold))
    }

    private func barColor(for index: Int) -> Color {
        let threshold = Float(index + 1) / Float(barCount)
        return level >= threshold ? Color.green : Color.green.opacity(0.4)
    }
}

struct StatusBadge: View {
    let status: TranscriptionService.Status
    var body: some View {
        Text(statusLabel)
            .font(.caption)
            .foregroundStyle(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .clipShape(Capsule())
    }

    private var statusLabel: String {
        switch status {
        case .idle: return "Idle"
        case .loadingModel: return "Loading model…"
        case .ready: return "Ready"
        case .transcribing: return "Transcribing…"
        case .failed: return "Error"
        }
    }

    private var statusColor: Color {
        switch status {
        case .idle, .ready: return .secondary
        case .loadingModel, .transcribing: return .blue
        case .failed: return .red
        }
    }
}

#Preview {
    SessionControlsView(
        audioCapture: AudioCaptureService(),
        transcription: TranscriptionService(),
        onStart: {},
        onStop: {}
    )
    .frame(width: 500)
}
