import Foundation

/// The full-screen meeting banner: a dead body reported (the body's colour) or the emergency button
/// pressed (the caller's colour). Shown the same way, over everything, before the meeting screen.
struct BodyReportPresentation: Identifiable, Equatable {
    enum Kind: Equatable { case body, emergency }

    let id = UUID()
    let bodyID: String
    let color: PlayerColor
    var kind: Kind = .body
}

/// Events and snapshots can arrive in either order. A body is reported once per round.
struct BodyReportState {
    private var reported = Set<String>()

    mutating func accept(bodyID: String) -> Bool { reported.insert(bodyID).inserted }
    mutating func reset() { reported.removeAll() }
}
