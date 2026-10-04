import AVFoundation
import SwiftUI

enum KillSound: String, CaseIterable {
    case killer = "among-us-kill"
    case victim = "among-us-killed"
}

@MainActor
final class KillAudioPlayer: ObservableObject {
    private var players: [KillSound: AVAudioPlayer] = [:]

    init() {
        guard !ProcessInfo.processInfo.arguments.contains("-disableAudio") else { return }
        for sound in KillSound.allCases {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[sound] = player
        }
    }

    func play(_ sound: KillSound = .killer) {
        let player = players[sound]
        player?.currentTime = 0
        player?.play()
    }

    func stop() { players.values.forEach { $0.stop() } }
}

/// One death cue per life, whether the event or state snapshot arrives first.
struct DeathSoundState {
    private var played = false

    mutating func killed(victimID: String?, localID: String?) -> Bool {
        guard let localID, victimID == localID, !played else { return false }
        played = true
        return true
    }

    mutating func update(wasAlive: Bool?, isAlive: Bool, isBody: Bool) -> Bool {
        if wasAlive == false && isAlive { played = false }
        guard wasAlive == true, !isAlive, isBody, !played else { return false }
        played = true
        return true
    }
}
