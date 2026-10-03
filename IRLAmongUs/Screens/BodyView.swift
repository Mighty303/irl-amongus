import SwiftUI

/// The dead player's phone *is* the body. It stays where they died, glowing red, still
/// advertising over BLE so living players nearby get a REPORT button. Whoever finds it can
/// also press REPORT right here on the body's phone.
struct BodyView: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("💀").font(.system(size: 120))
            Text("BODY").font(.system(size: 80, weight: .black))
            Button {
                Task { await store.perform("report_body", ["method": "self"]) }
            } label: {
                Text("REPORT").font(.system(size: 44, weight: .black))
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20))
                    .foregroundStyle(.red)
            }
            Spacer()
            VStack(spacing: 4) {
                Text("YOU DIED").font(.headline)
                Text("Leave your phone here, face up. Lie down silently until you're found.")
                Text("You're a ghost now. Don't talk about the game.")
            }
            .font(.footnote)
            .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.red)
        .ignoresSafeArea()
        .onAppear { UIScreen.main.brightness = 1 }
    }
}
