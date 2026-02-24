import Foundation
import EventKit

/// Fetches upcoming calendar events for meeting context.
final class CalendarService: ObservableObject {
    @Published private(set) var upcomingEvents: [EKEvent] = []
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var errorMessage: String?

    private let eventStore = EKEventStore()

    func requestAccess() async -> Bool {
        if #available(macOS 14.0, *) {
            return await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToEvents { [weak self] granted, error in
                    DispatchQueue.main.async {
                        self?.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                        if let error = error {
                            self?.errorMessage = error.localizedDescription
                        }
                        continuation.resume(returning: granted)
                    }
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { [weak self] granted, error in
                    DispatchQueue.main.async {
                        self?.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                        if let error = error {
                            self?.errorMessage = error.localizedDescription
                        }
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    func fetchUpcomingEvents(withinHours: Double = 24) {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess || status == .authorized else {
            DispatchQueue.main.async { [weak self] in
                self?.authorizationStatus = status
                self?.upcomingEvents = []
            }
            return
        }
        let start = Date()
        let end = start.addingTimeInterval(withinHours * 3600)
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)
        let sorted = events.sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = status
            self?.upcomingEvents = sorted
        }
    }
}
