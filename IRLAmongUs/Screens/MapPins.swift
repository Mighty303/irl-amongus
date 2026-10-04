import SwiftUI

extension GameState {
    /// Pins for every sign with a location that isn't already a task pin: special signs by kind
    /// (red button, reactor, lights, security, admin) and other signs as small grey pins. The meeting
    /// point is drawn by the floor plan itself.
    func otherSignPins(excluding taskPinIds: Set<String>) -> [POCStation] {
        stations.compactMap { s in
            guard !taskPinIds.contains(s.id), s.kind != .meeting, let lat = s.lat, let lng = s.lng else { return nil }
            let label = s.kind == .task ? (s.signText ?? s.name) : s.kind.shortLabel
            return POCStation(id: s.id, displayName: s.signText ?? s.name, taskType: s.kind.label,
                              roomID: String(label.prefix(10)), roomLabel: s.name,
                              position: CGPoint(x: lng, y: lat), style: POCPinStyle(s.kind))
        }
    }

    var meetingPointPin: CGPoint? {
        guard let m = stations.first(where: { $0.kind == .meeting }), let lat = m.lat, let lng = m.lng else { return nil }
        return CGPoint(x: lng, y: lat)
    }
}

extension StationKind {
    /// Label under a special sign's map pin.
    var shortLabel: String {
        switch self {
        case .task: return "SIGN"
        case .meeting: return "MEETING"
        case .emergency: return "BUTTON"
        case .reactor: return "REACTOR"
        case .electrical: return "LIGHTS"
        case .security: return "SECURITY"
        case .admin: return "ADMIN"
        }
    }
}
