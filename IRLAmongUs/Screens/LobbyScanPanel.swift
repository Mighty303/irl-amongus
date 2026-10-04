import SwiftUI

/// Scanning the host's lobby QR from the Local screen, in the same white panel as Add signs and
/// in-game sign scanning: the live camera as a square on the left, what it found on the right.
/// Stays in landscape (camera frames are already upright), unlike the old portrait scanner sheet.
struct LobbyScanPanel: View {
    /// Called with the lobby invite payload once one is in view.
    let onLobby: (String) -> Void
    let close: () -> Void

    /// The room code of the lobby QR in view.
    @State private var found: String?
    @State private var message: String?

    var body: some View {
        SignPanelContainer { compact in
            VStack(alignment: .leading, spacing: 12) {
                SignPanel.header("Scan lobby QR", subtitle: "Point the camera at the host's lobby QR")
                content(compact: compact)
            }
            .signPanel(closeLabel: "Stop scanning", close: close)
        }
    }

    private func content(compact: Bool) -> some View {
        let layout = compact ? AnyLayout(VStackLayout(spacing: 14)) : AnyLayout(HStackLayout(alignment: .top, spacing: 18))
        return layout {
            SignPanel.well
                .overlay { CameraView(onQRCode: handleQR) }
                .overlay { if found != nil { SignPanel.ready.opacity(0.25) } }
                .frame(width: compact ? nil : 260)
                .frame(maxWidth: compact ? .infinity : nil, maxHeight: compact ? 260 : .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(found != nil ? SignPanel.ready : Color(white: 0.8), lineWidth: found != nil ? 4 : 2))

            VStack(alignment: .leading, spacing: 10) {
                if let found {
                    Label("Found lobby \(found)", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(SignPanel.ready)
                } else {
                    Label("Looking for a lobby QR…", systemImage: "qrcode.viewfinder")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                }
                Text("The host's QR is behind the QR button in their lobby.")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(SignPanel.muted)
                if let message {
                    Text(message).font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(SignPanel.error).lineLimit(2)
                }
                Spacer(minLength: 0)
                Button(action: close) {
                    SignPanel.outlineLabel("TYPE THE CODE INSTEAD", systemImage: "keyboard")
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func handleQR(_ payload: String) {
        guard found == nil else { return }
        guard case let .join(code, _)? = QRPayload(payload) else {
            message = "That's not a lobby QR. Scan the one in the host's lobby."
            Haptics.error()
            return
        }
        found = GameStore.normalizedRoomCode(code)
        message = nil
        Haptics.success()
        Task {
            try? await Task.sleep(for: .milliseconds(600)) // let the green "found" register before joining
            onLobby(payload)
        }
    }
}
