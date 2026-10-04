import AVFoundation
import SwiftUI

@MainActor
final class KillAudioPlayer: ObservableObject {
    private var player: AVAudioPlayer?

    init() {
        guard !ProcessInfo.processInfo.arguments.contains("-disableAudio"),
              let url = Bundle.main.url(forResource: "among-us-kill", withExtension: "mp3") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
    }

    func play() {
        player?.currentTime = 0
        player?.play()
    }

    func stop() { player?.stop() }
}
