import SwiftUI

extension GameStore {
    /// Map dots while live positions are on: everyone from the server, with this phone's own estimate
    /// (fresher than the server's copy) for YOU. Empty when it's off.
    func liveDots(state: GameState) -> [POCPlayerDot] {
        guard livePositionsOn else { return [] }
        var dots: [POCPlayerDot] = livePositions.compactMap { pos in
            guard pos.playerId != state.me.id, let player = state.player(pos.playerId) else { return nil }
            return POCPlayerDot(id: pos.playerId, name: player.name, color: (player.color ?? .white).swatch,
                                position: CGPoint(x: pos.lng, y: pos.lat), accuracyM: pos.accuracyM,
                                isMe: false, faded: pos.stale)
        }
        if let mine = positions.estimate {
            dots.append(POCPlayerDot(id: state.me.id, name: state.me.name, color: .cyan,
                                     position: CGPoint(x: mine.lng, y: mine.lat), accuracyM: mine.accuracyM,
                                     isMe: true, faded: false))
        }
        return dots
    }
}

/// Testing tool: every player's estimated position on the SUB floor plan, plus this phone's sensors,
/// so you can walk around with friends and see how good the estimates are.
struct LiveMapView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let state = store.state {
                content(state)
            } else {
                Color.black
            }
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func content(_ state: GameState) -> some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            let layout = landscape ? AnyLayout(HStackLayout(spacing: 14)) : AnyLayout(VStackLayout(spacing: 14))
            layout {
                POCFloorPlan(
                    rooms: SUBLevel2Map.rooms,
                    stations: signPins(state),
                    meetingPoint: meetingPoint(state),
                    completedStationIDs: [],
                    selectedStation: nil,
                    ownLastCheckpoint: checkpoint(state),
                    onSelectStation: { _ in },
                    players: store.liveDots(state: state)
                )
                .frame(width: landscape ? min(geo.size.height, geo.size.width * 0.56) : nil,
                       height: landscape ? nil : min(geo.size.width, geo.size.height * 0.5))
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    panel(state)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .overlay(alignment: .topLeading) {
            HUDCloseButton { dismiss() }
                .padding(.leading, 20)
                .padding(.top, 16)
        }
    }

    // MARK: - Side panel

    private func panel(_ state: GameState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LIVE MAP").font(.caption.weight(.bold)).tracking(2).foregroundStyle(.cyan)
                    Text("Testing: everyone sees everyone").font(.headline)
                }
                Toggle("Share everyone's position", isOn: Binding(
                    get: { store.livePositionsOn },
                    set: { store.updateSetting("livePositions", $0) }))
                    .font(.subheadline.weight(.semibold))
                you
                if store.livePositionsOn { others(state) }
                Text("Scan signs as you go: each scan pins you exactly. Keep the phone held up while walking so steps follow the compass. Dots fade when a phone goes quiet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var you: some View {
        let e = store.positions.estimate
        let d = store.positions.diagnostics
        return VStack(alignment: .leading, spacing: 6) {
            sectionTitle("YOU")
            if let e {
                HStack(alignment: .firstTextBaseline) {
                    Text("±\(meters(e.accuracyM))").font(.title2.bold().monospacedDigit())
                    Text(place(room: e.room, level: e.levelDelta)).font(.subheadline).foregroundStyle(.secondary)
                }
                sourcesRow(e.sources)
            } else {
                Text("No estimate yet. Scan a sign, or wait for GPS.").font(.subheadline).foregroundStyle(.secondary)
            }
            if let message = store.location.statusMessage {
                Text(message).font(.caption).foregroundStyle(.red)
            }
            Group {
                row("Last sign", d.lastFixName.map { name in "\(name) · \(ago(d.lastFixAt))" } ?? "none yet")
                row("Since then", "\(d.stepsSinceFix) steps · \(meters(d.metersSinceFix))"
                    + (d.stepsAvailable ? "" : " (no step counter)"))
                row("Compass", d.compassUsable ? "following it" : d.phoneHeldUp ? "unsure, calibrating" : "phone not held up")
                row("GPS", d.gpsAccuracyM.map { acc in
                    "±\(meters(acc))" + (d.gpsWeight.map { " · weight \(Int(($0 * 100).rounded()))%" } ?? "")
                        + (d.gpsOutlier ? " · jumped, mostly ignored" : "")
                } ?? "no fix")
                row("Floor", d.altitudeSinceFixM.map { String(format: "%+.1f m since last sign", $0) } ?? "no barometer")
                if d.snappedToMap { row("Map", "kept inside the nearest room") }
            }
        }
    }

    private func others(_ state: GameState) -> some View {
        let now = store.serverNow()
        let others = store.livePositions.filter { $0.playerId != state.me.id }
        return VStack(alignment: .leading, spacing: 8) {
            sectionTitle("PLAYERS")
            if others.isEmpty {
                Text("Nobody else yet. Their phones send a position every couple of seconds once they have one.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(others) { pos in
                let player = state.player(pos.playerId)
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill((player?.color ?? .white).swatch).frame(width: 12, height: 12).padding(.top, 3)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(player?.name ?? "Player").font(.subheadline.weight(.semibold))
                            Text("±\(meters(pos.accuracyM))").font(.subheadline.monospacedDigit())
                            Spacer()
                            Text(seconds((now - pos.at) / 1000)).font(.caption).foregroundStyle(pos.stale ? .red : .secondary)
                        }
                        Text(place(room: pos.room, level: pos.levelDelta)).font(.caption).foregroundStyle(.secondary)
                        sourcesRow(pos.sources)
                    }
                }
                .opacity(pos.stale ? 0.6 : 1)
            }
        }
    }

    // MARK: - Bits

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 72, alignment: .leading)
            Text(value).font(.caption.monospacedDigit())
        }
    }

    private func sourcesRow(_ sources: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(sources, id: \.self) { source in
                Text(label(source))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.18), in: Capsule())
            }
        }
    }

    private func label(_ source: String) -> String {
        switch source {
        case "sign": return "SIGN SCAN"
        case "steps": return "STEPS"
        case "compass": return "COMPASS"
        case "gps": return "GPS"
        case "map": return "FLOOR PLAN"
        case "baro": return "FLOOR CHANGE"
        case "nearby": return "NEAR A PLAYER"
        case "bot": return "BOT"
        default: return source.uppercased()
        }
    }

    private func place(room: String?, level: Int) -> String {
        let floor = level == 0 ? nil : level > 0 ? "\(level) floor\(level == 1 ? "" : "s") up" : "\(-level) floor\(level == -1 ? "" : "s") down"
        return [room, floor].compactMap { $0 }.joined(separator: " · ").ifEmpty("Not in a mapped room")
    }

    private func meters(_ m: Double) -> String { m < 10 ? String(format: "%.1f m", m) : "\(Int(m.rounded())) m" }

    private func seconds(_ s: Double) -> String { s < 60 ? "\(max(0, Int(s)))s ago" : "\(Int(s / 60))m ago" }

    private func ago(_ date: Date?) -> String {
        guard let date else { return "" }
        return seconds(Date().timeIntervalSince(date))
    }

    private func signPins(_ state: GameState) -> [POCStation] {
        state.stations.compactMap { s in
            guard s.kind == .task, let lat = s.lat, let lng = s.lng else { return nil }
            let label = s.signText ?? s.name
            return POCStation(id: s.id, displayName: label, taskType: "Sign", roomID: String(label.prefix(10)),
                              roomLabel: label, position: CGPoint(x: lng, y: lat))
        }
    }

    private func meetingPoint(_ state: GameState) -> CGPoint? {
        guard let m = state.stations.first(where: { $0.kind == .meeting }), let lat = m.lat, let lng = m.lng else { return nil }
        return CGPoint(x: lng, y: lat)
    }

    private func checkpoint(_ state: GameState) -> POCCheckpoint {
        guard let cp = state.me.lastCheckpoint, let s = state.station(cp.stationId) else {
            return POCCheckpoint(stationID: "", stationName: "", roomLabel: "", verifiedAt: .now)
        }
        return POCCheckpoint(stationID: s.id, stationName: s.name, roomLabel: s.name, verifiedAt: Date(timeIntervalSince1970: cp.at / 1000))
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
