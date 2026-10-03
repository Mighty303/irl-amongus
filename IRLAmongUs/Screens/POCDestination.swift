import SwiftUI

/// POC screens opened from the shake-to-open Developer Mode menu (Debug builds).
enum POCDestination: String, CaseIterable, Identifiable {
    case onlineGame

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onlineGame: return "Online game (server POC)"
        }
    }

    var systemImage: String {
        switch self {
        case .onlineGame: return "gamecontroller.fill"
        }
    }
}

/// Full-screen host for a POC screen, with a bar to get back to the main menu.
/// These screens are laid out for portrait; closing returns to the landscape menu.
struct POCDestinationView: View {
    let destination: POCDestination
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Button { dismiss() } label: { Label("Main menu", systemImage: "chevron.left") }
                    Spacer()
                    Text(destination.title).font(.caption).foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .onAppear { OrientationDelegate.requestPortrait() }
    }

    @ViewBuilder private var content: some View {
        switch destination {
        case .onlineGame: GameRootView()
        }
    }
}
