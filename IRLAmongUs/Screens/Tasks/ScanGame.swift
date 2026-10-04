import CoreMotion
import SwiftUI

/// Submit Scan: stand still for the scan while the Scan-Mo-Tron prints your details. Moving the
/// phone (walking off the scanner) or leaving the app restarts it; the server enforces the duration.
/// Coordinates are pixels of the 504-wide MedBay panel art.
struct ScanGame: View {
    @Environment(\.scenePhase) private var scenePhase
    let seconds: Int
    let playerName: String
    /// Tells the server the scan began (it enforces the duration). Returns false if rejected.
    let start: () async -> Bool
    let onDone: () -> Void

    @State private var startedAt: Date?
    @State private var progress = 0.0
    @State private var status = "Step onto the scanner"
    @State private var bloodType = ["O-", "AB+", "B+", "A+", "O+", "AB-", "B-", "A-"].randomElement()!
    @State private var motion = CMMotionManager()
    /// Smoothed device acceleration (g) beyond gravity.
    @State private var shake = 0.0
    /// False once the panel closes, so a pending restart doesn't start a scan nobody is watching.
    @State private var open = true

    var body: some View {
        SpriteStage(width: 504, height: 343) {
            ZStack {
                Image("TaskScanTop").at(252, 89.5)
                Image("TaskScanBottom").at(252, 266)
                readout.at(252, 108)
                if startedAt != nil, progress < 1 {
                    TimelineView(.animation) { context in
                        let t = context.date.timeIntervalSinceReferenceDate
                        Rectangle().fill(Color.green.opacity(0.6)).frame(width: 456, height: 3)
                            .shadow(color: .green, radius: 6)
                            .at(252, 62 + 92 * abs(sin(t * 1.5)))
                    }
                }
                Text(status)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                    .at(252, 225)
                Rectangle().fill(Color.green)
                    .frame(width: max(0, 448 * progress), height: 52)
                    .frame(width: 448, alignment: .leading)
                    .at(252, 299)
            }
        }
        .task { await begin() }
        .task(id: startedAt) {
            guard let startedAt else { return }
            while !Task.isCancelled {
                progress = min(1, Date().timeIntervalSince(startedAt) / Double(seconds))
                if progress >= 1 {
                    status = "Scan complete"
                    stopMotion()
                    onDone()
                    return
                }
                status = "Scanning... \(Int(progress * 100))%"
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { interrupt("Scan interrupted") }
            else if startedAt == nil, progress < 1 { Task { await begin() } }
        }
        .onDisappear {
            open = false
            stopMotion()
            TaskSound.scan.stop()
        }
    }

    /// The Scan-Mo-Tron's printout, revealed line by line as the scan runs.
    private var readout: some View {
        let id = String(playerName.uppercased().filter(\.isLetter).prefix(3)).padding(toLength: 3, withPad: "X", startingAt: 0)
        let lines = ["ID: \(id)P0   HT: 3' 6\"   WT: 92lb", "C: \(playerName.uppercased())   BT: \(bloodType)"]
        let shown = startedAt == nil ? 0 : min(lines.count, Int(progress * Double(lines.count + 1)))
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<shown, id: \.self) { Text(lines[$0]) }
        }
        .font(.system(size: 20, weight: .medium, design: .monospaced))
        .foregroundStyle(.white)
        .lineLimit(1).minimumScaleFactor(0.5)
        .frame(width: 440, height: 90, alignment: .topLeading)
    }

    private func begin() async {
        guard open, startedAt == nil else { return }
        status = "Step onto the scanner"
        guard await start() else { status = "Scanner busy. Try again"; return }
        progress = 0
        shake = 0
        startedAt = Date()
        TaskSound.scan.play()
        startMotion()
    }

    private func interrupt(_ text: String) {
        guard startedAt != nil, progress < 1 else { return }
        startedAt = nil
        progress = 0
        status = text
        stopMotion()
        TaskSound.scan.stop()
        Haptics.error()
    }

    /// Walking off the scanner restarts it, like stepping off the platform in the game.
    private func startMotion() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 0.1
        motion.startDeviceMotionUpdates(to: .main) { data, _ in
            guard let a = data?.userAcceleration else { return }
            shake = shake * 0.8 + sqrt(a.x * a.x + a.y * a.y + a.z * a.z) * 0.2
            if shake > 0.25 {
                interrupt("Stand still! Restarting...")
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    await begin()
                }
            }
        }
    }

    private func stopMotion() { motion.stopDeviceMotionUpdates() }
}
