import Foundation

struct BodyReportPresentation: Identifiable, Equatable {
    let id = UUID()
    let bodyID: String
    let color: PlayerColor
}

/// Events and snapshots can arrive in either order. A body is reported once per round.
struct BodyReportState {
    private var reported = Set<String>()

    mutating func accept(bodyID: String) -> Bool { reported.insert(bodyID).inserted }
    mutating func reset() { reported.removeAll() }
}
