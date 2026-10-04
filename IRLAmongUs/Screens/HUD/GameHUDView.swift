import SwiftUI

/// The in-game screen (landscape): the SUB floor plan on the left, and on the right one square that
/// shows the actions (tasks, SCAN, REPORT, KILL, SABOTAGE), a task's details, or the task itself.
/// Tasks are square Among Us panels, so they take over the right square while the map stays visible.
struct GameHUDView: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    enum Panel: Equatable {
        case actions
        case detail(taskId: String)
        case task(taskId: String)
    }

    @State private var panel: Panel = .actions
    @State private var scanning = false
    @State private var showingCams = false
    @State private var spectating = false
    /// The sign a tapped task needs; nil when scanning from the big button (any sign).
    @State private var scanTarget: Station?
    @State private var confirmingEmergency = false
    @State private var showingDiagnostics = false
    @State private var showingMyQR = false
    @State private var scanningPlayer = false

    var body: some View {
        GeometryReader { geometry in
            // Two equal squares side by side, as large as the screen allows.
            let side = max(240, min(geometry.size.height - 16, (geometry.size.width - 48) / 2))
            HStack(spacing: 16) {
                HUDMapSquare(state: state, selectTask: { panel = .detail(taskId: $0) }, spectate: { spectating = true })
                    .frame(width: side, height: side)
                rightSquare
                    .frame(width: side, height: side)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.black.ignoresSafeArea())
        .overlay(alignment: .top) {
            if let sabotage = state.sabotage { HUDSabotageBanner(state: state, sabotage: sabotage) }
        }
        .onAppear { store.location.start() }
        .onChange(of: state.me.lastCheckpoint) { old, new in
            guard let new, new != old else { return }
            handleCheckIn(new)
        }
        .onChange(of: state.me.tasks) { _, tasks in
            // A task finished or vanished (e.g. restart): go back to the actions.
            if case let .detail(id) = panel, tasks.first(where: { $0.id == id })?.completed != false { panel = .actions }
        }
        .overlay {
            if scanning {
                SignScanPanel(state: state, target: scanTarget) { scanning = false }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: scanning)
        .overlay {
            if showingCams {
                SecurityCamsView(state: state) { showingCams = false }
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingCams)
        .overlay {
            if spectating {
                SpectateView(state: state) { spectating = false }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: spectating)
        .onChange(of: state.me.alive) { _, alive in if alive { spectating = false } }
        .onChange(of: state.me.canWatchCams) { _, can in
            // Walked away from Security long enough for the check-in to lapse.
            if can != true { showingCams = false }
        }
        .confirmationDialog("Call an emergency meeting?", isPresented: $confirmingEmergency, titleVisibility: .visible) {
            Button("Call meeting (\(state.me.emergencyLeft) left)", role: .destructive) {
                Task { await store.perform("call_emergency") }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingDiagnostics) {
            NavigationStack { DebugView().toolbar { Button("Done") { showingDiagnostics = false } } }
        }
        .sheet(isPresented: $showingMyQR) {
            VStack(spacing: 16) {
                Text(state.me.name).font(.title.bold())
                QRCodeImage(payload: QRPayload.player(qrToken: state.me.qrToken).string, size: 220)
                Text("Fallback when Bluetooth is unreliable").font(.caption)
                Button("Done") { showingMyQR = false }
            }
            .padding()
        }
        .sheet(isPresented: $scanningPlayer) {
            QRScanSheet(title: "Scan player QR") { payload in
                guard case let .player(token)? = QRPayload(payload) else { return }
                scanningPlayer = false
                Task { await store.handlePlayerQR(token) }
            }
        }
    }

    @ViewBuilder private var rightSquare: some View {
        switch panel {
        case .actions:
            actions
        case let .detail(id):
            if let task = state.me.tasks.first(where: { $0.id == id }) {
                HUDTaskDetail(state: state, task: task,
                              close: { panel = .actions },
                              scan: { scanTarget = state.station(task.currentStationId); scanning = true },
                              start: { panel = .task(taskId: id) })
            } else {
                actions
            }
        case let .task(id):
            if let task = state.me.tasks.first(where: { $0.id == id }) {
                HUDTaskSquare(state: state, task: task) { panel = .actions }
            } else {
                actions
            }
        }
    }

    private var actions: some View {
        HUDActionsPanel(state: state,
                        selectTask: { panel = .detail(taskId: $0) },
                        scan: { scanTarget = nil; scanning = true },
                        showDiagnostics: { showingDiagnostics = true },
                        showMyQR: { showingMyQR = true },
                        scanPlayer: { scanningPlayer = true })
    }

    /// After a successful sign scan: fix a sabotage there, offer the emergency button, or open the task.
    private func handleCheckIn(_ checkpoint: Checkpoint) {
        guard let station = state.station(checkpoint.stationId) else { return }
        if let sabotage = state.sabotage, state.me.alive,
           sabotage.stations.contains(where: { $0.stationId == station.id }) {
            Task { await store.perform("fix_sabotage", ["stationId": station.id]) }
        }
        if station.kind == .security, state.me.alive {
            // Sat down at Security: open the cameras.
            showingCams = true
            return
        }
        if station.kind == .emergency, state.me.alive, state.me.emergencyLeft > 0, state.sabotage == nil {
            confirmingEmergency = true
            return
        }
        if let task = state.me.tasks.first(where: { !$0.completed && $0.currentStationId == station.id }) {
            panel = .task(taskId: task.id)
        }
    }
}

// MARK: - Shared pieces

enum HUDStyle {
    static let panelFill = Color(red: 0.05, green: 0.063, blue: 0.078)
    static let here = Color(red: 0.96, green: 0.78, blue: 0.30)
    static let inProgress = Color(red: 0.96, green: 0.89, blue: 0.48)
    static let done = Color(red: 0.44, green: 0.84, blue: 0.51)
    static let danger = Color(red: 1.0, green: 0.42, blue: 0.42)

    static func panel() -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(panelFill)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.35), lineWidth: 2))
    }

    /// Task names as the list and detail show them, including which half of a two-step task is next.
    static func title(_ task: GameTask) -> String {
        switch task.type {
        case .delivery: return task.step == 0 ? "Delivery: pick up" : "Delivery: drop off"
        case .divert: return task.step == 0 ? "Divert Power (1/2)" : "Accept Power (2/2)"
        default: return task.type.label
        }
    }

    static func distance(_ meters: Double) -> String {
        meters < 1000 ? "\(Int(meters.rounded())) m" : String(format: "%.1f km", meters / 1000)
    }
}

extension GameState {
    /// Whether this player has a fresh check-in at a station (what the server requires to do its task).
    func isCheckedIn(at stationId: String?, now: Double) -> Bool {
        if settings.devSkipCheckpoint { return true }
        guard let cp = me.lastCheckpoint, cp.stationId == stationId else { return false }
        return now - cp.at < Double(settings.checkpointTtlSec) * 1000
    }
}

/// The station's reference photo, or a placeholder when it has none.
struct HUDSignPhoto: View {
    @Environment(GameStore.self) private var store
    let station: Station?
    var cornerRadius: CGFloat = 8

    var body: some View {
        // The frame comes from the caller; the image fills it and is cropped, never resizing the view.
        Color(white: 0.23)
            .overlay {
                if let photoId = station?.photoId, let base = store.serverURL {
                    AsyncImage(url: base.appendingPathComponent("photos/\(photoId).jpg")) { $0.resizable().scaledToFill() }
                        placeholder: { ProgressView() }
                } else {
                    Image(systemName: "photo").foregroundStyle(.white.opacity(0.45))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(.white.opacity(0.25), lineWidth: 1.5))
    }
}

/// The big white camera button: scanning a sign checks in and opens that sign's task.
struct HUDScanButton: View {
    var label = "SCAN"
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: "camera.fill").font(.system(size: size * 0.3, weight: .bold))
                Text(label).font(.system(size: size * 0.15, weight: .black, design: .rounded)).tracking(1)
            }
            .foregroundStyle(.black)
            .frame(width: size, height: size)
            .background(.white, in: Circle())
            .overlay(Circle().stroke(.black, lineWidth: 4))
            .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 3).padding(-3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scan a sign")
        .accessibilityIdentifier("hud.scan")
    }
}

/// Among Us red X, sitting on a panel's top-left corner.
struct HUDCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("CloseMenuIcon").resizable().scaledToFit().frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .offset(x: -12, y: -12)
        .accessibilityLabel("Close")
        .accessibilityIdentifier("hud.close")
    }
}

// MARK: - Map square

/// Martin's SUB floor plan with this player's task signs on it: orange while due, green once done,
/// and the player marker at the last verified check-in. Signs without GPS (or outside the SUB) have no pin.
struct HUDMapSquare: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let selectTask: (String) -> Void
    /// Ghosts: open everyone's cameras.
    var spectate: () -> Void = {}

    private struct Pin {
        let station: POCStation
        let taskId: String
        let completed: Bool
    }

    var body: some View {
        // The SFU buildings around the signs and players, on the floor picked at setup (the play area).
        let campus = store.campusView(points: state.locatedStationPoints + store.livePositions.map { CGPoint(x: $0.lng, y: $0.lat) },
                                      stations: state.stations, playArea: state.playArea)
        let pins = taskPins(campus)
        let (center, isPlayer) = mapCenter(campus)
        ZStack {
            // Zoomed in to a little over a room across, locked on you.
            FollowFloorMap(
                rooms: campus.rooms,
                // This player's task signs, plus every other sign so the whole venue is on the map.
                stations: pins.map(\.station) + state.otherSignPins(excluding: Set(pins.map(\.station.id)), campus: campus),
                completedStationIDs: Set(pins.filter(\.completed).map(\.station.id)),
                meetingPoint: state.meetingPointPin,
                players: store.liveDots(state: state, campus: campus),
                center: center,
                centerIsPlayer: isPlayer,
                visionM: isPlayer ? visionM : nil,
                myColor: state.player(state.me.id)?.color,
                isGhost: !state.me.alive,
                onSelectStation: { station in
                    if let pin = pins.first(where: { $0.station.id == station.id }) { selectTask(pin.taskId) }
                }
            )
            .overlay(alignment: .topTrailing) {
                VStack(alignment: .trailing, spacing: 6) {
                    if !state.me.alive { SpectateButton(action: spectate) }
                    cameraOnTag
                }
                .padding(10)
            }
            .overlay(alignment: .bottom) {
                if !state.me.alive {
                    Text("YOU ARE DEAD · finish your tasks")
                        .font(.system(size: 11, weight: .black, design: .rounded)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.black.opacity(0.75), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                        .padding(10)
                }
            }
            .overlay(alignment: .top) {
                if lightsOut {
                    Label("LIGHTS OUT", systemImage: "lightbulb.slash.fill")
                        .font(.system(size: 11, weight: .black, design: .rounded)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.black.opacity(0.75), in: Capsule())
                        .padding(10)
                }
            }
        }
    }

    /// Someone is watching the cameras (Security or a ghost spectating), so yours is on.
    @ViewBuilder private var cameraOnTag: some View {
        if store.isStreamingCamera {
            HStack(spacing: 4) {
                Circle().fill(Color.red).frame(width: 7, height: 7)
                Text("CAM ON").font(.system(size: 10, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.black.opacity(0.75), in: Capsule())
            .accessibilityLabel("Your camera is on: someone is watching")
        }
    }

    private var lightsOut: Bool {
        state.sabotage?.kind == "lights" && state.me.role != .impostor && state.me.alive
    }

    /// How far you see on the map, like Among Us: impostors a little further, crewmates almost nothing
    /// while the lights are out, ghosts everything.
    private var visionM: Double? {
        if !state.me.alive { return nil }
        if lightsOut { return 3 }
        return state.me.role == .impostor ? 14 : 10
    }

    private func taskPins(_ campus: CampusView) -> [Pin] {
        var seen = Set<String>()
        // Incomplete tasks first, so a sign shared with a finished task shows as still due.
        let ordered = state.me.tasks.filter { !$0.completed } + state.me.tasks.filter(\.completed)
        return ordered.compactMap { task in
            guard let station = state.station(task.completed ? task.steps.last : task.currentStationId),
                  let lat = station.lat, let lng = station.lng, seen.insert(station.id).inserted else { return nil }
            return Pin(
                station: POCStation(
                    id: station.id,
                    displayName: station.name,
                    taskType: task.type.label,
                    roomID: String(station.name.prefix(10)),
                    roomLabel: station.name,
                    position: CGPoint(x: lng, y: lat),
                    faded: campus.isOffFloor(buildingId: station.buildingId, floorId: station.floorId),
                    floorNote: campus.isOffFloor(buildingId: station.buildingId, floorId: station.floorId) ? station.floorId : nil
                ),
                taskId: task.id,
                completed: task.completed
            )
        }
    }

    /// What the map keeps in the middle: your live position, else your last check-in, else the red
    /// button or the play area's building.
    private func mapCenter(_ campus: CampusView) -> (CGPoint, Bool) {
        if let position = LocalMapTracking.coordinate(local: store.positions.estimate,
                positions: store.livePositions, playerID: state.me.id, serverNow: store.serverNow()) {
            return (position, true)
        }
        if let cp = state.me.lastCheckpoint, let s = state.station(cp.stationId), let lat = s.lat, let lng = s.lng {
            return (CGPoint(x: lng, y: lat), true)
        }
        if let s = state.stations.first(where: { $0.kind == .emergency }), let lat = s.lat, let lng = s.lng {
            return (CGPoint(x: lng, y: lat), false)
        }
        let b = store.campus.building(state.playArea?.buildingId) ?? campus.focus ?? store.campus.building("SUB")
        guard let bounds = b?.bounds else { return (CGPoint(x: -122.91825, y: 49.27855), false) }
        return (CGPoint(x: (bounds.minX + bounds.maxX) / 2, y: (bounds.minY + bounds.maxY) / 2), false)
    }
}

// MARK: - Actions square

struct HUDActionsPanel: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let selectTask: (String) -> Void
    let scan: () -> Void
    let showDiagnostics: () -> Void
    let showMyQR: () -> Void
    let scanPlayer: () -> Void

    private var isImpostor: Bool { state.me.role == .impostor }
    private var pending: [GameTask] { state.me.tasks.filter { !$0.completed } }

    var body: some View {
        GeometryReader { geometry in
            let button = min(84, max(56, geometry.size.height * 0.26))
            VStack(alignment: .leading, spacing: 8) {
                topRow.frame(height: 30)
                taskList.frame(maxHeight: .infinity)
                if isImpostor && state.me.alive { killStatus.frame(height: 14) }
                bottomRow(button: button).frame(height: button)
            }
        }
        .padding(12)
        .background(HUDStyle.panel())
    }

    private var topRow: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.24, green: 0.27, blue: 0.31))
                GeometryReader { bar in
                    Rectangle().fill(Color(red: 0.26, green: 0.77, blue: 0.35))
                        .frame(width: bar.size.width * state.taskProgress.fraction)
                }
                TaskText("TOTAL TASKS COMPLETED", size: 11).frame(maxWidth: .infinity)
            }
            .frame(height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(.black, lineWidth: 3))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(white: 0.55), lineWidth: 1.5).padding(-2))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Total tasks completed")
            .accessibilityValue("\(state.taskProgress.done) of \(state.taskProgress.total)")

            Menu {
                if state.settings.qrFallback {
                    Button("Show my player QR", action: showMyQR)
                    Button("Scan a player QR", action: scanPlayer)
                }
                Button("Diagnostics", action: showDiagnostics)
                Button("Leave game", role: .destructive) { store.leave() }
            } label: {
                Image("SettingsMenuIcon").resizable().scaledToFit().frame(width: 30, height: 30)
            }
            .accessibilityLabel("Settings")
        }
    }

    private var taskList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if isImpostor {
                    Text("Sabotage and kill everyone. Fake tasks:").foregroundStyle(Color(red: 1, green: 0.3, blue: 0.3))
                } else if !state.me.alive {
                    Text("You're a ghost. Keep doing tasks.").foregroundStyle(.white.opacity(0.7))
                } else {
                    Text("YOUR TASKS").tracking(1).foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                let done = state.me.tasks.count - pending.count
                if !isImpostor && done > 0 { Text("\(done) done").foregroundStyle(HUDStyle.done) }
            }
            .font(.system(size: 11, weight: .black, design: .rounded))
            .lineLimit(1)

            if pending.isEmpty {
                Text(state.me.tasks.isEmpty ? "No tasks this game." : "All tasks done ✓")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(HUDStyle.done)
                Spacer(minLength: 0)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(pending) { task in taskRow(task) }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    private func taskRow(_ task: GameTask) -> some View {
        let station = state.station(task.currentStationId)
        let here = state.isCheckedIn(at: task.currentStationId, now: store.serverNow()) && !state.settings.devSkipCheckpoint
        return Button { selectTask(task.id) } label: {
            HStack(spacing: 9) {
                HUDSignPhoto(station: station).frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text(HUDStyle.title(task))
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(task.step > 0 ? HUDStyle.inProgress : .white)
                    Text(station?.name ?? "Unknown sign")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .lineLimit(1)
                Spacer(minLength: 4)
                if here {
                    Text("HERE")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(HUDStyle.here, in: Capsule())
                } else if let station, let meters = store.location.distance(to: station) {
                    Text(HUDStyle.distance(meters))
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows the sign's photo and where it is")
    }

    private var killStatus: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let cooldown = store.secondsUntil(state.me.killCooldownUntil) ?? 0
            let targets = state.me.killTargets.compactMap { state.player($0)?.name }
            Text(cooldown > 0 ? "Kill ready in \(cooldown)s"
                 : targets.isEmpty ? "No one in kill range"
                 : "KILL READY · \(targets.joined(separator: ", ")) in range")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(cooldown == 0 && !targets.isEmpty ? HUDStyle.danger : .white.opacity(0.6))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder private func bottomRow(button: CGFloat) -> some View {
        if isImpostor && state.me.alive {
            HStack(alignment: .bottom, spacing: 8) {
                sabotageButton(size: button * 0.72)
                reportButton(size: button * 0.72)
                Spacer(minLength: 4)
                MapKillButton(state: state, size: button)
                HUDScanButton(size: button, action: scan)
            }
        } else {
            HStack(alignment: .bottom, spacing: 10) {
                Text(state.me.alive
                     ? "Point the camera at a task's sign to check in and start it."
                     : "You're a ghost: you can't report or vote, but your tasks still count. Tap Spectate on the map to watch everyone.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if state.me.alive { reportButton(size: button * 0.86) }
                if state.me.alive || state.settings.ghostTasks { HUDScanButton(size: button, action: scan) }
            }
        }
    }

    private func reportButton(size: CGFloat) -> some View {
        let body = state.me.nearbyBodies.first
        return Button {
            if let body { Task { await store.perform("report_body", ["bodyId": body]) } }
        } label: {
            Image("ReportActionIcon").resizable().scaledToFit()
                .frame(width: size, height: size)
                .opacity(body == nil ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(body == nil)
        .accessibilityLabel(body == nil ? "Report, no body nearby" : "Report body")
        .accessibilityIdentifier("hud.report")
    }

    private func sabotageButton(size: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let cooldown = store.secondsUntil(state.me.sabotageAvailableAt) ?? 0
            let available = cooldown == 0 && state.sabotage == nil
            Menu {
                Button("Reactor meltdown") { Task { await store.perform("sabotage", ["kind": "reactor"]) } }
                Button("Lights") { Task { await store.perform("sabotage", ["kind": "lights"]) } }
            } label: {
                ZStack {
                    Image("SabotageActionIcon").resizable().scaledToFit()
                        .frame(width: size, height: size)
                        .opacity(available ? 1 : 0.35)
                    if cooldown > 0 {
                        TaskText("\(cooldown)", size: size / 3)
                    }
                }
            }
            .disabled(!available)
            .accessibilityLabel(cooldown > 0 ? "Sabotage, ready in \(cooldown) seconds" : "Sabotage")
            .accessibilityIdentifier("hud.sabotage")
        }
    }
}

// MARK: - Task detail square

/// Tapping a task: the sign's photo up close, where it is, and a button to scan it (or start, once there).
struct HUDTaskDetail: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let task: GameTask
    let close: () -> Void
    let scan: () -> Void
    let start: () -> Void

    var body: some View {
        let station = state.station(task.currentStationId)
        let checkedIn = state.isCheckedIn(at: task.currentStationId, now: store.serverNow())
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 10) {
                HUDSignPhoto(station: station, cornerRadius: 12)
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.48)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(HUDStyle.title(task))
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(task.step > 0 ? HUDStyle.inProgress : .white)
                        Spacer(minLength: 4)
                        if task.steps.count > 1 {
                            Text("STEP \(task.step + 1) OF \(task.steps.count)")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(HUDStyle.inProgress, in: Capsule())
                        }
                    }
                    locationRow(station)
                    if let text = station?.signText {
                        Text("Text on the sign: “\(text)”")
                    }
                    if task.step + 1 < task.steps.count, let next = state.station(task.steps[task.step + 1]) {
                        Text("Then: \(next.name)")
                    }
                    Spacer(minLength: 0)
                    Button(action: checkedIn ? start : scan) {
                        Label(checkedIn ? "START TASK" : "SCAN THIS SIGN", systemImage: checkedIn ? "play.fill" : "camera.fill")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(.white, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.black, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hud.detail.action")
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
            }
        }
        .padding(12)
        .background(HUDStyle.panel())
        .overlay(alignment: .topLeading) { HUDCloseButton(action: close) }
    }

    @ViewBuilder private func locationRow(_ station: Station?) -> some View {
        HStack(spacing: 6) {
            if let station, let bearing = store.location.bearing(to: station), let heading = store.location.heading {
                Image(systemName: "location.north.fill")
                    .foregroundStyle(.cyan)
                    .rotationEffect(.degrees(bearing - heading))
            } else {
                Image(systemName: "mappin.and.ellipse").foregroundStyle(.cyan)
            }
            if let station, let meters = store.location.distance(to: station) {
                Text("\(station.name) · \(HUDStyle.distance(meters))")
            } else {
                Text(station.map { "\($0.name) · no GPS, use the photo" } ?? "Unknown sign")
            }
        }
        .foregroundStyle(.white.opacity(0.9))
    }
}

// MARK: - Task square

/// The task's mini-game inside the right square. Completion is sent to the server; a rejection
/// (e.g. walked away mid-upload) restarts the mini-game with the reason shown.
struct HUDTaskSquare: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let task: GameTask
    let close: () -> Void

    @State private var completed = false
    @State private var submitting = false
    @State private var error: String?
    @State private var attempt = 0
    /// The task and sign as they were when the panel opened. Finishing moves the task on (done, or its
    /// next sign) on the server before this panel closes; without these it would flash "scan first".
    @State private var shownTask: GameTask
    @State private var stationId: String?

    init(state: GameState, task: GameTask, close: @escaping () -> Void) {
        self.state = state
        self.task = task
        self.close = close
        _shownTask = State(initialValue: task)
        _stationId = State(initialValue: task.currentStationId)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(Color.black)
            if completed || submitting || state.isCheckedIn(at: stationId, now: store.serverNow()) {
                TaskGame(task: shownTask, state: state, onDone: complete)
                    .id(attempt)
                    .padding(8)
                    .allowsHitTesting(!completed && !submitting)
            } else {
                Text("Scan this task's sign first.")
                    .font(.headline).foregroundStyle(.white)
            }
            if completed { TaskText("Task Completed!", size: 28) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.35), lineWidth: 2))
        .overlay(alignment: .bottom) {
            if let error {
                Text(error)
                    .font(.footnote.bold()).foregroundStyle(.white).multilineTextAlignment(.center)
                    .padding(8).background(.red, in: RoundedRectangle(cornerRadius: 8)).padding(8)
            }
        }
        .overlay(alignment: .topLeading) { HUDCloseButton { TaskSound.panelClose.play(); close() } }
        .onAppear { TaskSound.panelOpen.play() }
    }

    private func complete() {
        Task {
            error = nil
            submitting = true
            defer { submitting = false }
            if await store.perform("task_complete", ["taskId": shownTask.id]) {
                completed = true
                TaskSound.complete.play()
                Haptics.success()
                try? await Task.sleep(for: .milliseconds(1400))
                close()
            } else {
                error = store.errorMessage
                store.errorMessage = nil
                attempt += 1
            }
        }
    }
}

// MARK: - Sabotage banner

struct HUDSabotageBanner: View {
    let state: GameState
    let sabotage: SabotageView

    var body: some View {
        HStack(spacing: 8) {
            Text(sabotage.kind == "reactor" ? "☢️ REACTOR MELTDOWN" : "💡 LIGHTS OUT")
                .font(.system(size: 13, weight: .black, design: .rounded))
            if sabotage.deadline != nil {
                Countdown(deadline: sabotage.deadline, font: .system(size: 13, weight: .black, design: .monospaced))
            }
            Text(fixHint).font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .lineLimit(1)
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(Color(red: 0.75, green: 0.1, blue: 0.1), in: Capsule())
        .padding(.top, 2)
    }

    private var fixHint: String {
        let names = sabotage.stations.map { fix in
            "\(state.station(fix.stationId)?.name ?? "?")\(fix.active ? " ✓" : "")"
        }
        return sabotage.kind == "reactor"
            ? "Scan both reactor signs: \(names.joined(separator: " · "))"
            : "Scan \(names.first ?? "the electrical sign")"
    }
}
