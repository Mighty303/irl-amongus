import AVFoundation
import UIKit

/// Among Us game sounds (meetings, voting, ejection, sabotage, players leaving), stored as data assets by
/// scripts/import-game-sounds.py. Like the task sounds, they play on the default audio session.
enum GameSoundEffect: String {
    case emergencyMeeting = "SoundEmergencyMeeting"
    case sabotageAlarm = "SoundSabotageAlarm"
    case ejectText = "SoundEjectText"
    case vote = "SoundVote"
    case voteLockIn = "SoundVoteLockIn"
    case voteTimer = "SoundVoteTimer"
    case panelAppear = "SoundPanelAppear"
    case panelDisappear = "SoundPanelDisappear"
    case playerLeft = "SoundPlayerLeft"

    @MainActor private static var players: [GameSoundEffect: AVAudioPlayer] = [:]

    /// Plays from the start (restarting it if it's already playing). `loop` repeats until `stop()`.
    @MainActor func play(loop: Bool = false) {
        guard !ProcessInfo.processInfo.arguments.contains("-disableAudio"),
              let player = Self.players[self] ?? load() else { return }
        player.numberOfLoops = loop ? -1 : 0
        player.currentTime = 0
        player.play()
    }

    @MainActor func stop() { Self.players[self]?.stop() }

    @MainActor private func load() -> AVAudioPlayer? {
        guard let data = NSDataAsset(name: rawValue)?.data,
              let player = try? AVAudioPlayer(data: data) else { return nil }
        player.prepareToPlay()
        Self.players[self] = player
        return player
    }
}
