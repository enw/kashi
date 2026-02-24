import Foundation
import AVFoundation
import Combine

/// Captures microphone audio and outputs PCM Float32 buffers at 16 kHz for WhisperKit.
final class AudioCaptureService: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var permissionGranted = false

    private let engine = AVAudioEngine()
    private let sampleRate: Double = 16000
    private let bufferSize: AVAudioFrameCount = 4096
    private var cancellables = Set<AnyCancellable>()

    /// Callback for raw Float32 audio samples (mono, 16 kHz).
    var onAudioBuffer: (([Float]) -> Void)?

    override init() {
        super.init()
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func start() throws {
        guard permissionGranted else {
            throw AudioCaptureError.permissionDenied
        }
        guard !isRunning else { return }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioCaptureError.formatCreationFailed
        }

        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        guard let converter else {
            throw AudioCaptureError.converterCreationFailed
        }

        let onBuffer = self.onAudioBuffer
        let reportLevel: (Float) -> Void = { [weak self] level in
            DispatchQueue.main.async { self?.audioLevel = level }
        }
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.processBuffer(buffer, converter: converter, targetFormat: targetFormat, onBuffer: onBuffer, reportLevel: reportLevel)
        }

        try engine.start()
        DispatchQueue.main.async { [weak self] in
            self?.isRunning = true
        }
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        DispatchQueue.main.async { [weak self] in
            self?.isRunning = false
            self?.audioLevel = 0
        }
    }

    private func processBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat,
        onBuffer: (([Float]) -> Void)?,
        reportLevel: (Float) -> Void
    ) {
        let inputFrameCount = buffer.frameLength
        let outputFrameCapacity = AVAudioFrameCount(Double(inputFrameCount) * targetFormat.sampleRate / buffer.format.sampleRate)
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: max(outputFrameCapacity, 1)
        ) else { return }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        if error != nil { return }

        let frameLength = outputBuffer.frameLength
        guard let channelData = outputBuffer.floatChannelData?[0] else { return }
        let floats = Array(UnsafeBufferPointer(start: channelData, count: Int(frameLength)))
        onBuffer?(floats)
        reportLevel(computeLevel(floats))
    }

    private func computeLevel(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(0) { $0 + $1 * $1 }
        let rms = sqrt(sum / Float(samples.count))
        return min(1, rms * 10)
    }
}

enum AudioCaptureError: LocalizedError {
    case permissionDenied
    case formatCreationFailed
    case converterCreationFailed
    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Microphone access was denied."
        case .formatCreationFailed: return "Could not create target audio format."
        case .converterCreationFailed: return "Could not create audio converter."
        }
    }
}
