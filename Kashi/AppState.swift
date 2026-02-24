import SwiftUI

/// Shared app state for menu-driven UI (e.g. Help window).
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var showHelp = false

    private init() {}
}
