import Foundation

struct KillPresentation: Identifiable, Equatable {
    let id: UUID
    let victimID: String
    var attackerColor: PlayerColor?
    let victimColor: PlayerColor

    init(victimID: String, attackerColor: PlayerColor?, victimColor: PlayerColor) {
        id = UUID()
        self.victimID = victimID
        self.attackerColor = attackerColor
        self.victimColor = victimColor
    }
}

/// Events, snapshots and acknowledgements can describe the same kill in any order.
struct KillPresentationState {
    private var presentedVictims = Set<String>()

    mutating func accept(victimID: String) -> Bool {
        presentedVictims.insert(victimID).inserted
    }

    mutating func reset() { presentedVictims.removeAll() }
}

extension PlayerColor {
    /// The same suit palette used by generate-lobby-player-colors.py.
    var suitRGB: (UInt8, UInt8, UInt8) {
        switch self {
        case .red: return (197, 17, 17)
        case .blue: return (19, 46, 210)
        case .green: return (17, 128, 45)
        case .pink: return (238, 84, 187)
        case .orange: return (240, 125, 13)
        case .yellow: return (246, 246, 87)
        case .black: return (63, 71, 78)
        case .white: return (215, 225, 241)
        case .purple: return (107, 47, 188)
        case .brown: return (113, 73, 30)
        case .cyan: return (56, 255, 221)
        case .lime: return (80, 240, 57)
        case .maroon: return (80, 15, 27)
        case .rose: return (236, 113, 151)
        case .banana: return (255, 255, 190)
        }
    }

    static func rosterColor(for id: String, in players: [PlayerView]) -> PlayerColor? {
        guard let index = players.firstIndex(where: { $0.id == id }) else { return nil }
        return players[index].color ?? allCases[index % allCases.count]
    }
}
