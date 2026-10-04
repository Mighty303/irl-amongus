import SwiftUI

/// POC screens opened from the shake-to-open Developer Mode menu (Debug builds).
enum POCDestination: String, CaseIterable, Identifiable {
    case onlineGame, demoMode, gameOver, signsLab, bluetoothLab, tools

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onlineGame: return "Online game"
        case .demoMode: return "Demo mode"
        case .gameOver: return "Win screen"
        case .signsLab: return "Sign recognition test"
        case .bluetoothLab: return "Bluetooth proximity test"
        case .tools: return "GPS, QR, haptics & mini-games"
        }
    }

    var systemImage: String {
        switch self {
        case .onlineGame: return "gamecontroller.fill"
        case .demoMode: return "flag.fill"
        case .gameOver: return "trophy.fill"
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
            .onAppear {
                if destination == .gameOver { OrientationDelegate.requestLandscape() }
                else if destination != .onlineGame { OrientationDelegate.requestPortrait() }
            }
    }

    @ViewBuilder private var content: some View {
        switch destination {
        case .onlineGame: GameRootView()
        case .demoMode: DemoModeView()
        case .gameOver: GameOverPreview()
        case .signsLab: SignsLabView()
        case .bluetoothLab: BluetoothLabView()
        case .tools: ToolsLabView()
        }
    }
}

/// Shake-menu opt-in for hosts demonstrating a game with simplified setup and win rules.
private struct DemoModeView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Toggle("Enable demo controls", isOn: $store.demoModeEnabled)
                    .accessibilityIdentifier("demo.enabled")
            } footer: {
                Text("Adds sign setup and small-game voting controls to the host's lobby settings. Create or join a game from the main menu, then open Settings → Game.")
            }
            if store.demoModeEnabled {
                Section("Current lobby") {
                    if let state = store.state, state.phase == .LOBBY {
                        DemoSignsControl(state: state)
                    } else {
                        Text("Host a lobby to change its demo rules.")
                    }
                    DemoVotingControl(state: store.state)
                }
            }
            Section {
                Text("Turning off Require signs lets everyone start without adding signs. Existing signs and tasks stay available. Player counts and other game rules still apply.")
                Text("Allow voting after a kill keeps a three-player game running when one crewmate and one impostor remain. Votes still need a clear winner; ties and skips eject no one. Impostors win when no living crewmates remain.")
                Text("Turning off demo controls hides the switches; it does not reset the lobby's demo rules.")
            }
        }
    }
}

struct DemoVotingControl: View {
    @Environment(GameStore.self) private var store
    let state: GameState?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Allow voting after a kill", isOn: Binding(
                get: { state?.settings.demoContinueAtParity ?? false },
                set: { enabled in Task { await store.setDemoContinueAtParity(enabled) } }
            ))
            .disabled(state?.isHost != true || state?.phase != .LOBBY || !store.isSynced
                      || store.isUpdatingDemoVoting || state?.settings.demoContinueAtParity == nil)
            .accessibilityIdentifier("demo.continueAtParity")
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var detail: String {
        guard let state else { return "Host a lobby to enable voting after a kill." }
        if state.phase != .LOBBY { return "Change this rule in the lobby before starting the game." }
        if state.settings.demoContinueAtParity == nil { return "Update the server to enable small-game demo voting." }
        if !state.isHost { return "Only the host can change demo voting." }
        return "Keep playing when impostors match the crew, so survivors can report and vote."
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
