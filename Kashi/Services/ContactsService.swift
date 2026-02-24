import Foundation
import Contacts

/// Best-effort helper for matching a Person to a CNContact.
@MainActor
final class ContactsService: ObservableObject {
    @Published private(set) var authorizationStatus: CNAuthorizationStatus =
        CNContactStore.authorizationStatus(for: .contacts)

    @Published private(set) var lastErrorMessage: String?

    private let store = CNContactStore()

    func requestAccessIfNeeded() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        authorizationStatus = status

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            do {
                let granted = try await withCheckedThrowingContinuation { continuation in
                    self.store.requestAccess(for: .contacts) { granted, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                self.lastErrorMessage = error.localizedDescription
                            }
                            self.authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
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

    /// Try to find a best-effort CNContact match for a Person by email or name.
    func matchContact(for person: Person) async -> CNContact? {
        guard await requestAccessIfNeeded() else { return nil }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactMiddleNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]

        do {
            if let email = person.email, !email.isEmpty {
                let predicate = CNContact.predicateForContacts(matchingEmailAddress: email)
                let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
                if let first = contacts.first {
                    return first
                }
            }

            // Fallback to name-based lookup if we have something that looks like a name.
            let components = person.displayName.split(separator: " ")
            if let first = components.first {
                let predicate = CNContact.predicateForContacts(matchingName: String(first))
                let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
                // Prefer exact displayName match when possible.
                if let exact = contacts.first(where: { contact in
                    contact.fullName.caseInsensitiveCompare(person.displayName) == .orderedSame
                }) {
                    return exact
                }
                return contacts.first
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
        return nil
    }
}

private extension CNContact {
    var fullName: String {
        [givenName, middleName, familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

