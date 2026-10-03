import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("IRL Among Us")
                        .font(.largeTitle.bold())

                    Text("Gather your crew and start a game.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("Create Game") {
                    // Game setup will be added here.
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
            }
            .padding(32)
        }
    }
}

#Preview {
    ContentView()
}

