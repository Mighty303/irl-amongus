import SwiftUI

/// Routes server phases, with the physical-map POC following the role presentation.
struct GameRootView: View {
    var lobbyContent: ((GameState) -> AnyView)? = nil
    @Environment(GameStore.self) private var store

    var body: some View {
        @Bindable var store = store
        ZStack(alignment: .top) {
            Group {
                if store.session == nil {
                    HomeView()
                } else if let state = store.state {
                    screen(for: state)
                        .allowsHitTesting(store.isSynced)
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Connecting to \(store.serverURLString)…")
                    }
                }
            }

            if store.session != nil && !store.isSynced && store.state != nil {
                Text("Reconnecting… actions paused until the game state syncs")
                    .font(.footnote.bold())
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.black)
                    .background(.yellow)
            }

            if let alert = store.alert {
                AlertOverlay(alert: alert) { store.alert = nil }
            }
        }
        .onChange(of: store.state?.phase, initial: true) { _, phase in
            if phase == .LOBBY || phase == .ROLE_REVEAL || phase == nil {
                OrientationDelegate.requestLandscape()
            } else {
                OrientationDelegate.requestPortrait()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if store.session != nil && store.state?.phase != .ROLE_REVEAL && (!store.isSynced || (lobbyContent != nil && store.state?.phase != .LOBBY)) {
                Button("Leave Game", role: .destructive) { store.leave() }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
        .alert("Error", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func screen(for state: GameState) -> some View {
        switch state.phase {
        case .LOBBY:
            if let lobbyContent { lobbyContent(state) } else { AnyView(LobbyView(state: state)) }
        case .ROLE_REVEAL: RoleRevealView(state: state)
        case .PLAYING: state.me.isBody ? AnyView(BodyView(state: state)) : AnyView(PhysicalMapView(showsCloseButton: false, gameState: state))
        case .MEETING, .VOTING, .RESULT: MeetingView(state: state)
        case .GAME_OVER: GameOverView(state: state)
        }
    }
}

/// Full-screen, impossible-to-miss event (body reported, sabotage…). Tap to dismiss.
struct AlertOverlay: View {
    let alert: GameStore.Alert
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(alert.title).font(.system(size: 40, weight: .black)).multilineTextAlignment(.center)
            if let subtitle = alert.subtitle { Text(subtitle).font(.title3).multilineTextAlignment(.center) }
            Text("Tap to dismiss").font(.caption).opacity(0.7)
        }
        .foregroundStyle(.white)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(alert.color)
        .ignoresSafeArea()
        .onTapGesture(perform: dismiss)
        .task(id: alert.id) {
            try? await Task.sleep(for: .seconds(5))
            dismiss()
        }
    }
}

/// Countdown to a server timestamp, corrected for clock skew.
struct Countdown: View {
    @Environment(GameStore.self) private var store
    let deadline: Double?
    var font: Font = .system(size: 48, weight: .bold, design: .monospaced)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            if let s = store.secondsUntil(deadline) {
                Text(String(format: "%02d:%02d", s / 60, s % 60)).font(font)
            }
        }
    }
}
