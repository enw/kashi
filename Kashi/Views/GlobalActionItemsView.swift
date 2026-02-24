import SwiftUI
import SwiftData

struct GlobalActionItemsView: View {
    @Query(sort: \ActionItem.createdAt, order: .reverse)
    private var allItems: [ActionItem]

    @Query(sort: \Person.displayName)
    private var people: [Person]

    @Query(sort: \Team.name)
    private var teams: [Team]

    @State private var selectedStatus: StatusFilter = .open
    @State private var selectedPersonId: UUID?
    @State private var selectedTeamId: UUID?

    private enum StatusFilter: String, CaseIterable, Identifiable {
        case all
        case open
        case done

        var id: String { rawValue }
    }

    private var filteredItems: [ActionItem] {
        allItems.filter { item in
            switch selectedStatus {
            case .all:
                true
            case .open:
                item.status == .open || item.status == .inProgress
            case .done:
                item.status == .done
            }
        }
        .filter { item in
            if let id = selectedPersonId {
                return item.assignee?.id == id
            }
            return true
        }
        .filter { item in
            if let teamId = selectedTeamId,
               let team = teams.first(where: { $0.id == teamId }) {
                if let assignee = item.assignee {
                    return team.members.contains(where: { $0.id == assignee.id })
                }
                return false
            }
            return true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            filters
            Divider()
            list
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack {
            Text("All Action Items")
                .font(.title2)
                .bold()
            Spacer()
            Text("\(filteredItems.count) shown")
                .foregroundStyle(.secondary)
        }
    }

    private var filters: some View {
        HStack(spacing: 16) {
            Picker("Status", selection: $selectedStatus) {
                Text("All").tag(StatusFilter.all)
                Text("Open").tag(StatusFilter.open)
                Text("Done").tag(StatusFilter.done)
            }
            .pickerStyle(.segmented)
            .frame(width: 260)

            Picker("Person", selection: $selectedPersonId) {
                Text("Anyone").tag(UUID?.none)
                ForEach(people) { person in
                    Text(person.displayName).tag(Optional(person.id))
                }
            }
            .frame(width: 220)

            Picker("Team", selection: $selectedTeamId) {
                Text("Any team").tag(UUID?.none)
                ForEach(teams) { team in
                    Text(team.name).tag(Optional(team.id))
                }
            }
            .frame(width: 220)
        }
    }

    @ViewBuilder
    private var list: some View {
        if filteredItems.isEmpty {
            Text("No action items match these filters yet.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            List {
                ForEach(filteredItems) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: item.status == .done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.status == .done ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.headline)
                            HStack(spacing: 8) {
                                if let assignee = item.assignee {
                                    Text(assignee.displayName)
                                }
                                if let due = item.dueDate {
                                    Text(due, style: .date)
                                }
                                if let meeting = item.meeting {
                                    Text("· \(meeting.title)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.inset)
        }
    }
}

