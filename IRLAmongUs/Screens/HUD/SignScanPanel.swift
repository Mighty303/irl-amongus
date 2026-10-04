import SwiftUI

/// Checking in at a sign, in the same white panel as Add signs: the live camera as a square on the
/// left; on the right, the sign to find, how close the camera is to matching it, and fallbacks.
/// Signs are recognized automatically (photo or text, two frames in a row); the sign's QR also works.
/// After a check-in the HUD opens that sign's task.
struct SignScanPanel: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    /// The sign a task needs, or nil for any sign (the big scan button).
    let target: Station?
    let close: () -> Void

    @State private var candidate: (id: String, hits: Int)?
    /// Feature-print distance to the target in the latest frame (lower = more alike).
    @State private var targetDistance: Float?
    @State private var submitting = false
    @State private var checkedIn: Station?
    @State private var message: String?

    /// Consecutive matching frames required, to avoid one-off false positives.
    private let requiredHits = 2

    var body: some View {
        SignPanelContainer { compact in
            VStack(alignment: .leading, spacing: 12) {
                SignPanel.header(target == nil ? "Scan a sign" : "Scan this sign",
                                 subtitle: "Fill the frame with the sign · it checks you in by itself")
                content(compact: compact)
            }
            .signPanel(closeLabel: "Stop scanning", close: close)
        }
        // In case the first download of the sign photos failed; photos already processed are reused.
        .onAppear { store.prepareSigns() }
    }

    private func content(compact: Bool) -> some View {
        let layout = compact ? AnyLayout(VStackLayout(spacing: 14)) : AnyLayout(HStackLayout(alignment: .top, spacing: 18))
        return layout {
            SignPanel.well
                .overlay {
                    CameraView(onQRCode: handleQR, onFrame: { [signs = store.signs, threshold = store.signThreshold] buffer in
                        // Camera queue: only touch thread-safe objects here, then hop to main.
                        let result = signs.analyze(buffer, threshold: threshold)
                        DispatchQueue.main.async { handle(result) }
                    })
                }
                .overlay { if checkedIn != nil { SignPanel.ready.opacity(0.25) } }
                .frame(width: compact ? nil : 260)
                .frame(maxWidth: compact ? .infinity : nil, maxHeight: compact ? 260 : .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(checkedIn != nil ? SignPanel.ready : Color(white: 0.8), lineWidth: checkedIn != nil ? 4 : 2))

            VStack(alignment: .leading, spacing: 10) {
                if let target { targetCard(target) }
                status
                if let message {
                    Text(message).font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(SignPanel.error).lineLimit(2)
                }
                Spacer(minLength: 0)
                fallbacks
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Right side

    private func targetCard(_ station: Station) -> some View {
        HStack(alignment: .top, spacing: 10) {
            HUDSignPhoto(station: station, cornerRadius: 10)
                .frame(width: 96, height: 72)
            VStack(alignment: .leading, spacing: 3) {
                Text(station.signText.map { "Reads “\($0)”" } ?? station.name)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .lineLimit(2)
                Text(whereIs(station))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(SignPanel.muted)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder private var status: some View {
        if let checkedIn {
            Label("Checked in at \(checkedIn.signText ?? checkedIn.name)", systemImage: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(SignPanel.ready)
        } else if let candidate, let station = state.station(candidate.id) {
            Label("Recognizing \(station.signText ?? station.name)…", systemImage: "viewfinder")
                .font(.system(size: 15, weight: .black, design: .rounded))
        } else if store.signs.loadedCount == 0, state.stations.contains(where: { $0.photoId != nil }) {
            Label("Loading the sign photos…", systemImage: "arrow.down.circle")
                .font(.system(size: 15, weight: .black, design: .rounded))
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label(target == nil ? "Point the camera at any sign" : "Point the camera at the sign",
                      systemImage: "camera.viewfinder")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                if target != nil { closeness }
            }
        }
    }

    /// Warmer/colder: how alike the camera frame and the sign's photo look right now.
    private var closeness: some View {
        let threshold = Double(store.signThreshold)
        let level = targetDistance.map { max(0, min(1, (1.6 - Double($0)) / max(1.6 - threshold, 0.1))) } ?? 0
        return HStack(spacing: 8) {
            Text("MATCH").font(.system(size: 10, weight: .black, design: .rounded)).foregroundStyle(SignPanel.muted)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(SignPanel.well)
                    Capsule().fill(level > 0.8 ? SignPanel.ready : SignPanel.ink)
                        .frame(width: max(8, geo.size.width * level))
                }
            }
            .frame(height: 8)
            .animation(.easeOut(duration: 0.3), value: level)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Match")
        .accessibilityValue("\(Int(level * 100)) percent")
    }

    @ViewBuilder private var fallbacks: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let gps = gpsOption {
                Button { submit(gps.station.id, method: "gps") } label: {
                    SignPanel.outlineLabel("CHECK IN BY GPS · \(HUDStyle.distance(gps.distance))", systemImage: "location.fill")
                }
                .buttonStyle(.plain)
                .disabled(submitting || checkedIn != nil)
            }
            if state.settings.devSkipCheckpoint, let target {
                SignPanel.filledButton("CHECK IN (DEV)", systemImage: "hammer.fill") { submit(target.id, method: "manual") }
            }
            if state.settings.qrFallback {
                Text("A QR code on the sign works too.")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(SignPanel.muted)
            }
        }
    }

    // MARK: - Logic

    /// GPS check-in, offered only once you're inside the sign's radius (the server checks it again).
    private var gpsOption: (station: Station, distance: Double)? {
        let candidates = target.map { [$0] } ?? state.stations
        return candidates
            .compactMap { s in store.location.distance(to: s).map { (station: s, distance: $0) } }
            .filter { $0.distance <= $0.station.radiusM }
            .min { $0.distance < $1.distance }
    }

    private func whereIs(_ station: Station) -> String {
        if let meters = store.location.distance(to: station) { return "\(station.name) · about \(HUDStyle.distance(meters)) away" }
        return station.lat == nil ? "No GPS for this sign: use the photo" : station.name
    }

    private func handle(_ result: SignRecognizer.FrameResult) {
        guard checkedIn == nil else { return }
        if let target { targetDistance = result.distances[target.id] }
        guard let match = result.best else { candidate = nil; return }
        let hits = candidate?.id == match.stationId ? (candidate?.hits ?? 0) + 1 : 1
        candidate = (match.stationId, hits)
        if hits >= requiredHits { submit(match.stationId, method: "sign") }
    }

    private func handleQR(_ payload: String) {
        guard case let .station(id)? = QRPayload(payload) else { return }
        submit(id, method: "qr")
    }

    private func submit(_ stationId: String, method: String) {
        guard !submitting, checkedIn == nil else { return }
        submitting = true
        message = nil
        Task {
            defer { submitting = false; candidate = nil }
            guard await store.checkIn(stationId: stationId, method: method) else {
                message = store.errorMessage
                return
            }
            checkedIn = state.station(stationId)
            if let target, stationId != target.id, let station = checkedIn {
                message = "That's “\(station.signText ?? station.name)”, not this task's sign."
            }
            // A beat to see the green, then back to the HUD, which opens the sign's task.
            try? await Task.sleep(for: .milliseconds(stationId == target?.id || target == nil ? 700 : 1600))
            close()
        }
    }
}
