import SwiftUI

/// GPS, QR scanning/generation, haptics, the task mini-games and the body screen, all testable offline.
struct ToolsLabView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Location") {
                    NavigationLink("GPS & geofence") { LocationLabView() }
                }
                Section("Camera") {
                    NavigationLink("QR scanner") { QRLabView() }
                    NavigationLink("QR generator") { QRGeneratorLabView() }
                }
                Section("Feedback") {
                    NavigationLink("Haptics") { HapticsLabView() }
                    NavigationLink("Kill animation & colours") { KillAnimationPreview() }
                    NavigationLink("Meeting banners (body, emergency)") { BodyReportPreview() }
                    NavigationLink("Ejection animation") { EjectionPreview() }
                    NavigationLink("Body screen preview") { BodyPreview() }
                }
                Section("Task mini-games") {
                    NavigationLink("Fix Wiring") { MiniGameHost { WiringGame(onDone: $0) } }
                    NavigationLink("Start Reactor (sequence)") { MiniGameHost { SequenceGame(onDone: $0) } }
                    NavigationLink("Upload Data (8s, cancels if app leaves foreground)") {
                        MiniGameHost { UploadGame(seconds: 8, start: { true }, onDone: $0) }
                    }
                    NavigationLink("Swipe Card") { MiniGameHost { SwipeCardGame(onDone: $0) } }
                    NavigationLink("Prime Shields") { MiniGameHost { ShieldsGame(onDone: $0) } }
                    NavigationLink("Clean O2 Filter") { MiniGameHost { O2Game(onDone: $0) } }
                    NavigationLink("Submit Scan (10s, stand still)") {
                        MiniGameHost { ScanGame(seconds: 10, playerName: "Red", start: { true }, onDone: $0) }
                    }
                    NavigationLink("Divert Power") { MiniGameHost { DivertPowerGame(onDone: $0) } }
                    NavigationLink("Accept Diverted Power") { MiniGameHost { AcceptPowerGame(onDone: $0) } }
                }
                Section {
                    NavigationLink("Reactor meltdown (hand scanner)") { MiniGameHost { ReactorPreviewGame(onDone: $0) } }
                    NavigationLink("Oxygen keypad") { MiniGameHost { OxygenPreviewGame(onDone: $0) } }
                    NavigationLink("Admin map") { AdminMapPreview() }
                } header: {
                    Text("Sabotage & admin")
                } footer: {
                    Text("Offline: the reactor's second scanner is a button, the keypad checks its own code, and the admin map shows made-up crowds on a real floor plan.")
                }
            }
            .navigationTitle("Tools")
        }
    }
}

private struct QRLabView: View {
    @State private var scans: [(String, Date)] = []

    var body: some View {
        VStack(spacing: 0) {
            CameraView(onQRCode: { payload in
                scans.insert((payload, Date()), at: 0)
                Haptics.success()
            })
            .frame(height: 360)
            List {
                if scans.isEmpty { Text("Point at any QR code").foregroundStyle(.secondary) }
                ForEach(Array(scans.enumerated()), id: \.offset) { _, scan in
                    VStack(alignment: .leading) {
                        Text(scan.0).font(.callout.monospaced())
                        Text("\(describe(scan.0)) · \(scan.1.formatted(date: .omitted, time: .standard))").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("QR scanner")
    }

    private func describe(_ payload: String) -> String {
        switch QRPayload(payload) {
        case let .join(code, server)?: return "Lobby join: \(code)\(server.map { " @ \($0)" } ?? "")"
        case let .station(id)?: return "Station check-in: \(id)"
        case let .player(token)?: return "Player QR: \(token)"
        case nil: return "Not a game QR"
        }
    }
}

private struct QRGeneratorLabView: View {
    @State private var text = "irlau://station/test"

    var body: some View {
        Form {
            TextField("Payload", text: $text).font(.body.monospaced()).autocorrectionDisabled().textInputAutocapitalization(.never)
            HStack { Spacer(); QRCodeImage(payload: text, size: 260); Spacer() }
            Text("Scan this from a second phone's QR scanner to test the camera at different distances and angles.").font(.caption)
        }
        .navigationTitle("QR generator")
    }
}

private struct HapticsLabView: View {
    var body: some View {
        List {
            Button("Tap (light)") { Haptics.tap() }
            Button("Heavy") { Haptics.heavy() }
            Button("Success") { Haptics.success() }
            Button("Error") { Haptics.error() }
            Button("Kill in range (subtle)") { Haptics.killInRange() }
            Button("Alarm: body reported / meeting") { Haptics.alarm() }
        }
        .navigationTitle("Haptics")
    }
}

private struct BodyPreview: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("💀").font(.system(size: 120))
            Text("BODY").font(.system(size: 80, weight: .black))
            Text("Put the phone down across the room. Is it obvious from a distance?").multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.red)
        .toolbarBackground(.red, for: .navigationBar)
    }
}

/// Runs a mini-game in the task panel, like a real task, and starts it over after each completion.
/// The reactor scanner on its own: "Second user" stands in for the person holding the other scanner. Holding
/// your hand on it while they're holding fixes it after a second, as the server would.
private struct ReactorPreviewGame: View {
    let onDone: () -> Void
    @State private var holding = false
    @State private var secondUser = false

    var body: some View {
        ReactorHandGame(otherHeld: secondUser, onHold: { holding = $0 })
            .overlay(alignment: .bottomTrailing) {
                Button(secondUser ? "Second user: holding" : "Second user: not holding") { secondUser.toggle() }
                    .buttonStyle(.borderedProminent).tint(secondUser ? .green : .gray)
                    .padding(8)
                    .accessibilityIdentifier("reactor.preview.secondUser")
            }
            .task(id: holding && secondUser) {
                guard holding && secondUser else { return }
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled { onDone() }
            }
    }
}

/// The O2 keypad on its own, checking its own random code.
private struct OxygenPreviewGame: View {
    let onDone: () -> Void
    @State private var code = String(format: "%05d", Int.random(in: 0..<100_000))
    @State private var wrong = 0

    var body: some View {
        OxygenKeypadGame(code: code, done: false, wrongAttempts: wrong) { typed in
            if typed == code { onDone() } else { wrong += 1 }
        }
    }
}

/// The admin map with made-up crowds, on the ASB 9000 Level plan (or the SUB until the campus downloads).
private struct AdminMapPreview: View {
    @Environment(GameStore.self) private var store
    @State private var counts: [String: Int] = [:]

    private var floor: CampusFloor? {
        let building = store.campus.building("ASB") ?? store.campus.building("SUB")
        return building.map { $0.floor("09") ?? $0.mainFloor }
    }

    var body: some View {
        VStack(spacing: 10) {
            if let floor {
                AdminFloorPlan(rooms: floor.rooms, counts: counts)
                Button("Shuffle people") { shuffle(floor) }.buttonStyle(.borderedProminent)
            } else {
                Text("No floor plans yet.")
            }
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Admin map")
        .onAppear { if let floor, counts.isEmpty { shuffle(floor) } }
    }

    private func shuffle(_ floor: CampusFloor) {
        let rooms = floor.rooms.filter { $0.priority > 5 }.shuffled().prefix(6)
        counts = Dictionary(uniqueKeysWithValues: rooms.map { ($0.id, Int.random(in: 1...5)) })
    }
}

private struct MiniGameHost<Game: View>: View {
    @Environment(\.dismiss) private var dismiss
    let make: (@escaping () -> Void) -> Game
    @State private var done = false
    @State private var round = 0

    init(@ViewBuilder _ make: @escaping (@escaping () -> Void) -> Game) {
        self.make = make
    }

    var body: some View {
        TaskPanel(completed: done, close: { TaskSound.panelClose.play(); dismiss() }) {
            make { complete() }.id(round)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func complete() {
        done = true
        TaskSound.complete.play()
        Haptics.success()
        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            done = false
            round += 1
        }
    }
}
