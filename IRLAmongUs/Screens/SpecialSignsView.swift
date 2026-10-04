import SwiftUI

/// A special sign the map can have: the red button (required) or an optional room.
struct SpecialSignSlot: Identifiable, Equatable {
    let id: String
    let kind: StationKind
    /// Which one of its kind (reactor has A and B).
    let index: Int
    let title: String
    let detail: String
    let required: Bool

    static let all: [SpecialSignSlot] = [
        .init(id: "emergency", kind: .emergency, index: 0, title: "Red button",
              detail: "Emergency meetings. Everyone gathers here too.", required: true),
        .init(id: "reactorA", kind: .reactor, index: 0, title: "Reactor A",
              detail: "Sabotage: meltdown. Needs both reactor signs.", required: false),
        .init(id: "reactorB", kind: .reactor, index: 1, title: "Reactor B",
              detail: "Sabotage: meltdown. Needs both reactor signs.", required: false),
        .init(id: "o2A", kind: .oxygen, index: 0, title: "O2 A",
              detail: "Sabotage: oxygen. Type the code at both O2 keypads.", required: false),
        .init(id: "o2B", kind: .oxygen, index: 1, title: "O2 B",
              detail: "Sabotage: oxygen. Type the code at both O2 keypads.", required: false),
        .init(id: "security", kind: .security, index: 0, title: "Security",
              detail: "The cameras room.", required: false),
        .init(id: "admin", kind: .admin, index: 0, title: "Admin",
              detail: "The room occupancy map.", required: false),
    ]

    func station(in stations: [Station]) -> Station? {
        let same = stations.filter { $0.kind == kind }
        return index < same.count ? same[index] : nil
    }
}

/// The red button and the optional special signs (sabotage, security, admin), in the same white panel
/// as My signs. Used by the lobby and by saved games, which pass their own add/remove.
struct SpecialSignsView: View {
    @Environment(GameStore.self) private var store
    let stations: [Station]
    /// Adds a sign; true when it worked.
    let submit: ([String: Any]) async -> Bool
    let delete: (Station) async -> Void
    /// Moves a sign's pin and floor (`SignPinStep` placement); true when it worked.
    let move: (Station, [String: Any]) async -> Bool
    let close: () -> Void
    /// Open straight on this sign's capture (e.g. tapped its tile in the lobby).
    var startSlot: SpecialSignSlot? = nil

    @State private var capturing: SpecialSignSlot?
    @State private var moving: (slot: SpecialSignSlot, station: Station)?
    @State private var started = false

    var body: some View {
        SignPanelContainer { compact in
            VStack(alignment: .leading, spacing: 12) {
                SignPanel.header(moving.map { "Move \($0.slot.title)" } ?? capturing?.title ?? "Special signs",
                                 subtitle: moving != nil ? "Put the pin exactly on the sign"
                                     : capturing?.detail ?? "The red button is required · the rest are optional")
                if let moving {
                    SignPinStep(compact: compact, station: moving.station,
                                others: stations.filter { $0.id != moving.station.id },
                                save: { await move(moving.station, $0) },
                                done: { self.moving = nil })
                } else if let slot = capturing {
                    SignCaptureStep(
                        compact: compact,
                        title: slot.title,
                        fallbackName: slot.title,
                        submit: { payload in
                            // Replacing: remove the old sign of this slot first (reactor has two, so be specific).
                            if let old = slot.station(in: stations) { await delete(old) }
                            return await submit(payload)
                        },
                        onSaved: { if startSlot != nil { close() } else { capturing = nil } },
                        kind: slot.kind,
                        fixedName: slot.title
                    )
                } else {
                    slots
                }
            }
            .signPanel(closeLabel: capturing == nil && moving == nil ? "Close special signs" : "Back to special signs") {
                // Opened on one sign: the X goes straight back to the lobby.
                if moving != nil { moving = nil }
                else if capturing != nil, startSlot == nil { capturing = nil } else { close() }
            }
        }
        .onAppear {
            guard !started else { return }
            started = true
            capturing = startSlot
        }
    }

    private var slots: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SpecialSignSlot.all) { slot in
                    if let station = slot.station(in: stations) {
                        filled(slot, station)
                    } else {
                        empty(slot)
                    }
                }
            }
            .padding(2)
        }
        .frame(maxHeight: .infinity)
    }

    private func filled(_ slot: SpecialSignSlot, _ station: Station) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SignPanel.well
                .overlay {
                    if let photoId = station.photoId, let base = store.serverURL {
                        AsyncImage(url: base.appendingPathComponent("photos/\(photoId).jpg")) { $0.resizable().scaledToFill() }
                            placeholder: { ProgressView() }
                    } else {
                        Image(systemName: slot.kind.icon).font(.title2).foregroundStyle(SignPanel.muted)
                    }
                }
                .frame(width: 150, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) { badge(slot, set: true) }
            Text(slot.title).font(.system(size: 14, weight: .black, design: .rounded))
            Text(station.pinLabel(store.campus))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(station.lat == nil ? SignPanel.error : SignPanel.muted).lineLimit(1)
            HStack(spacing: 6) {
                Button { capturing = slot } label: {
                    Text("REPLACE").font(.system(size: 12, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(SignPanel.ink, lineWidth: 2))
                }
                .buttonStyle(.plain)
                SignPinStep.button(slot.title) { moving = (slot, station) }
                Button { Task { await delete(station) } } label: {
                    Image(systemName: "trash").font(.system(size: 13, weight: .bold))
                        .frame(width: 32, height: 32)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(SignPanel.ink, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(slot.title)")
            }
        }
        .frame(width: 150)
        .padding(8)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.8), lineWidth: 2))
    }

    private func empty(_ slot: SpecialSignSlot) -> some View {
        Button { capturing = slot } label: {
            VStack(spacing: 6) {
                Image(systemName: slot.kind.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(slot.required ? .white : SignPanel.ink)
                    .frame(width: 48, height: 48)
                    .background(slot.required ? Color.red : SignPanel.well, in: Circle())
                Text(slot.title).font(.system(size: 15, weight: .black, design: .rounded))
                Text(slot.required ? "REQUIRED" : "OPTIONAL")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(slot.required ? Color.red : SignPanel.muted)
                Text(slot.detail)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(SignPanel.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(10)
            .frame(width: 150, height: 196)
            .background(SignPanel.well.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(slot.required ? Color.red : SignPanel.ink.opacity(0.35), style: StrokeStyle(lineWidth: 3, dash: [8, 6])))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(slot.title), \(slot.required ? "required" : "optional")")
    }

    private func badge(_ slot: SpecialSignSlot, set: Bool) -> some View {
        Label(slot.kind.shortLabel, systemImage: slot.kind.icon)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(POCPinStyle(slot.kind).color, in: Capsule())
            .padding(6)
    }
}

extension SpecialSignsView {
    /// This lobby's special signs (anyone can set them).
    static func lobby(store: GameStore, stations: [Station], startSlot: SpecialSignSlot? = nil,
                      close: @escaping () -> Void) -> SpecialSignsView {
        SpecialSignsView(
            stations: stations,
            submit: { await store.perform("add_station", $0) },
            delete: { await store.perform("delete_station", ["stationId": $0.id]) },
            move: { station, placement in
                await store.perform("move_station", placement.merging(["stationId": station.id]) { $1 })
            },
            close: close,
            startSlot: startSlot
        )
    }
}
