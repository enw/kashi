import Foundation
import SwiftData

enum ActionItemStatus: String, Codable, CaseIterable, Equatable {
    case open
    case inProgress
    case done
    case cancelled
}

enum ActionItemPriority: String, Codable, CaseIterable, Equatable {
    case low
    case medium
    case high
}

@Model
final class Person {
    var id: UUID
    var displayName: String
    var role: String?
    var contactIdentifier: String?
    var email: String?
    var phone: String?

    init(
        id: UUID = UUID(),
        displayName: String,
        role: String? = nil,
        contactIdentifier: String? = nil,
        email: String? = nil,
        phone: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.contactIdentifier = contactIdentifier
        self.email = email
        self.phone = phone
    }
}

@Model
final class Team {
    var id: UUID
    var name: String
    var notes: String?
    var members: [Person] = []

    init(
        id: UUID = UUID(),
        name: String,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.notes = notes
    }
}

@Model
final class ActionItem {
    var id: UUID
    var title: String
    var details: String?
    var statusRaw: String
    var dueDate: Date?
    var createdAt: Date
    var completedAt: Date?
    var reminderIdentifier: String?
    var assignee: Person?
    var meeting: Meeting?

    init(
        id: UUID = UUID(),
        title: String,
        details: String? = nil,
        status: ActionItemStatus = .open,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        reminderIdentifier: String? = nil,
        assignee: Person? = nil,
        meeting: Meeting? = nil
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.statusRaw = status.rawValue
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.reminderIdentifier = reminderIdentifier
        self.assignee = assignee
        self.meeting = meeting
    }

    var status: ActionItemStatus {
        get { ActionItemStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }

    var priority: ActionItemPriority {
        // For now just default to medium; can be expanded later.
        get { .medium }
        set { _ = newValue }
    }
}

