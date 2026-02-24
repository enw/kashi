import Foundation
import WhisperKit
import Combine

/// Loads WhisperKit, accepts audio buffers, and publishes transcript segments.
@MainActor
final class TranscriptionService: ObservableObject {
    @Published private(set) var segments: [TranscriptSegment] = []
    @Published private(set) var status: Status = .idle
    @Published private(set) var errorMessage: String?

    private var whisperKit: WhisperKit?
    private var micBuffer: [Float] = []
    private var systemBuffer: [Float] = []
    private let segmentDuration: TimeInterval = 5.0
    private let sampleRate: Double = 16000
    private let samplesPerSegment: Int
    private var processingTask: Task<Void, Never>?

    /// Called when a new transcript segment is finalized (for persistence).
    var onSegmentFinalized: ((TranscriptSegment) -> Void)?

    init() {
        self.samplesPerSegment = Int(segmentDuration * sampleRate)
    }

    enum Status: Equatable {
        case idle
        case loadingModel
        case ready
        case transcribing
        case failed(String)
    }

    func loadModel() async {
        if case .ready = status { return }
        if case .loadingModel = status { return }
        status = .loadingModel
        errorMessage = nil

        do {
            let wk = try await WhisperKit(
                model: "base.en",
                verbose: false,
                prewarm: true
            )
            whisperKit = wk
            status = .ready
        } catch {
            status = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    /// Append mic audio (speaker: .me)
    func appendAudio(_ samples: [Float]) {
        appendAudio(samples, speaker: .me)
    }

    /// Append audio from a given speaker (mic = .me, system = .others).
    func appendAudio(_ samples: [Float], speaker: TranscriptSegment.Speaker) {
        guard case .ready = status, whisperKit != nil else { return }
        switch speaker {
        case .me:
            micBuffer.append(contentsOf: samples)
            if micBuffer.count >= samplesPerSegment {
                flushSegment(speaker: .me)
            }
        case .others:
            systemBuffer.append(contentsOf: samples)
            if systemBuffer.count >= samplesPerSegment {
                flushSegment(speaker: .others)
            }
        }
    }

    func flushSegment() {
        if micBuffer.count > 0 { flushSegment(speaker: .me) }
        if systemBuffer.count > 0 { flushSegment(speaker: .others) }
    }

    private func flushSegment(speaker: TranscriptSegment.Speaker) {
        let toProcess: [Float]
        switch speaker {
        case .me:
            guard micBuffer.count > 0 else { return }
            toProcess = micBuffer
            micBuffer = []
        case .others:
            guard systemBuffer.count > 0 else { return }
            toProcess = systemBuffer
            systemBuffer = []
        }
        processChunk(toProcess, speaker: speaker)
    }

    private func processChunk(_ samples: [Float], speaker: TranscriptSegment.Speaker) {
        guard samples.count > 0 else { return }
        guard let wk = whisperKit else { return }

        let onFinalized = onSegmentFinalized // capture by value
        let task = Task.detached(priority: .userInitiated) { [wk, speaker, onFinalized, samples] in
            await MainActor.run { [weak self] in self?.status = .transcribing }

            // Compute results into immutable locals to satisfy @Sendable capture rules
            let producedSegment: TranscriptSegment?
            let producedError: String?
            do {
                let results = try await wk.transcribe(audioArray: samples)
                let text = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                if Self.isMeaningfulTranscript(text) {
                    producedSegment = TranscriptSegment(text: text, speaker: speaker, timestamp: Date())
                } else {
                    producedSegment = nil
                }
                producedError = nil
            } catch {
                producedSegment = nil
                producedError = error.localizedDescription
            }

            await MainActor.run { [weak self, producedSegment, producedError, onFinalized] in
                if let segment = producedSegment {
                    self?.segments.append(segment)
                    onFinalized?(segment)
                }
                if let errorMessage = producedError {
                    self?.errorMessage = errorMessage
                }
                self?.status = .ready
                self?.processingTask = nil
            }
        }
        processingTask = task
    }

    func clearTranscript() {
        segments.removeAll()
        micBuffer.removeAll()
        systemBuffer.removeAll()
    }

    func stopAndClear() {
        processingTask?.cancel()
        processingTask = nil
        clearTranscript()
        status = .ready
    }

    /// Treats silence/placeholder tokens as non-meaningful so we don't show them in the transcript.
    private nonisolated static func isMeaningfulTranscript(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return false }
        let lower = t.lowercased()
        let silenceMarkers = [
            "[blank_audio]",
            "[blank audio]",
            "(silence)",
            "[silence]",
            "[no speech]",
            "...",
            "…"
        ]
        if silenceMarkers.contains(lower) { return false }
        if lower.hasPrefix("[blank") { return false }
        return true
    }
}
