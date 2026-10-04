import SwiftUI

/// POC screens opened from the shake-to-open Developer Mode menu (Debug builds).
enum POCDestination: String, CaseIterable, Identifiable {
    case onlineGame, demoMode, signsLab, bluetoothLab, tools

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onlineGame: return "Online game"
        case .demoMode: return "Demo mode"
        case .signsLab: return "Sign recognition test"
        case .bluetoothLab: return "Bluetooth proximity test"
        case .tools: return "GPS, QR, haptics & mini-games"
        }
    }

    var systemImage: String {
        switch self {
        case .onlineGame: return "gamecontroller.fill"
        case .demoMode: return "flag.fill"
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
            // The online game sets its own orientation per phase; the test benches are portrait.
            .onAppear { if destination != .onlineGame { OrientationDelegate.requestPortrait() } }
    }

    @ViewBuilder private var content: some View {
        switch destination {
        case .onlineGame: GameRootView()
        case .demoMode: DemoModeView()
        case .signsLab: SignsLabView()
        case .bluetoothLab: BluetoothLabView()
        case .tools: ToolsLabView()
        }
    }
}

/// Shake-menu opt-in for hosts demonstrating a game without photographing signs.
private struct DemoModeView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Toggle("Enable demo controls", isOn: $store.demoModeEnabled)
                    .accessibilityIdentifier("demo.enabled")
            } footer: {
                Text("Adds a Require signs switch to the host's lobby settings. Create or join a game from the main menu, then open Settings → Game.")
            }
            if store.demoModeEnabled {
                Section("Current lobby") {
                    if let state = store.state, state.phase == .LOBBY {
                        DemoSignsControl(state: state)
                    } else {
                        Text("Host a lobby to turn off its sign requirement.")
                    }
                }
            }
            Section {
                Text("Turning off Require signs lets everyone start without adding signs. Existing signs and tasks stay available. Player counts and other game rules still apply.")
                Text("Turning off demo controls hides the switch; it does not change the lobby's sign requirement.")
            }
        }
    }
}

struct DemoSignsControl: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Require signs", isOn: Binding(
                get: { (state.settings.signsPerPlayer ?? 0) > 0 },
                set: { required in Task { await store.setDemoSignsRequired(required) } }
            ))
            .disabled(!state.isHost || !store.isSynced || store.isUpdatingDemoSigns
                      || state.settings.signsPerPlayer == nil)
            .accessibilityIdentifier("demo.requireSigns")
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var detail: String {
        if !state.isHost { return "Only the host can change the sign requirement." }
        if state.settings.signsPerPlayer == nil { return "This server does not support sign requirements." }
        let perPlayer = state.settings.signsPerPlayer ?? 0
        if perPlayer == 0 { return "Demo: no signs required to start. The red button is still needed." }
        return state.gameset == nil ? "Players must add \(perPlayer) signs each."
            : "\(perPlayer) per player, minus the saved game's signs, split between players."
    }
}
