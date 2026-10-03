import SwiftUI

/// POC screens opened from the shake-to-open Developer Mode menu (Debug builds).
enum POCDestination: String, CaseIterable, Identifiable {
    case onlineGame, signsLab, bluetoothLab, tools

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onlineGame: return "Online game (server POC)"
        case .signsLab: return "Sign recognition test"
        case .bluetoothLab: return "Bluetooth proximity test"
        case .tools: return "GPS, QR, haptics & mini-games"
        }
    }

    var systemImage: String {
        switch self {
        case .onlineGame: return "gamecontroller.fill"
        case .signsLab: return "camera.viewfinder"
        case .bluetoothLab: return "dot.radiowaves.left.and.right"
        case .tools: return "wrench.and.screwdriver"
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
        case .signsLab: SignsLabView()
        case .bluetoothLab: BluetoothLabView()
        case .tools: ToolsLabView()
        }
    }
}
