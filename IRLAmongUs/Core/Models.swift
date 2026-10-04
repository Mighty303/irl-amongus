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
    /// The rest are special signs: the red button (required), sabotage fixes (reactor, O2), and the optional
    /// Security (cameras) and Admin (room occupancy) rooms. `electrical` is the old lights sabotage.
    case task, meeting, emergency, reactor, oxygen, electrical, security, admin
    var id: String { rawValue }

    /// The kinds anyone can pick (the old lights sabotage is gone).
    static let allCases: [StationKind] = [.task, .meeting, .emergency, .reactor, .oxygen, .security, .admin]

    /// A kind from a newer server than this app reads as a plain sign, instead of failing the whole game state.
    init(from decoder: Decoder) throws {
        self = StationKind(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .task
    }

    var label: String {
        switch self {
        case .task: return "Sign (tasks)"
        case .meeting: return "Meeting point"
        case .emergency: return "Emergency button"
        case .reactor: return "Reactor"
        case .oxygen: return "O2 keypad"
        case .electrical: return "Electrical (lights)"
        case .security: return "Security (cameras)"
        case .admin: return "Admin (room map)"
        }
    }

    var icon: String {
        switch self {
        case .task: return "mappin"
        case .meeting: return "person.3.fill"
        case .emergency: return "light.beacon.max.fill"
        case .reactor: return "atom"
        case .oxygen: return "aqi.medium"
        case .electrical: return "bolt.fill"
        case .security: return "video.fill"
        case .admin: return "map.fill"
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
    /// Saved game whose signs this lobby is using (optional so older servers still decode).
    let gameset: GamesetRef?
    /// Lobby: signs each non-bot player must add, their share when a saved game supplies some.
    /// Optional for older servers, which use `signsPerPlayer` for everyone.
    let signQuotas: [String: Int]?

    var isHost: Bool { me.id == hostId }

    /// Signs a player must add before the host can start (0 = nothing to do).
    func requiredSigns(for playerId: String) -> Int { signQuotas?[playerId] ?? settings.signsPerPlayer ?? 0 }
    /// This player's share.
    var requiredSigns: Int { requiredSigns(for: me.id) }
    /// The red button sign is required to start.
    var hasRedButton: Bool { stations.contains { $0.kind == .emergency } }
    /// The building and floor picked for this game, if any.
    var playArea: CampusPlace? {
        guard let b = settings.mapBuildingId, !b.isEmpty, let f = settings.mapFloorId, !f.isEmpty else { return nil }
        return CampusPlace(buildingId: b, floorId: f)
    }
    func signs(addedBy playerId: String) -> [Station] {
        stations.filter { $0.kind == .task && $0.addedBy == playerId }
    }
    var mySigns: [Station] { signs(addedBy: me.id) }
    /// Mirrors the server's start check.
    var playersMissingSigns: [PlayerView] {
        players.filter { $0.isBot != true && signs(addedBy: $0.id).count < requiredSigns(for: $0.id) }
    }
    func station(_ id: String?) -> Station? { stations.first { $0.id == id } }
    func player(_ id: String?) -> PlayerView? { players.first { $0.id == id } }
    var alivePlayers: [PlayerView] { players.filter(\.alive) }
}

struct GamesetRef: Decodable, Equatable {
    let id: String
    let name: String
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
    /// Signs each non-bot player must add in the lobby before START (0 = no requirement).
    /// Optional so phones still decode snapshots from servers without lobby signs.
    var signsPerPlayer: Int?
    /// Demo: keep playing at impostor/crew parity so small games can reach a vote.
    /// Optional for compatibility with servers without this demo rule.
    var demoContinueAtParity: Bool?
    var uploadSec: Int
    /// Optional so phones still decode snapshots from servers without Submit Scan.
    var scanSec: Int?
    var sabotageCooldownSec: Int
    var reactorSec: Int
    var reactorWindowSec: Int
    /// Seconds to fix the oxygen. Optional for older servers.
    var oxygenSec: Int?
    /// Sabotages use existing signs the server picks instead of dedicated reactor/O2 signs. Optional for older servers.
    var autoSabotageSigns: Bool?
    /// Testing: everyone sees everyone's estimated position on the map. Optional for older servers.
    var livePositions: Bool?
    /// Play area: the SFU building and floor the game is on (campus map ids). Empty = not set.
    var mapBuildingId: String?
    var mapFloorId: String?
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
    /// Player who photographed this sign in the lobby (task signs only).
    let addedBy: String?
    /// SFU building and floor the sign is on (campus map). Optional for older signs and servers.
    var buildingId: String? = nil
    var floorId: String? = nil
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

/// A player's estimated position from the server's `positions` stream (live map, testing).
struct LivePosition: Decodable, Identifiable, Equatable {
    let playerId: String
    let lat: Double
    let lng: Double
    /// One-sigma uncertainty radius, meters.
    let accuracyM: Double
    let at: Double
    let roomId: String?
    let room: String?
    /// SFU building and floor, when the phone knows them. Optional for older servers.
    let buildingId: String?
    let floorId: String?
    let levelDelta: Int
    let sources: [String]
    let stale: Bool
    var id: String { playerId }
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
    /// Sent only to this victim by newer servers, for their kill animation.
    var killedBy: String? = nil
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
    /// Security cameras: whether you may watch (dead, or just scanned the Security sign), and whether
    /// someone else is watching so your phone should send its front camera. Optional for older servers.
    let canWatchCams: Bool?
    let camWanted: Bool?
    /// Just scanned the Admin sign: may open the admin map. Optional for older servers.
    let canViewAdmin: Bool?
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
    /// Impostors left after this vote (only when roles are revealed on ejection). Optional for older servers.
    let impostorsRemaining: Int?
}

/// Someone on the Admin map: where they are, without who (the server sends no names).
struct AdminPerson: Decodable, Equatable {
    let lat: Double
    let lng: Double
    let buildingId: String?
    let floorId: String?
}

struct SabotageView: Decodable, Equatable {
    struct FixStation: Decodable, Equatable {
        let stationId: String
        let active: Bool
    }
    let kind: String
    let deadline: Double?
    let stations: [FixStation]
    /// Oxygen: the code to type at each keypad (on the note beside it). Optional for older servers.
    let code: String?
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
