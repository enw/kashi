import Foundation

/// A single segment of transcribed speech with speaker and timestamp.
struct TranscriptSegment: Identifiable, Equatable {
    let id: UUID
    let text: String
    let speaker: Speaker
    let timestamp: Date

    init(id: UUID = UUID(), text: String, speaker: Speaker, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.speaker = speaker
        self.timestamp = timestamp
    }

    enum Speaker: String, Equatable {
        case me
        case others
    }
}
