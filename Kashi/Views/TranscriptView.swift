import SwiftUI

struct TranscriptView: View {
    let segments: [TranscriptSegment]
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(segments) { segment in
                        TranscriptBubble(segment: segment)
                            .id(segment.id)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: segments.count) { _, _ in
                if let last = segments.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
    }
}

struct TranscriptBubble: View {
    let segment: TranscriptSegment
    private var isMe: Bool { segment.speaker == .me }

    var body: some View {
        HStack {
            if isMe { Spacer(minLength: 60) }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                Text(segment.text)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isMe ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(formatTime(segment.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !isMe { Spacer(minLength: 60) }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    TranscriptView(segments: [
        TranscriptSegment(text: "Hello, can everyone hear me?", speaker: .me),
        TranscriptSegment(text: "Yes, we can.", speaker: .others),
    ])
    .frame(width: 400, height: 300)
}
