import Foundation
import CoreAudio
import AVFoundation
import Combine

/// Captures system (loopback) audio via CoreAudio Process Tap and outputs Float32 mono at 16 kHz.
@available(macos 14.2, *)
final class SystemAudioCaptureService: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var errorMessage: String?

    private var tapID: AudioObjectID = 0
    private var aggregateDeviceID: AudioObjectID = 0
    private var ioProcID: AudioDeviceIOProcID?
    private let processingQueue = DispatchQueue(label: "kashi.systemaudio.processing", qos: .userInitiated)
    private let targetSampleRate: Double = 16000

    /// Callback for Float32 mono 16 kHz samples (system/others audio).
    var onAudioBuffer: (([Float]) -> Void)?

    override init() {
        super.init()
    }

    func start() {
        guard !isRunning else { return }
        errorMessage = nil

        // Create tap description: stereo global tap, exclude no processes (capture all).
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.name = "Kashi System Tap"
        description.isPrivate = true
        description.muteBehavior = .unmuted
        description.isExclusive = true

        var tapIDOut: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
        var status = AudioHardwareCreateProcessTap(description, &tapIDOut)
        guard status == noErr else {
            errorMessage = "AudioHardwareCreateProcessTap failed: \(status)"
            return
        }
        tapID = tapIDOut

        let tapUUIDString = description.uuid.uuidString
        let tapsList: [[String: Any]] = [
            [
                kAudioSubTapUIDKey: tapUUIDString,
                kAudioSubTapDriftCompensationKey: true
            ]
        ]
        let aggregateUID = "com.kashi.systemtap.\(UUID().uuidString)"
        let aggregateProps: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Kashi System Tap Device",
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceTapListKey: tapsList,
            kAudioAggregateDeviceTapAutoStartKey: false,
            kAudioAggregateDeviceIsPrivateKey: true
        ]

        var aggregateIDOut: AudioObjectID = 0
        status = AudioHardwareCreateAggregateDevice(aggregateProps as CFDictionary, &aggregateIDOut)
        if status != noErr {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = 0
            errorMessage = "AudioHardwareCreateAggregateDevice failed: \(status)"
            return
        }
        aggregateDeviceID = aggregateIDOut

        let onBuffer = self.onAudioBuffer
        let queue = processingQueue
        let block: AudioDeviceIOBlock = { _, inputData, _, _, _ in
            guard inputData.pointee.mNumberBuffers > 0 else { return }
            let buffer = inputData.pointee.mBuffers
            let numFrames = Int(buffer.mDataByteSize) / (Int(buffer.mNumberChannels) * MemoryLayout<Float>.size)
            guard numFrames > 0, let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { return }
            let channels = Int(buffer.mNumberChannels)
            // Downmix to mono (average channels) and resample 48k -> 16k (take ~1/3 samples).
            let srcRate = 48000.0
            let ratio = srcRate / 16000.0
            var mono: [Float] = []
            mono.reserveCapacity(Int(Double(numFrames) / ratio) + 1)
            for i in 0..<numFrames {
                let srcIdx = i * channels
                var sum: Float = 0
                for c in 0..<channels { sum += data[srcIdx + c] }
                mono.append(sum / Float(channels))
            }
            var downsampled: [Float] = []
            downsampled.reserveCapacity(mono.count / Int(ratio) + 1)
            var idx = 0.0
            while Int(idx) < mono.count {
                downsampled.append(mono[Int(idx)])
                idx += ratio
            }
            if !downsampled.isEmpty {
                queue.async {
                    onBuffer?(downsampled)
                }
            }
        }

        var ioProcIDOut: AudioDeviceIOProcID?
        status = AudioDeviceCreateIOProcIDWithBlock(&ioProcIDOut, aggregateDeviceID, nil, block)
        guard status == noErr, let procID = ioProcIDOut else {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            AudioHardwareDestroyProcessTap(tapID)
            aggregateDeviceID = 0
            tapID = 0
            errorMessage = "AudioDeviceCreateIOProcIDWithBlock failed: \(status)"
            return
        }
        ioProcID = procID

        status = AudioDeviceStart(aggregateDeviceID, procID)
        if status != noErr {
            AudioDeviceDestroyIOProcID(aggregateDeviceID, procID)
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            AudioHardwareDestroyProcessTap(tapID)
            ioProcID = nil
            aggregateDeviceID = 0
            tapID = 0
            errorMessage = "AudioDeviceStart failed: \(status)"
            return
        }

        isRunning = true
    }

    func stop() {
        guard isRunning, let procID = ioProcID else { return }
        AudioDeviceStop(aggregateDeviceID, procID)
        AudioDeviceDestroyIOProcID(aggregateDeviceID, procID)
        AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
        AudioHardwareDestroyProcessTap(tapID)
        ioProcID = nil
        aggregateDeviceID = 0
        tapID = 0
        isRunning = false
        errorMessage = nil
    }
}
