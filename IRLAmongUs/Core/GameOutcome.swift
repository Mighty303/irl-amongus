/// A player's team decides victory, including players who died before the game ended.
enum GameOutcome {
    static func didWin(winner: String?, localRole: String?) -> Bool {
        switch (winner, localRole) {
        case ("crewmates", "crewmate"), ("impostors", "impostor"): true
        default: false
        }
    }
}
