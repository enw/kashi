import Foundation
import EventKit

/// Helper for mapping ActionItem objects to Reminders.
@MainActor
final class RemindersService: ObservableObject {
    @Published private(set) var authorizationStatus: EKAuthorizationStatus =
        EKEventStore.authorizationStatus(for: .reminder)

    @Published private(set) var lastErrorMessage: String?

    private let store = EKEventStore()

    func requestAccessIfNeeded() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        authorizationStatus = status

        switch status {
        case .fullAccess, .authorized:
            return true
        case .notDetermined:
            do {
                let granted = try await withCheckedThrowingContinuation { continuation in
                    store.requestAccess(to: .reminder) { granted, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                self.lastErrorMessage = error.localizedDescription
                            }
                            self.authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
                            continuation.resume(returning: granted)
                        }
                    }
                }
                return granted
            } catch {
                lastErrorMessage = error.localizedDescription
                return false
            }
        default:
            return false
        }
    }

    /// Find (or create) the dedicated "Kashi Tasks" reminders list.
    private func kashiCalendar() throws -> EKCalendar {
        if let existing = store.calendars(for: .reminder).first(where: { $0.title == "Kashi Tasks" }) {
            return existing
        }

        let calendar = EKCalendar(for: .reminder, eventStore: store)
        calendar.title = "Kashi Tasks"
        if let source = store.defaultCalendarForNewReminders()?.source
            ?? store.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = source
        }
        try store.saveCalendar(calendar, commit: true)
        return calendar
    }

    /// Create or update the EKReminder backing an ActionItem.
    func upsertReminder(for item: ActionItem) async {
        guard await requestAccessIfNeeded() else { return }

        do {
            let calendar = try kashiCalendar()
            let reminder: EKReminder
            if let id = item.reminderIdentifier,
               let existing = store.calendarItem(withIdentifier: id) as? EKReminder {
                reminder = existing
            } else {
                reminder = EKReminder(eventStore: store)
                reminder.calendar = calendar
            }

            reminder.title = item.title

            var notes = item.details ?? ""
            if let meeting = item.meeting {
                let meetingLine = "Meeting: \(meeting.title) – \(meeting.date.formatted(date: .abbreviated, time: .shortened))"
                notes = notes.isEmpty ? meetingLine : "\(meetingLine)\n\n\(notes)"
            }
            reminder.notes = notes.isEmpty ? nil : notes

            if let due = item.dueDate {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day],
                    from: due
                )
            } else {
                reminder.dueDateComponents = nil
            }

            reminder.isCompleted = item.status == .done

            try store.save(reminder, commit: true)
            item.reminderIdentifier = reminder.calendarItemIdentifier
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}

