import Foundation
import SwiftData

@Model
final class Meeting {
    var id: UUID
    var title: String
    var date: Date
    var durationSeconds: Double
    var notesMarkdown: String
    var aiSummaryMarkdown: String?

    @Relationship(deleteRule: .cascade, inverse: \MeetingTranscriptSegment.meeting)
    var segments: [MeetingTranscriptSegment] = []

    init(
        id: UUID = UUID(),
        title: String = "New Meeting",
        date: Date = Date(),
        durationSeconds: Double = 0,
        notesMarkdown: String = "",
        aiSummaryMarkdown: String? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.durationSeconds = durationSeconds
        self.notesMarkdown = notesMarkdown
        self.aiSummaryMarkdown = aiSummaryMarkdown
    }
}

@Model
final class MeetingTranscriptSegment {
    var text: String
    var speakerRaw: String // "me" | "others"
    var timestamp: Date
    var meeting: Meeting?

    init(text: String, speaker: TranscriptSegment.Speaker, timestamp: Date = Date(), meeting: Meeting? = nil) {
        self.text = text
        self.speakerRaw = speaker.rawValue
        self.timestamp = timestamp
        self.meeting = meeting
    }

    var speaker: TranscriptSegment.Speaker {
        get { TranscriptSegment.Speaker(rawValue: speakerRaw) ?? .me }
        set { speakerRaw = newValue.rawValue }
    }
}
