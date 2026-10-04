import AVFoundation
import Foundation

enum GameSound: String, CaseIterable {
    case bodyReport = "dead-body-reported"
    case crewmateVictory = "crewmate-victory"
    case impostorVictory = "imposter-victory"
}

@MainActor
final class GameAudioPlayer {
    private var players: [GameSound: AVAudioPlayer] = [:]

    func play(_ sound: GameSound) {
        guard !ProcessInfo.processInfo.arguments.contains("-disableAudio") else { return }
        if players[sound] == nil {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3"),
                  let audio = try? AVAudioPlayer(contentsOf: url) else { return }
            audio.prepareToPlay()
            players[sound] = audio
        }
        players.values.forEach { $0.stop() }
        players[sound]?.currentTime = 0
        players[sound]?.play()
    }
}

/// A report event and its meeting snapshot share one cue per body per round.
struct BodyReportSoundState {
    private var reported = Set<String>()

    mutating func accept(bodyID: String) -> Bool { reported.insert(bodyID).inserted }
    mutating func reset() { reported.removeAll() }
}

/// The winning team selects the cue; events and snapshots play it once per round.
struct VictorySoundState {
    private var played = false

    mutating func accept(winner: String) -> GameSound? {
        guard !played else { return nil }
        let sound: GameSound
        switch winner {
        case "crewmates": sound = .crewmateVictory
        case "impostors": sound = .impostorVictory
        default: return nil
        }
        played = true
        return sound
    }

    mutating func reset() { played = false }
}
