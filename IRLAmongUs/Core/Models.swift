import Foundation

// Mirrors the per-player snapshot built by `Game.viewFor` in server/src/game.ts.
// The server strips hidden information before sending, so nothing here is secret from this player.

enum Phase: String, Decodable {
    case LOBBY, ROLE_REVEAL, PLAYING, MEETING, VOTING, RESULT, GAME_OVER
}

enum Role: String, Codable {
    case crewmate, impostor
}

enum PlayerColor: String, Decodable, CaseIterable {
    case red, blue, green, pink, orange, yellow, black, white
    case purple, brown, cyan, lime, maroon, rose, banana

    var lobbyAssetName: String {
        "LobbyPlayer\(rawValue.capitalized)"
    }

    var name: String { rawValue.capitalized }
}

enum StationKind: String, Codable, CaseIterable, Identifiable {
    /// `task` stations are plain signs; the server assigns a random mini-game to each at game start.
    case task, meeting, emergency, reactor, electrical
    var id: String { rawValue }

    var label: String {
        switch self {
        case .task: return "Sign (tasks)"
        case .meeting: return "Meeting point"
        case .emergency: return "Emergency button"
        case .reactor: return "Reactor"
        case .electrical: return "Electrical (lights)"
        }
    }
}

enum TaskType: String, Codable, CaseIterable, Identifiable {
    case wiring, upload, sequence, delivery, swipe, shields, o2, scan, divert
    /// A mini-game from a newer server than this app. Decoding it this way keeps the rest of the
    /// game state readable instead of failing the whole snapshot.
    case unknown

    /// The mini-games this app can play (the lobby toggles).
    static let allCases: [TaskType] = [.wiring, .upload, .sequence, .delivery, .swipe, .shields, .o2, .scan, .divert]

    init(from decoder: Decoder) throws {
        self = TaskType(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wiring: return "Fix Wiring"
        case .upload: return "Upload Data"
        case .sequence: return "Start Reactor Sequence"
        case .delivery: return "Delivery"
        case .swipe: return "Swipe Card"
        case .shields: return "Prime Shields"
        case .o2: return "Clean O2 Filter"
        case .scan: return "Submit Scan"
        case .divert: return "Divert Power"
        case .unknown: return "New task (update the app)"
        }
    }
}

struct GameState: Decodable, Equatable {
    let serverTime: Double
    let code: String
    let mapId: String
    let phase: Phase
    let phaseDeadline: Double?
    let hostId: String
    let settings: Settings
    let stations: [Station]
    let players: [PlayerView]
    let taskProgress: TaskProgress
    let me: Me
    let emergencyAvailableAt: Double
    let meeting: Meeting?
    let result: VoteResult?
    let sabotage: SabotageView?
    let winner: String?
    let winReason: String?

    var isHost: Bool { me.id == hostId }
    func station(_ id: String?) -> Station? { stations.first { $0.id == id } }
    func player(_ id: String?) -> PlayerView? { players.first { $0.id == id } }
    var alivePlayers: [PlayerView] { players.filter(\.alive) }
}

struct Settings: Codable, Equatable {
    var impostors: Int
    var minPlayers: Int
    var tasksPerPlayer: Int
    var killCooldownSec: Int
    var roleRevealSec: Int
    var gatherTimeoutSec: Int
    var discussionSec: Int
    var votingSec: Int
    var resultSec: Int
    var anonymousVotes: Bool
    var revealRoleOnEject: Bool
    var emergencyMeetingsPerPlayer: Int
    var emergencyCooldownSec: Int
    /// Approximate meters; the server converts them to RSSI cutoffs (see `BLEDistance`).
    var killDistanceM: Double
    var reportDistanceM: Double
    /// Calibration: smoothed RSSI two phones read 1 m apart.
    var rssiAt1m: Double
    var pathLossExponent: Double
    var proximityFreshSec: Int
    var checkpointTtlSec: Int
    var qrFallback: Bool
    var devSkipProximity: Bool
    var devSkipCheckpoint: Bool
    var ghostTasks: Bool
    var taskTypes: [TaskType]
    /// Only filled in for the host; blank for everyone else.
    var forcedImpostorIds: [String]
    var uploadSec: Int
    /// Optional so phones still decode snapshots from servers without Submit Scan.
    var scanSec: Int?
    var sabotageCooldownSec: Int
    var reactorSec: Int
    var reactorWindowSec: Int
}

struct Station: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let kind: StationKind
    let lat: Double?
    let lng: Double?
    let radiusM: Double
    let signText: String?
    let photoId: String?
}

struct PlayerView: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    /// Server-assigned and persisted. Optional while older deployed servers roll forward.
    let color: PlayerColor?
    /// The player's cut-out head, served at /faces/:faceId.png. Optional for older servers.
    let faceId: String?
    let isHost: Bool
    /// Server-run test bot. Optional so phones still decode snapshots from servers without bots.
    let isBot: Bool?
    let connected: Bool
    let alive: Bool
    let ejected: Bool
    let role: Role?
    let hasVoted: Bool
}

struct TaskProgress: Decodable, Equatable {
    let done: Int
    let total: Int
    var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
}

struct Me: Decodable, Equatable {
    let id: String
    let name: String
    let role: Role?
    let alive: Bool
    let isBody: Bool
    let ackedRole: Bool
    let bleToken: String
    let qrToken: String
    let tasks: [GameTask]
    let lastCheckpoint: Checkpoint?
    let emergencyLeft: Int
    let hasVoted: Bool
    let voteTarget: String?
    let killCooldownUntil: Double?
    let killTargets: [String]
    let nearbyBodies: [String]
    let sabotageAvailableAt: Double?
}

struct GameTask: Decodable, Identifiable, Equatable {
    let id: String
    let type: TaskType
    let steps: [String]
    let step: Int
    let completed: Bool
    let startedAt: Double?

    var currentStationId: String? { completed ? nil : steps[min(step, steps.count - 1)] }
}

struct Checkpoint: Decodable, Equatable {
    let stationId: String
    let method: String
    let at: Double
}

struct Meeting: Decodable, Equatable {
    let kind: String
    let calledBy: String?
    let bodyId: String?
    let stage: String
    let arrived: [String]
}

struct VoteResult: Decodable, Equatable {
    struct Tally: Decodable, Equatable {
        let targetId: String?
        let count: Int
        let voterIds: [String]?
    }
    let tallies: [Tally]
    let ejectedId: String?
    let ejectedWasImpostor: Bool?
    let tie: Bool
    let ejectedRole: Role?
}

struct SabotageView: Decodable, Equatable {
    struct FixStation: Decodable, Equatable {
        let stationId: String
        let active: Bool
    }
    let kind: String
    let deadline: Double?
    let stations: [FixStation]
}

/// Log-distance path-loss model, matching the server's `rssiAtDistance`. BLE RSSI is noisy, so these are estimates.
enum BLEDistance {
    static func rssi(atMeters d: Double, rssiAt1m: Double, exponent: Double) -> Double {
        rssiAt1m - 10 * exponent * log10(max(d, 0.1))
    }

    static func meters(forRSSI rssi: Double, rssiAt1m: Double, exponent: Double) -> Double {
        pow(10, (rssiAt1m - rssi) / (10 * exponent))
    }
}

struct Session: Codable, Equatable {
    let code: String
    let playerId: String
    let token: String
}

/// QR payloads used across the app.
enum QRPayload {
    case join(code: String, server: String?)
    case station(id: String)
    case player(qrToken: String)

    init?(_ string: String) {
        guard let url = URL(string: string), url.scheme == "irlau",
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let pathParts = url.pathComponents.filter { $0 != "/" }
        switch url.host {
        case "join":
            guard let code = comps.queryItems?.first(where: { $0.name == "code" })?.value else { return nil }
            self = .join(code: code, server: comps.queryItems?.first(where: { $0.name == "server" })?.value)
        case "station":
            guard let id = pathParts.first else { return nil }
            self = .station(id: id)
        case "player":
            guard let token = pathParts.first else { return nil }
            self = .player(qrToken: token)
        default:
            return nil
        }
    }

    var string: String {
        switch self {
        case let .join(code, server):
            var comps = URLComponents(string: "irlau://join")!
            comps.queryItems = [URLQueryItem(name: "code", value: code)] + (server.map { [URLQueryItem(name: "server", value: $0)] } ?? [])
            return comps.string!
        case let .station(id): return "irlau://station/\(id)"
        case let .player(token): return "irlau://player/\(token)"
        }
    }
}
