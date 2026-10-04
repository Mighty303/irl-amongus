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
        .init(id: "lights", kind: .electrical, index: 0, title: "Lights",
              detail: "Sabotage: lights out, fixed at this sign.", required: false),
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
    let close: () -> Void

    @State private var capturing: SpecialSignSlot?

    var body: some View {
        SignPanelContainer { compact in
            VStack(alignment: .leading, spacing: 12) {
                SignPanel.header(capturing?.title ?? "Special signs",
                                 subtitle: capturing?.detail ?? "The red button is required · the rest are optional")
                if let slot = capturing {
                    SignCaptureStep(
                        compact: compact,
                        title: slot.title,
                        fallbackName: slot.title,
                        submit: { payload in
                            // Replacing: remove the old sign of this slot first (reactor has two, so be specific).
                            if let old = slot.station(in: stations) { await delete(old) }
                            return await submit(payload)
                        },
                        onSaved: { capturing = nil },
                        kind: slot.kind,
                        fixedName: slot.title
                    )
                } else {
                    slots
                }
            }
            .signPanel(closeLabel: capturing == nil ? "Close special signs" : "Back to special signs") {
                if capturing != nil { capturing = nil } else { close() }
            }
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
            Text(station.signText.map { "Reads “\($0)”" } ?? (station.lat != nil ? "On the map" : "No map pin"))
                .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(SignPanel.muted).lineLimit(1)
            HStack(spacing: 6) {
                Button { capturing = slot } label: {
                    Text("REPLACE").font(.system(size: 12, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(SignPanel.ink, lineWidth: 2))
                }
                .buttonStyle(.plain)
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
    static func lobby(store: GameStore, stations: [Station], close: @escaping () -> Void) -> SpecialSignsView {
        SpecialSignsView(
            stations: stations,
            submit: { await store.perform("add_station", $0) },
            delete: { await store.perform("delete_station", ["stationId": $0.id]) },
            close: close
        )
    }
}
