import Foundation
import SwiftData

struct ExportBundle: Codable {
    struct ExportMeeting: Codable {
        var id: UUID
        var title: String
        var date: Date
        var durationSeconds: Double
        var notesMarkdown: String
        var aiSummaryMarkdown: String?
    }

    struct ExportPerson: Codable {
        var id: UUID
        var displayName: String
        var role: String?
        var contactIdentifier: String?
        var email: String?
        var phone: String?
    }

    struct ExportTeam: Codable {
        var id: UUID
        var name: String
        var notes: String?
        var memberIds: [UUID]
    }

    struct ExportActionItem: Codable {
        var id: UUID
        var title: String
        var details: String?
        var status: String
        var dueDate: Date?
        var createdAt: Date
        var completedAt: Date?
        var reminderIdentifier: String?
        var assigneeId: UUID?
        var meetingId: UUID?
    }

    var meetings: [ExportMeeting]
    var people: [ExportPerson]
    var teams: [ExportTeam]
    var actionItems: [ExportActionItem]
}

/// Simple JSON-based import/export for Kashi data.
enum ImportExportService {
    static func exportAll(modelContext: ModelContext) throws -> Data {
        let descriptor = FetchDescriptor<Meeting>()
        let meetings = try modelContext.fetch(descriptor)

        let people = try modelContext.fetch(FetchDescriptor<Person>())
        let teams = try modelContext.fetch(FetchDescriptor<Team>())
        let items = try modelContext.fetch(FetchDescriptor<ActionItem>())

        let exportMeetings = meetings.map {
            ExportBundle.ExportMeeting(
                id: $0.id,
                title: $0.title,
                date: $0.date,
                durationSeconds: $0.durationSeconds,
                notesMarkdown: $0.notesMarkdown,
                aiSummaryMarkdown: $0.aiSummaryMarkdown
            )
        }

        let exportPeople = people.map {
            ExportBundle.ExportPerson(
                id: $0.id,
                displayName: $0.displayName,
                role: $0.role,
                contactIdentifier: $0.contactIdentifier,
                email: $0.email,
                phone: $0.phone
            )
        }

        let exportTeams = teams.map { team in
            ExportBundle.ExportTeam(
                id: team.id,
                name: team.name,
                notes: team.notes,
                memberIds: team.members.map(\.id)
            )
        }

        let exportItems = items.map { item in
            ExportBundle.ExportActionItem(
                id: item.id,
                title: item.title,
                details: item.details,
                status: item.status.rawValue,
                dueDate: item.dueDate,
                createdAt: item.createdAt,
                completedAt: item.completedAt,
                reminderIdentifier: item.reminderIdentifier,
                assigneeId: item.assignee?.id,
                meetingId: item.meeting?.id
            )
        }

        let bundle = ExportBundle(
            meetings: exportMeetings,
            people: exportPeople,
            teams: exportTeams,
            actionItems: exportItems
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(bundle)
    }

    static func importFrom(data: Data, into modelContext: ModelContext) throws {
        let decoder = JSONDecoder()
        let bundle = try decoder.decode(ExportBundle.self, from: data)

        // Index existing entities by id to avoid duplicates.
        let existingMeetings = try modelContext.fetch(FetchDescriptor<Meeting>())
        var meetingById = Dictionary(uniqueKeysWithValues: existingMeetings.map { ($0.id, $0) })

        let existingPeople = try modelContext.fetch(FetchDescriptor<Person>())
        var personById = Dictionary(uniqueKeysWithValues: existingPeople.map { ($0.id, $0) })

        let existingTeams = try modelContext.fetch(FetchDescriptor<Team>())
        var teamById = Dictionary(uniqueKeysWithValues: existingTeams.map { ($0.id, $0) })

        let existingItems = try modelContext.fetch(FetchDescriptor<ActionItem>())
        var itemById = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.id, $0) })

        // Meetings
        for m in bundle.meetings {
            let meeting = meetingById[m.id] ?? Meeting(
                id: m.id,
                title: m.title,
                date: m.date,
                durationSeconds: m.durationSeconds,
                notesMarkdown: m.notesMarkdown,
                aiSummaryMarkdown: m.aiSummaryMarkdown
            )
            meeting.title = m.title
            meeting.date = m.date
            meeting.durationSeconds = m.durationSeconds
            meeting.notesMarkdown = m.notesMarkdown
            meeting.aiSummaryMarkdown = m.aiSummaryMarkdown
            if meetingById[m.id] == nil {
                modelContext.insert(meeting)
                meetingById[m.id] = meeting
            }
        }

        // People
        for p in bundle.people {
            let person = personById[p.id] ?? Person(
                id: p.id,
                displayName: p.displayName,
                role: p.role,
                contactIdentifier: p.contactIdentifier,
                email: p.email,
                phone: p.phone
            )
            person.displayName = p.displayName
            person.role = p.role
            person.contactIdentifier = p.contactIdentifier
            person.email = p.email
            person.phone = p.phone
            if personById[p.id] == nil {
                modelContext.insert(person)
                personById[p.id] = person
            }
        }

        // Teams
        for t in bundle.teams {
            let team = teamById[t.id] ?? Team(id: t.id, name: t.name, notes: t.notes)
            team.name = t.name
            team.notes = t.notes
            team.members = t.memberIds.compactMap { personById[$0] }
            if teamById[t.id] == nil {
                modelContext.insert(team)
                teamById[t.id] = team
            }
        }

        // Action items
        for a in bundle.actionItems {
            let status = ActionItemStatus(rawValue: a.status) ?? .open
            let item = itemById[a.id] ?? ActionItem(
                id: a.id,
                title: a.title,
                details: a.details,
                status: status,
                dueDate: a.dueDate,
                createdAt: a.createdAt,
                completedAt: a.completedAt,
                reminderIdentifier: a.reminderIdentifier
            )
            item.title = a.title
            item.details = a.details
            item.status = status
            item.dueDate = a.dueDate
            item.createdAt = a.createdAt
            item.completedAt = a.completedAt
            item.reminderIdentifier = a.reminderIdentifier
            item.assignee = a.assigneeId.flatMap { personById[$0] }
            item.meeting = a.meetingId.flatMap { meetingById[$0] }
            if itemById[a.id] == nil {
                modelContext.insert(item)
                itemById[a.id] = item
            }
        }

        try modelContext.save()
    }
}

