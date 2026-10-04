import AVFoundation
import SwiftUI

@MainActor
final class RoleRevealAudioPlayer: ObservableObject {
    private var player: AVAudioPlayer?

    init() {
        guard !ProcessInfo.processInfo.arguments.contains("-disableAudio"),
              let asset = NSDataAsset(name: "RoleRevealSound") else { return }
        player = try? AVAudioPlayer(data: asset.data)
        player?.prepareToPlay()
    }

    func play() {
        player?.currentTime = 0
        player?.play()
    }

    func stop() {
        player?.stop()
    }
}
