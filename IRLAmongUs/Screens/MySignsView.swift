import SwiftUI

/// The white Among Us style pop-up (same look as Customize) where a player adds the signs they owe
/// before the game can start. Adding a sign happens in the same panel (`SignCaptureStep`): take a
/// photo or pick one from Photos, the app reads what the sign says, then save. No naming.
struct MySignsView: View {
    @Environment(GameStore.self) private var store
    let close: () -> Void

    @State private var capturing = false
    @State private var moving: Station?

    var body: some View {
        SignPanelContainer { compact in
            if let state = store.state {
                panel(state: state, compact: compact)
            }
        }
    }

    private func panel(state: GameState, compact: Bool) -> some View {
        let required = max(state.requiredSigns, 1)
        let mine = state.mySigns.count
        let number = min(mine + 1, required)
        return VStack(alignment: .leading, spacing: 12) {
            SignPanel.header(moving != nil ? "Move pin" : capturing ? "Add a sign" : "My signs",
                             subtitle: moving != nil ? "Put the pin exactly on the sign"
                                 : capturing ? "Fill the frame with the sign · no naming needed"
                                 : "\(min(mine, required)) of \(required) · point and shoot, the app reads each sign")
            if let moving {
                SignPinStep(compact: compact, station: moving, others: state.stations.filter { $0.id != moving.id },
                            save: { await store.perform("move_station", $0.merging(["stationId": moving.id]) { $1 }) },
                            done: { self.moving = nil })
            } else if capturing {
                SignCaptureStep(compact: compact, title: "Sign \(number) of \(required)", fallbackName: "Sign \(number)") {
                    await store.perform("add_station", $0)
                } onSaved: {
                    capturing = false
                }
            } else {
                slots(state.mySigns, required: required)
            }
        }
        .signPanel(closeLabel: capturing || moving != nil ? "Back to my signs" : "Close my signs") {
            if moving != nil { moving = nil } else if capturing { capturing = false } else { close() }
        }
    }

    // MARK: - Slots

    private func slots(_ mine: [Station], required: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(mine.enumerated()), id: \.element.id) { index, sign in
                    filledSlot(sign, number: index + 1)
                }
                if mine.count < required {
                    ForEach(mine.count..<required, id: \.self) { index in
                        emptySlot(number: index + 1, of: required, next: index == mine.count)
                    }
                }
            }
            .padding(2)
        }
        .frame(maxHeight: .infinity)
    }

    private func filledSlot(_ sign: Station, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SignPanel.well
                .overlay {
                    if let photoId = sign.photoId, let base = store.serverURL {
                        AsyncImage(url: base.appendingPathComponent("photos/\(photoId).jpg")) { $0.resizable().scaledToFill() }
                            placeholder: { ProgressView() }
                    }
                }
                .frame(width: 168, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    Text("SIGN \(number)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(SignPanel.ready, in: Capsule())
                        .padding(6)
                }
            HStack(alignment: .center, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(sign.signText.map { "Reads “\($0)”" } ?? sign.name)
                        .font(.system(size: 13, weight: .black, design: .rounded)).lineLimit(1)
                    Text(sign.pinLabel(store.campus))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(sign.lat == nil ? SignPanel.error : SignPanel.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                SignPinStep.button("Sign \(number)") { moving = sign }
                Button {
                    Task { await store.perform("delete_station", ["stationId": sign.id]) }
                } label: {
                    Image(systemName: "trash").font(.system(size: 13, weight: .bold))
                        .frame(width: 32, height: 32)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(SignPanel.ink, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete sign \(number)")
            }
            .frame(width: 168)
        }
        .padding(8)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.8), lineWidth: 2))
    }

    private func emptySlot(number: Int, of required: Int, next: Bool) -> some View {
        Button { capturing = true } label: {
            VStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(next ? .white : SignPanel.ink)
                    .frame(width: 52, height: 52)
                    .background(next ? SignPanel.ink : SignPanel.well, in: Circle())
                Text("Add sign").font(.system(size: 15, weight: .black, design: .rounded))
                Text("Sign \(number) of \(required)").font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(SignPanel.muted)
            }
            .frame(width: 150, height: 172)
            .background(SignPanel.well.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(SignPanel.ink.opacity(next ? 1 : 0.35), style: StrokeStyle(lineWidth: 3, dash: [8, 6])))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mySigns.add.\(number)")
    }
}
