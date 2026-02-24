import SwiftUI
import SwiftData

struct MeetingActionItemsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var meeting: Meeting

    @Query(sort: \Person.displayName)
    private var people: [Person]

    @State private var newTitle: String = ""
    @State private var newDueDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            list
            Divider()
            newItemRow
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack {
            Text("Action Items")
                .font(.title3)
                .bold()
            Spacer()
            Text("\(openCount) open")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var list: some View {
        if meeting.actionItems.isEmpty {
            Text("No action items yet. Add one below or generate them from the summary.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            List {
                ForEach(meeting.actionItems.sorted(by: { $0.createdAt < $1.createdAt })) { item in
                    ActionItemRowView(
                        item: item,
                        allPeople: people,
                        onDelete: { delete(item) }
                    )
                }
                .onDelete(perform: delete(at:))
            }
            .listStyle(.inset)
        }
    }

    private var newItemRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New action item")
                .font(.headline)
            HStack(spacing: 8) {
                TextField("What needs to be done?", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                DatePicker(
                    "Due",
                    selection: Binding(
                        get: { newDueDate ?? Date() },
                        set: { newDueDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                Button {
                    addNewItem()
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var openCount: Int {
        meeting.actionItems.filter { $0.status == .open || $0.status == .inProgress }.count
    }

    private func addNewItem() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let item = ActionItem(
            title: title,
            dueDate: newDueDate,
            meeting: meeting
        )
        meeting.actionItems.append(item)
        modelContext.insert(item)
        newTitle = ""
        newDueDate = nil
    }

    private func delete(_ item: ActionItem) {
        if let index = meeting.actionItems.firstIndex(where: { $0.id == item.id }) {
            meeting.actionItems.remove(at: index)
        }
        modelContext.delete(item)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let sorted = meeting.actionItems.sorted(by: { $0.createdAt < $1.createdAt })
            guard index < sorted.count else { continue }
            delete(sorted[index])
        }
    }
}

private struct ActionItemRowView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var item: ActionItem
    let allPeople: [Person]
    let onDelete: () -> Void

    @State private var assigneeName: String = ""
    @StateObject private var contactsService = ContactsService()
    @State private var isMatchingContact = false
    @StateObject private var remindersService = RemindersService()
    @State private var isSyncingReminder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { item.status == .done },
                    set: { isDone in
                        item.status = isDone ? .done : .open
                        item.completedAt = isDone ? Date() : nil
                    }
                ))
                .toggleStyle(.checkbox)

                TextField("Title", text: Binding(
                    get: { item.title },
                    set: { item.title = $0 }
                ))
                .textFieldStyle(.plain)

                Spacer()

                Picker("Status", selection: Binding(
                    get: { item.status },
                    set: { item.status = $0 }
                )) {
                    ForEach(ActionItemStatus.allCases, id: \.self) { status in
                        Text(label(for: status)).tag(status)
                    }
                }
                .pickerStyle(.menu)

                if let dueDate = item.dueDate {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { dueDate },
                            set: { item.dueDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                } else {
                    Button("Set due date") {
                        item.dueDate = Date()
                    }
                    .buttonStyle(.borderless)
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 8) {
                Text("Assignee:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Name", text: Binding(
                    get: {
                        assigneeName.isEmpty ? (item.assignee?.displayName ?? "") : assigneeName
                    },
                    set: { assigneeName = $0 }
                ))
                .onSubmit {
                    assignPerson(named: assigneeName)
                }
                .textFieldStyle(.roundedBorder)

                if item.assignee?.contactIdentifier == nil {
                    Button {
                        Task {
                            await matchAssigneeToContact()
                        }
                    } label: {
                        if isMatchingContact {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Match contact…")
                        }
                    }
                    .buttonStyle(.borderless)
                }

                if let assignee = item.assignee, let role = assignee.role, !role.isEmpty {
                    Text("· \(role)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 24)

            if let details = item.details, !details.isEmpty {
                TextEditor(text: Binding(
                    get: { details },
                    set: { item.details = $0 }
                ))
                .font(.caption)
                .frame(minHeight: 40, maxHeight: 80)
            } else {
                Button("Add details") {
                    item.details = ""
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .padding(.leading, 24)
            }

            HStack(spacing: 8) {
                if item.reminderIdentifier != nil {
                    Text("Synced to Reminders")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Button {
                    Task { await syncToReminders() }
                } label: {
                    if isSyncingReminder {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(item.reminderIdentifier == nil ? "Sync to Reminders" : "Update Reminders")
                    }
                }
                .buttonStyle(.borderless)
            }
            .padding(.leading, 24)
        }
        .padding(.vertical, 4)
    }

    private func assignPerson(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let existing = allPeople.first(where: { $0.displayName.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            item.assignee = existing
        } else {
            let person = Person(displayName: trimmed)
            modelContext.insert(person)
            item.assignee = person
        }
        assigneeName = ""
    }

    private func matchAssigneeToContact() async {
        guard let person = item.assignee else { return }
        isMatchingContact = true
        defer { isMatchingContact = false }
        if let contact = await contactsService.matchContact(for: person) {
            person.contactIdentifier = contact.identifier
            if person.email == nil || person.email?.isEmpty == true {
                person.email = contact.emailAddresses.first?.value as String?
            }
            if person.phone == nil || person.phone?.isEmpty == true {
                person.phone = contact.phoneNumbers.first?.value.stringValue
            }
        }
    }

    private func syncToReminders() async {
        isSyncingReminder = true
        defer { isSyncingReminder = false }
        await remindersService.upsertReminder(for: item)
    }

    private func label(for status: ActionItemStatus) -> String {
        switch status {
        case .open: return "Open"
        case .inProgress: return "In progress"
        case .done: return "Done"
        case .cancelled: return "Cancelled"
        }
    }
}

