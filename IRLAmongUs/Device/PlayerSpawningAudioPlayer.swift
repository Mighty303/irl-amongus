import AVFoundation
import SwiftUI

@MainActor
final class PlayerSpawningAudioPlayer: ObservableObject {
    private var player: AVAudioPlayer?

    func play() {
        guard !ProcessInfo.processInfo.arguments.contains("-disableAudio") else { return }

        if player == nil {
            guard let url = Bundle.main.url(forResource: "player-spawning", withExtension: "mp3") else {
                return
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                self.player = player
            } catch {
                // Players can still enter the lobby if audio is unavailable.
                return
            }
        }

        player?.currentTime = 0
        player?.play()
    }
}
