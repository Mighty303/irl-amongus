import SwiftUI

/// Lobby sheet where a player photographs the signs they must contribute before the game can start.
/// Everyone's signs become task stations; the server deals tasks across them at game start.
struct MySignsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var adding = false

    private static let teal = Color(red: 0.31, green: 0.56, blue: 0.55)
    private static let ready = Color(red: 0.56, green: 0.84, blue: 0.69)

    var body: some View {
        if let state = store.state {
            let required = max(state.requiredSigns, 1)
            let mine = state.mySigns
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MY SIGNS · \(min(mine.count, required)) OF \(required) ADDED")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Take photos of \(required) signs around the venue")
                            .font(.system(size: 24, weight: .light, design: .rounded))
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Text("DONE").font(.system(size: 15, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 22).frame(minHeight: 44)
                    }
                    .buttonStyle(MySignsOutlineButtonStyle())
                }
                Text("Just point and shoot: no naming needed, the app reads what the sign says. Everyone's signs become the game's task stations; tasks are dealt randomly when the game starts.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(mine.enumerated()), id: \.element.id) { index, sign in
                            filledSlot(sign, number: index + 1)
                        }
                        if mine.count < required {
                            ForEach(mine.count..<required, id: \.self) { index in
                                emptySlot(number: index + 1, of: required, primary: index == mine.count)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .foregroundStyle(.white)
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(white: 0.09))
            .preferredColorScheme(.dark)
            .sheet(isPresented: $adding, onDismiss: { OrientationDelegate.requestLandscape() }) {
                // Portrait, like in-game check-ins, so reference photos match what the scanner sees later.
                StationEditorView(signOnly: true, title: "Sign \(min(mine.count + 1, required)) of \(required)",
                                  fallbackName: "Sign \(mine.count + 1)")
                    .onAppear { OrientationDelegate.requestPortrait() }
            }
        }
    }

    private func filledSlot(_ sign: Station, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Group {
                    if let photoId = sign.photoId, let base = store.serverURL {
                        AsyncImage(url: base.appendingPathComponent("photos/\(photoId).jpg")) { $0.resizable().scaledToFill() }
                            placeholder: { Color(white: 0.2) }
                    } else {
                        Color(white: 0.2).overlay(Text("No photo").font(.caption).foregroundStyle(.secondary))
                    }
                }
                .frame(width: 210, height: 120)
                .clipped()
                Text("SIGN \(number)")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.05, green: 0.17, blue: 0.12))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Self.ready, in: Capsule())
                    .padding(8)
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(sign.signText.map { "Reads “\($0)”" } ?? sign.name)
                        .font(.system(size: 14, weight: .heavy, design: .rounded)).lineLimit(1)
                    Text(sign.lat != nil ? "Location tagged" : "No GPS (photo only)")
                        .font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                }
                Spacer(minLength: 6)
                Button {
                    Task { await store.perform("delete_station", ["stationId": sign.id]) }
                } label: {
                    Image(systemName: "trash").font(.system(size: 13)).frame(width: 32, height: 32)
                }
                .buttonStyle(MySignsOutlineButtonStyle(lineWidth: 1.5))
                .accessibilityLabel("Delete \(sign.name)")
            }
            .padding(10)
        }
        .frame(width: 210)
        .background(Color(white: 0.13), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.35), lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func emptySlot(number: Int, of required: Int, primary: Bool) -> some View {
        Button { adding = true } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 52, height: 52)
                    .background(primary ? Self.teal : Color(white: 0.18), in: Circle())
                Text("Add sign").font(.system(size: 15, weight: .heavy, design: .rounded))
                Text("Sign \(number) of \(required)").font(.system(size: 11, design: .rounded)).opacity(0.65)
            }
            .foregroundStyle(.white.opacity(primary ? 1 : 0.75))
            .frame(width: 180, height: 178)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(primary ? 0.5 : 0.3), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mySigns.add.\(number)")
    }
}

private struct MySignsOutlineButtonStyle: ButtonStyle {
    var lineWidth: CGFloat = 3

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? .black : .white)
            .background(configuration.isPressed ? Color.white : Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(lineWidth < 3 ? 0.4 : 1), lineWidth: lineWidth))
    }
}
