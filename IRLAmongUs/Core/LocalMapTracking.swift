import CoreGraphics
import Foundation

enum LocalMapTracking {
    /// Local movement powers the game map; sharing controls only the network feed.
    static func isEnabled(phase: Phase, sharing: Bool) -> Bool {
        switch phase {
        case .PLAYING, .MEETING, .VOTING, .RESULT: return true
        case .LOBBY, .ROLE_REVEAL: return sharing
        case .GAME_OVER: return false
        }
    }

    static func coordinate(local: PositionEstimator.Estimate?, positions: [LivePosition],
                           playerID: String, serverNow: Double) -> CGPoint? {
        let own = positions.first {
            $0.playerId == playerID && !$0.stale && serverNow - $0.at <= 6_000
        }
        // BLE fusion can improve weak indoor GPS, especially on tablets without
        // a step counter. Keep accurate local sign/step fixes ahead of the echo.
        if let own, local == nil || own.accuracyM + 2 < local!.accuracyM {
            return CGPoint(x: own.lng, y: own.lat)
        }
        return local.map { CGPoint(x: $0.lng, y: $0.lat) }
    }
}
