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
                    screen(for: store.bodyReportBackdrop ?? state)
                        .allowsHitTesting(store.isSynced && store.bodyReportPresentation == nil)
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
        .onChange(of: store.state?.phase, initial: true) { _, _ in
            guard store.killPresentation == nil && store.bodyReportPresentation == nil else { return }
            OrientationDelegate.requestLandscape()
        }
        .onChange(of: store.killPresentation?.id) { _, _ in
            guard store.bodyReportPresentation == nil else { return }
            OrientationDelegate.requestLandscape()
        }
        .onChange(of: store.bodyReportPresentation?.id) { _, id in
            guard id == nil else { return } // The report window chooses and locks the landscape side.
            OrientationDelegate.requestLandscape()
        }
        .safeAreaInset(edge: .bottom) {
            // The in-game HUD has Leave game in its settings menu, so it keeps the full screen height.
            if store.session != nil && store.state?.phase != .ROLE_REVEAL && store.state?.phase != .GAME_OVER
                && store.state?.phase != .RESULT // the ejection screen is full screen
                && (!store.isSynced || (lobbyContent != nil && store.state?.phase != .LOBBY && store.state?.phase != .PLAYING)) {
                Button("Leave Game", role: .destructive) { store.leave() }
                    .allowsHitTesting(store.killPresentation == nil)
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
        // Killed players keep the game screen as a ghost (it says to stay put until the body is found).
        case .PLAYING: GameHUDView(state: state)
        case .MEETING, .VOTING: MeetingView(state: state)
        // The Among Us ejection screen while the vote result shows.
        case .RESULT: EjectionView(state: state)
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
