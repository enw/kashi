import SwiftUI
import EventKit

struct UpcomingMeetingsView: View {
    @ObservedObject var calendar: CalendarService

    var body: some View {
        Section("Today") {
            if calendar.upcomingEvents.isEmpty {
                Text("No upcoming events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(calendar.upcomingEvents.prefix(5), id: \.eventIdentifier) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title ?? "Untitled")
                            .font(.subheadline)
                            .lineLimit(1)
                        if let start = event.startDate {
                            Text(start, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
