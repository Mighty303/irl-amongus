import Foundation
import Observation
import SwiftUI

/// Owns the connection to the authoritative game server and the device services.
/// Views render `state` (the server's redacted snapshot) and call `perform` for every action.
/// The client never decides outcomes; it only asks.
@MainActor
@Observable
final class GameStore {
    enum Connection: Equatable { case disconnected, connecting, connected }

    struct Alert: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let subtitle: String?
        let color: Color
    }

    // Persisted
    var serverURLString: String { didSet { preferences.set(serverURLString, forKey: "serverURL") } }
    var playerName: String { didSet { preferences.set(playerName, forKey: "playerName") } }
    private(set) var session: Session? {
        didSet { preferences.set(try? JSONEncoder().encode(session), forKey: "session") }
    }

    private(set) var isEnteringLobby = false
    private(set) var state: GameState?
    private(set) var connection: Connection = .disconnected
    /// False between (re)connecting and receiving a fresh snapshot. Actions are blocked until true.
    private(set) var isSynced = false
    var errorMessage: String?
    var alert: Alert?
    var killPresentation: KillPresentation?
    /// You just killed someone: a quick slash across your screen (changes with each kill).
    var killSlash: UUID?
    /// Where you were when you were killed (x = longitude, y = latitude): your body stays there on your map,
    /// and the map stops following you, until someone finds it.
    private(set) var deathSpot: CGPoint?
    var bodyReportPresentation: BodyReportPresentation?
    private(set) var bodyReportBackdrop: GameState?
    /// serverTime - localTime, in ms
    private(set) var clockOffset: Double = 0
    var signThreshold: Float { didSet { preferences.set(signThreshold, forKey: "signThreshold") } }
    /// Local opt-in; the sign requirement itself remains authoritative on the server.
    var demoModeEnabled: Bool { didSet { preferences.set(demoModeEnabled, forKey: "demoModeEnabled") } }
    /// How this phone works out where it is: GPS (the original), steps, or AR (Settings, for comparing them).
    var positionMode: PositionMode {
        didSet {
            preferences.set(positionMode.rawValue, forKey: "positionMode")
            positions.mode = positionMode
            positions.useARState(.off)
            updateARTracking()
            updateCameraStream()
        }
    }
    private(set) var isUpdatingDemoSigns = false
    private(set) var isUpdatingDemoVoting = false
    @ObservationIgnored private var demoSignRequirements: [String: Int] = [:]

    let ble = BLEProximity()
    let location = LocationService()
    let signs = SignRecognizer()
    /// This phone's own position estimate (sensors only).
    let positions = PositionEstimator()
    /// AR position mode's camera tracking.
    @ObservationIgnored private let arTracker = ARPositionTracker()
    @ObservationIgnored private var localTrackingOn = false
    /// The live map (testing) is open: track this phone even in a lobby with sharing off.
    var liveMapOpen = false { didSet { updateLocalTracking() } }
    /// Every SFU Burnaby building's floor plans, so play can happen anywhere on campus.
    let campus = CampusMap()
    /// Security cameras: the latest frame from each player's front camera, while you're watching.
    private(set) var camFeeds: [String: (image: UIImage, at: Date)] = [:]
    private(set) var isWatchingCams = false
    /// Admin map: everyone's whereabouts (no names) while it's open, for the room counts.
    private(set) var adminPeople: [AdminPerson] = []
    private(set) var isWatchingAdmin = false
    /// True while this phone's front camera is being sent to someone watching.
    private(set) var isStreamingCamera = false
    @ObservationIgnored private let frontCamera = FrontCameraStreamer()
    @ObservationIgnored private var cameraUsageObserver: NSObjectProtocol?
    /// Everyone's estimated positions, while live positions are on.
    private(set) var livePositions: [LivePosition] = []
    var livePositionsOn: Bool { state?.settings.livePositions == true }

    @ObservationIgnored private let killAudio = KillAudioPlayer()
    @ObservationIgnored private let gameAudio = GameAudioPlayer()
    @ObservationIgnored private var bodyReportSound = BodyReportSoundState()
    @ObservationIgnored private var victorySound = VictorySoundState()
    @ObservationIgnored private var deathSound = DeathSoundState()
    @ObservationIgnored private var killPresentationState = KillPresentationState()
    @ObservationIgnored private var bodyReportState = BodyReportState()
    @ObservationIgnored private var initializedCooldownForLobby: String? {
        didSet { preferences.set(initializedCooldownForLobby, forKey: "initializedKillCooldownLobby") }
    }
    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private let httpSession: URLSession
    @ObservationIgnored private var socket: URLSessionWebSocketTask?
    @ObservationIgnored private var pending: [Int: CheckedContinuation<Void, Error>] = [:]
    @ObservationIgnored private var nextRequestId = 1
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var proximityTask: Task<Void, Never>?
    @ObservationIgnored private var positionTask: Task<Void, Never>?
    @ObservationIgnored private var reconnectAttempt = 0

    init(defaults: UserDefaults = .standard, httpSession: URLSession = .shared, restoresSession: Bool = true) {
        self.preferences = defaults
        self.httpSession = httpSession
        initializedCooldownForLobby = defaults.string(forKey: "initializedKillCooldownLobby")
        // Saved addresses from local testing (Cloudflare quick tunnels, the old LAN placeholder) are dead;
        // move them to the hosted server. Any other saved address (e.g. a laptop on purpose) is kept.
        let saved = defaults.string(forKey: "serverURL")
        let isStale = saved.map { $0.contains("trycloudflare.com") || $0 == "http://192.168.1.100:3000" } ?? true
        serverURLString = isStale ? Self.defaultServerURL : saved!
        playerName = defaults.string(forKey: "playerName") ?? ""
        gamesetPassword = defaults.string(forKey: "gamesetPassword") ?? ""
        preferredColor = defaults.string(forKey: "preferredColor").flatMap(PlayerColor.init(rawValue:))
        preferredFaceId = defaults.string(forKey: "preferredFaceId")
        signThreshold = defaults.object(forKey: "signThreshold") as? Float ?? 0.6
        demoModeEnabled = defaults.bool(forKey: "demoModeEnabled")
        positionMode = defaults.string(forKey: "positionMode").flatMap(PositionMode.init(rawValue:)) ?? .ar
        if restoresSession, let data = defaults.data(forKey: "session") {
            session = try? JSONDecoder().decode(Session.self, from: data)
        }
        positions.campus = campus
        positions.mode = positionMode
        arTracker.onMove = { [positions] in positions.useARMove(east: $0, north: $1) }
        arTracker.onState = { [positions] in positions.useARState($0) }
        location.onLocation = { [positions] in positions.useGPS($0) }
        location.onHeading = { [positions] in positions.useHeading($0) }
        if session != nil { connect() }
        if let base = serverURL { Task { [campus] in await campus.load(serverURL: base) } }
        // No queue: runs at once on the posting thread (always main), so AR lets go of the camera before
        // the sign scanner's session is queued to start.
        cameraUsageObserver = NotificationCenter.default.addObserver(forName: CameraUsage.changed, object: nil, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateCameraStream()
                self?.updateARTracking()
            }
        }
    }

    /// Hosted game server (Render). There's no address field in the app; for a local server, launch with
    /// `-serverURL http://…` (Xcode scheme argument) or scan a lobby QR that carries another server.
    static let defaultServerURL = "https://irl-amongus-server.onrender.com"

    var serverURL: URL? { Self.validatedServerURL(serverURLString) }

    static func validatedServerURL(_ value: String) -> URL? {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.hasSuffix("://") else { return nil }
        while text.hasSuffix("/") { text.removeLast() }
        if !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text), ["http", "https"].contains(url.scheme),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else { return nil }
        return url
    }

    static func normalizedRoomCode(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func isValidRoomCode(_ value: String) -> Bool {
        let code = normalizedRoomCode(value)
        return code.count == 4 && code.utf8.allSatisfy { (65...90).contains($0) || (48...57).contains($0) }
    }

    var canEnterLobby: Bool {
        !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        serverURL != nil && !isEnteringLobby && session == nil
    }

    func serverNow() -> Double { Date().timeIntervalSince1970 * 1000 + clockOffset }

    /// Seconds remaining until a server timestamp.
    func secondsUntil(_ serverMs: Double?) -> Int? {
        guard let serverMs else { return nil }
        return max(0, Int(((serverMs - serverNow()) / 1000).rounded(.up)))
    }

    // MARK: - Lobby (REST)

    func createGame() async {
        await enterLobby(path: "games", body: lookBody(["name": playerName, "mapId": "default"]))
    }

    func joinGame(code: String) async {
        guard Self.isValidRoomCode(code) else { errorMessage = "Enter a four-character room code."; return }
        let code = Self.normalizedRoomCode(code)
        await enterLobby(path: "games/\(code)/join", body: lookBody(["name": playerName]))
    }

    private func enterLobby(path: String, body: [String: Any]) async {
        guard !isEnteringLobby, session == nil else { return }
        guard let base = serverURL else { errorMessage = "Enter a valid HTTP or HTTPS server address."; return }
        let name = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { errorMessage = "Enter your display name."; return }
        var body = body
        body["name"] = name
        isEnteringLobby = true
        errorMessage = nil
        defer { isEnteringLobby = false }
        do {
            let response = try await postJSON(base.appendingPathComponent(path), body: body)
            guard let code = response["code"] as? String, let playerId = response["playerId"] as? String,
                  let token = response["token"] as? String else { throw ClientError.server("Bad response") }
            session = Session(code: code, playerId: playerId, token: token)
            connect()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Adds your preferred suit colour to a create/join request (the server uses it if it's free).
    private func lookBody(_ body: [String: Any]) -> [String: Any] {
        var body = body
        if let preferredColor { body["color"] = preferredColor.rawValue }
        return body
    }

    func checkServer() async -> String {
        guard let base = serverURL else { return "Invalid URL" }
        do {
            var request = URLRequest(url: base.appendingPathComponent("health"))
            request.timeoutInterval = 5
            let (data, response) = try await httpSession.data(for: request)
            try validateHTTPResponse(response)
            return String(data: data, encoding: .utf8) ?? "OK"
        } catch {
            return error.localizedDescription
        }
    }

    struct GamesetSummary: Decodable, Identifiable, Equatable {
        let id: String
        let name: String
        let signs: Int
        let updatedAt: Double
    }

    struct Gameset: Decodable, Identifiable, Equatable {
        let id: String
        let name: String
        let stations: [Station]
        let updatedAt: Double
    }

    /// Shared password for creating and editing saved games (until accounts exist). Remembered once it works.
    var gamesetPassword: String { didSet { preferences.set(gamesetPassword, forKey: "gamesetPassword") } }
    /// Your look, picked on the Local screen (or last used in a lobby): sent when you create or join a game.
    var preferredColor: PlayerColor? { didSet { preferences.set(preferredColor?.rawValue, forKey: "preferredColor") } }
    var preferredFaceId: String? { didSet { preferences.set(preferredFaceId, forKey: "preferredFaceId") } }
    /// The lobby we've already put your saved face on, so it isn't sent again on every snapshot.
    @ObservationIgnored private var faceAppliedForLobby: String?
    var canEditGamesets: Bool { !gamesetPassword.isEmpty }

    /// Saved games: sets of already-photographed signs for no-setup demos. Anyone can list and use them.
    func gamesets() async throws -> [GamesetSummary] { try await getJSON("gamesets") }
    func gameset(_ id: String) async throws -> Gameset { try await getJSON("gamesets/\(id)") }

    private func getJSON<T: Decodable>(_ path: String) async throws -> T {
        guard let base = serverURL else { throw ClientError.server("Invalid server URL") }
        let (data, response) = try await httpSession.data(from: base.appendingPathComponent(path))
        try validateHTTPResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Checks the password with the server and remembers it if it's right.
    func unlockGamesets(password: String) async -> Bool {
        guard let base = serverURL else { return false }
        do {
            _ = try await postJSON(base.appendingPathComponent("gamesets/check"), body: ["password": password])
            gamesetPassword = password
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Password-protected change to saved games (create, add/remove signs, delete). nil if it failed (error shown).
    @discardableResult
    func editGamesets(_ path: String, _ body: [String: Any] = [:]) async -> [String: Any]? {
        guard let base = serverURL else { return nil }
        var payload = body
        payload["password"] = gamesetPassword
        do {
            return try await postJSON(base.appendingPathComponent(path), body: payload)
        } catch {
            if error.localizedDescription == "Wrong password" { gamesetPassword = "" }
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Host: use a saved game's signs in this lobby, or `nil` to go back to players' own signs.
    @discardableResult
    func useGameset(_ id: String?) async -> Bool {
        guard let base = serverURL, let session else { return false }
        do {
            _ = try await postJSON(base.appendingPathComponent("games/\(session.code)/gameset"),
                                   body: ["playerId": session.playerId, "token": session.token, "gamesetId": id as Any? ?? NSNull()])
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func uploadPhoto(_ image: UIImage) async throws -> String {
        guard let base = serverURL else { throw ClientError.server("Invalid server URL") }
        let jpeg = image.resized(maxDimension: 800).jpegData(compressionQuality: 0.8) ?? Data()
        let response = try await postJSON(base.appendingPathComponent("photos"), body: ["jpegBase64": jpeg.base64EncodedString()])
        guard let id = response["photoId"] as? String else { throw ClientError.server("Upload failed") }
        return id
    }

    /// Uploads a player's cut-out head (transparent PNG) and returns its id for `set_face`.
    func uploadFace(_ png: Data) async throws -> String {
        guard let base = serverURL else { throw ClientError.server("Invalid server URL") }
        let response = try await postJSON(base.appendingPathComponent("faces"), body: ["pngBase64": png.base64EncodedString()])
        guard let id = response["faceId"] as? String else { throw ClientError.server("Upload failed") }
        return id
    }

    func faceURL(_ faceId: String?) -> URL? {
        guard let faceId, let base = serverURL else { return nil }
        return base.appendingPathComponent("faces/\(faceId).png")
    }

    private func postJSON(_ url: URL, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 10
        let (data, response) = try await httpSession.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if let error = json["error"] as? String { throw ClientError.server(error) }
        try validateHTTPResponse(response)
        return json
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode
            throw ClientError.server(status.map { "Server returned HTTP \($0)." } ?? "Invalid server response.")
        }
    }

    /// Handles lobby invites from the in-app scanner or the system camera.
    func handle(url: URL) async {
        await handleLobbyQRCode(url.absoluteString)
    }

    func handleLobbyQRCode(_ payload: String) async {
        guard case let .join(code, server)? = QRPayload(payload) else {
            errorMessage = "Scan a lobby invite QR code. Station and player codes cannot join a game."
            return
        }
        guard session == nil, !isEnteringLobby else {
            errorMessage = "Leave your current game before joining another lobby."
            return
        }
        guard Self.isValidRoomCode(code) else { errorMessage = "Enter a four-character room code."; return }
        if let server {
            guard Self.validatedServerURL(server) != nil else {
                errorMessage = "This lobby QR contains an invalid server address."
                return
            }
            serverURLString = server
        }
        errorMessage = nil
        let normalizedCode = Self.normalizedRoomCode(code)
        pendingJoinCode = normalizedCode
        // The picker asks for a name on a fresh install, then joins this same invite.
        guard !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        await joinGame(code: normalizedCode)
    }

    /// Opens the LOCAL picker and preserves the scanned invite while requesting a name.
    var pendingJoinCode: String?

    func leave() {
        // Quitting a lobby removes you there (your name is free to rejoin), instead of leaving you offline.
        // Close the connection only once the message is out.
        if state?.phase == .LOBBY, isSynced, let socket,
           let data = try? JSONSerialization.data(withJSONObject: ["id": 0, "action": "leave", "payload": [String: Any]()]) {
            self.socket = nil
            socket.send(.string(String(decoding: data, as: UTF8.self))) { _ in socket.cancel(with: .goingAway, reason: nil) }
        }
        disconnect()
        alert = nil
        killAudio.stop()
        deathSound = DeathSoundState()
        killPresentation = nil
        killPresentationState.reset()
        bodyReportPresentation = nil
        bodyReportBackdrop = nil
        bodyReportState.reset()
        initializedCooldownForLobby = nil
        session = nil
        state = nil
        livePositions = []
        camFeeds = [:]
        isWatchingCams = false
        updateCameraStream()
        ble.stop()
        location.stop()
        positions.reset()
        GameSoundEffect.sabotageAlarm.stop()
        localTrackingOn = false
        updateARTracking()
    }

    // MARK: - WebSocket

    func connect() {
        guard let session, let base = serverURL,
              var comps = URLComponents(url: base.appendingPathComponent("ws"), resolvingAgainstBaseURL: false) else { return }
        comps.scheme = base.scheme == "https" ? "wss" : "ws"
        if !campus.isFullCampus { Task { [campus] in await campus.load(serverURL: base) } }
        comps.queryItems = [
            URLQueryItem(name: "code", value: session.code),
            URLQueryItem(name: "playerId", value: session.playerId),
            URLQueryItem(name: "token", value: session.token),
        ]
        guard let url = comps.url else { return }

        socket?.cancel(with: .goingAway, reason: nil)
        reconnectTask?.cancel()
        isSynced = false
        connection = .connecting
        let task = URLSession.shared.webSocketTask(with: url)
        socket = task
        task.resume()
        receive(on: task)
        startProximityReporting()
        startPositionReporting()
    }

    func disconnect() {
        reconnectTask?.cancel()
        proximityTask?.cancel()
        positionTask?.cancel()
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        connection = .disconnected
        isSynced = false
        failPending(ClientError.server("Disconnected"))
        updateCameraStream() // backgrounded or offline: camera off
    }

    /// PRD: on returning to the app, fetch authoritative state before enabling actions.
    func scenePhaseChanged(_ phase: ScenePhase) {
        guard session != nil else { return }
        switch phase {
        case .active: connect() // fresh socket -> server sends a full snapshot -> isSynced
        case .background: disconnect()
        default: break
        }
    }

    private func receive(on task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            Task { @MainActor in
                guard let self, self.socket === task else { return }
                switch result {
                case let .success(message):
                    if case let .string(text) = message { self.handleMessage(Data(text.utf8)) }
                    if case let .data(data) = message { self.handleMessage(data) }
                    self.receive(on: task)
                case let .failure(error):
                    self.handleSocketClosed(task: task, error: error)
                }
            }
        }
    }

    private func handleSocketClosed(task: URLSessionWebSocketTask, error: Error) {
        connection = .disconnected
        isSynced = false
        failPending(error)
        if task.closeCode.rawValue == 4001 { // server doesn't know this game/player any more
            errorMessage = "That game no longer exists."
            leave()
            return
        }
        guard session != nil else { return }
        reconnectAttempt += 1
        let delay = min(5.0, 0.5 * Double(reconnectAttempt))
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.connect()
        }
    }

    private struct Envelope: Decodable {
        let type: String
        let id: Int?
        let ok: Bool?
        let error: String?
        let event: String?
        let state: GameState?
        let positions: [LivePosition]?
        let playerId: String?
        let jpeg: String?
        let people: [AdminPerson]?
    }

    private func handleMessage(_ data: Data) {
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            errorMessage = "Decode error: \(error)"
            return
        }
        switch envelope.type {
        case "state":
            guard let newState = envelope.state else { return }
            apply(newState)
        case "ack":
            guard let id = envelope.id, let continuation = pending.removeValue(forKey: id) else { return }
            if envelope.ok == true { continuation.resume() } else { continuation.resume(throwing: ClientError.server(envelope.error ?? "Failed")) }
        case "event":
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            handleEvent(envelope.event ?? "", data: json?["data"] as? [String: Any] ?? [:])
        case "positions":
            livePositions = envelope.positions ?? []
        case "cam":
            guard isWatchingCams, let id = envelope.playerId, let jpeg = envelope.jpeg,
                  let data = Data(base64Encoded: jpeg), let image = UIImage(data: data) else { return }
            camFeeds[id] = (image, Date())
        case "admin":
            guard isWatchingAdmin else { return }
            adminPeople = envelope.people ?? []
        default:
            break
        }
    }

    private func apply(_ newState: GameState) {
        let old = state
        if old?.code != newState.code || (old?.phase != newState.phase
            && (newState.phase == .LOBBY || newState.phase == .ROLE_REVEAL)) {
            bodyReportSound.reset()
            victorySound.reset()
            bodyReportPresentation = nil
            bodyReportBackdrop = nil
            bodyReportState.reset()
        }
        if old != nil, old?.phase != .GAME_OVER, newState.phase == .GAME_OVER,
           let winner = newState.winner {
            playVictorySound(winner: winner)
        }
        // Snapshot fallback covers a missed event, without replaying on reconnect.
        if old?.phase == .PLAYING, newState.phase == .MEETING,
           newState.meeting?.kind == "body", let bodyID = newState.meeting?.bodyId {
            presentBodyReport(bodyID: bodyID, roster: newState.players, backdrop: old)
        }
        if (old?.phase != newState.phase && (newState.phase == .LOBBY || newState.phase == .ROLE_REVEAL))
            || (old?.me.alive == false && newState.me.alive) {
            killPresentation = nil
            killPresentationState.reset()
        }
        clockOffset = newState.serverTime - Date().timeIntervalSince1970 * 1000
        state = newState
        PlayerFaceCache.shared.prefetch(newState.players.compactMap { faceURL($0.faceId) })
        playStateSounds(old: old, new: newState)
        if deathSound.update(wasAlive: old?.me.alive, isAlive: newState.me.alive, isBody: newState.me.isBody) {
            killAudio.play(.victim)
        }
        if old?.me.alive == true && !newState.me.alive && newState.me.isBody {
            deathSpot = positions.estimate.map { CGPoint(x: $0.lng, y: $0.lat) }
            presentKill(victimID: newState.me.id, killerID: newState.me.killedBy)
        }
        if !newState.me.isBody { deathSpot = nil }
        connection = .connected
        isSynced = true
        reconnectAttempt = 0

        // Use the temporary playtest default once per host lobby; subsequent edits stay intact.
        if newState.phase == .LOBBY, newState.isHost, initializedCooldownForLobby != newState.code {
            initializedCooldownForLobby = newState.code
            if newState.settings.killCooldownSec != 10 {
                Task { await perform("update_settings", ["killCooldownSec": 10]) }
            }
        }

        // BLE also runs in the lobby while live positions are on: who's next to whom sharpens the map.
        if newState.phase == .GAME_OVER || (newState.phase == .LOBBY && newState.settings.livePositions != true) {
            ble.stop()
        } else {
            ble.start(token: newState.me.bleToken)
        }
        location.start()
        positions.playArea = newState.playArea
        // Put your saved face on once you're in a lobby (the colour went with the join request).
        if newState.phase == .LOBBY, let face = preferredFaceId, faceAppliedForLobby != newState.code,
           newState.player(newState.me.id)?.faceId != face {
            faceAppliedForLobby = newState.code
            Task { await perform("set_face", ["faceId": face]) }
        }
        if newState.me.canWatchCams != true, isWatchingCams { isWatchingCams = false; camFeeds = [:] }
        if newState.me.canViewAdmin != true, isWatchingAdmin { isWatchingAdmin = false; adminPeople = [] }
        updateCameraStream()
        // The local map follows movement even when position sharing is disabled.
        updateLocalTracking()
        if newState.settings.livePositions != true { livePositions = [] }
        // Everyone starts the game at the red button: the first fix, before any sign is scanned.
        // (Not in GPS mode, which is kept as it originally was for comparison.)
        if positionMode != .gps, old?.phase == .ROLE_REVEAL, newState.phase == .PLAYING,
           let button = newState.stations.first(where: { $0.kind == .emergency }), let lat = button.lat, let lng = button.lng {
            positions.fix(lat: lat, lng: lng, name: "Red button (start)", buildingId: button.buildingId, floorId: button.floorId,
                          accuracyM: PositionEstimator.startFixM)
        }
        // A verified check-in at a sign tells us exactly where this phone is.
        if let cp = newState.me.lastCheckpoint, cp != old?.me.lastCheckpoint, cp.method != "manual",
           serverNow() - cp.at < 30_000, // not an old check-in replayed by a reconnect
           let station = newState.station(cp.stationId), let lat = station.lat, let lng = station.lng {
            positions.fix(lat: lat, lng: lng, name: station.signText ?? station.name,
                          buildingId: station.buildingId, floorId: station.floorId)
        }

        if old?.stations != newState.stations { prepareSigns() }
        // Discreet buzz when a kill target first comes into range.
        if newState.me.role == .impostor, old?.me.killTargets.isEmpty ?? true, !newState.me.killTargets.isEmpty {
            Haptics.killInRange()
        }
        if old?.me.nearbyBodies.isEmpty ?? true, !newState.me.nearbyBodies.isEmpty {
            Haptics.heavy()
        }
    }

    private func playBodyReportSound(bodyID: String) {
        guard bodyReportSound.accept(bodyID: bodyID) else { return }
        gameAudio.play(.bodyReport)
    }

    private func playVictorySound(winner: String) {
        guard let sound = victorySound.accept(winner: winner, localRole: state?.me.role?.rawValue) else { return }
        gameAudio.play(sound)
    }

    private func handleEvent(_ event: String, data: [String: Any]) {
        switch event {
        case "ROLE_ASSIGNED":
            Haptics.heavy()
        case "PLAYER_KILLED":
            if let victimID = data["victimId"] as? String {
                let killerID = data["killerId"] as? String
                // Only the victim sees the kill animation; the killer gets a slash (`killSlash`).
                if victimID == session?.playerId {
                    presentKill(victimID: victimID, killerID: killerID)
                }
            }
            if deathSound.killed(victimID: data["victimId"] as? String, localID: session?.playerId) {
                killAudio.play(.victim)
            }
            if data["victimId"] as? String == session?.playerId { Haptics.alarm(times: 2) } else { Haptics.success() }
        case "BODY_REPORTED":
            if let state, state.phase == .PLAYING || state.phase == .MEETING,
               let bodyID = data["bodyId"] as? String ?? state.meeting?.bodyId
                ?? state.players.first(where: { !$0.alive && $0.name == data["bodyName"] as? String })?.id {
                presentBodyReport(bodyID: bodyID, roster: state.players,
                                  backdrop: state.phase == .PLAYING ? state : nil)
            }
            Haptics.alarm()
        case "EMERGENCY_MEETING":
            if let state {
                presentEmergencyMeeting(callerID: data["callerId"] as? String ?? state.meeting?.calledBy, roster: state.players,
                                        backdrop: state.phase == .PLAYING ? state : nil)
            }
            Haptics.alarm()
        case "VOTING_STARTED":
            Haptics.heavy()
        case "SABOTAGE_STARTED":
            let kind = data["kind"] as? String
            // Reactor and O2: no title screen; the map shows red crisis text and only their signs, with flashing arrows.
            if kind == "lights" {
                alert = Alert(title: "💡 LIGHTS SABOTAGED", subtitle: "Fix the lights at Electrical.", color: .orange)
            }
            // Among Us sounds the alarm until the reactor or oxygen is fixed; lights go out silently.
            if kind == "reactor" || kind == "oxygen" { GameSoundEffect.sabotageAlarm.play(loop: true) }
            Haptics.alarm(times: 2)
        case "SABOTAGE_RESOLVED":
            GameSoundEffect.sabotageAlarm.stop()
            Haptics.success()
        case "CREWMATES_WIN":
            playVictorySound(winner: "crewmates")
            Haptics.alarm(times: 1)
        case "IMPOSTORS_WIN":
            playVictorySound(winner: "impostors")
            Haptics.alarm(times: 1)
        case "KICKED":
            errorMessage = "You were removed from the lobby."
            leave()
        default:
            break
        }
    }

    // MARK: - Actions

    private func presentKill(victimID: String, killerID: String?) {
        guard let state, bodyReportPresentation == nil else { return }
        if killPresentationState.accept(victimID: victimID) {
            killPresentation = KillPresentation.from(victimID: victimID, killerID: killerID, players: state.players, serverURL: serverURL)
        } else if killPresentation?.victimID == victimID, let killerID {
            // Resolve a late attacker by ID, even when another player has the same suit colour.
            killPresentation?.resolveAttacker(killerID, players: state.players)
        }
    }

    func dismissKill(_ id: UUID) {
        if killPresentation?.id == id { killPresentation = nil }
    }

    private func presentBodyReport(bodyID: String, roster: [PlayerView], backdrop: GameState?) {
        guard bodyReportState.accept(bodyID: bodyID) else { return }
        playBodyReportSound(bodyID: bodyID)
        killPresentation = nil
        alert = nil
        bodyReportBackdrop = backdrop
        bodyReportPresentation = BodyReportPresentation(bodyID: bodyID,
            color: PlayerColor.rosterColor(for: bodyID, in: roster) ?? .black)
    }

    /// The emergency button: the caller at the table, "EMERGENCY MEETING" and the alarm, over everything.
    private func presentEmergencyMeeting(callerID: String?, roster: [PlayerView], backdrop: GameState?) {
        GameSoundEffect.emergencyMeeting.play()
        killPresentation = nil
        alert = nil
        bodyReportBackdrop = backdrop
        bodyReportPresentation = BodyReportPresentation(bodyID: callerID ?? "emergency",
            color: callerID.flatMap { PlayerColor.rosterColor(for: $0, in: roster) } ?? .red, kind: .emergency,
            faceId: roster.first(where: { $0.id == callerID })?.faceId, faceBaseURL: serverURL)
    }

    /// Voting, lobby and sabotage sounds that follow from the snapshot rather than an event.
    private func playStateSounds(old: GameState?, new: GameState) {
        guard let old, old.code == new.code else { return }
        let votes = { (s: GameState) in s.players.filter(\.hasVoted).count }
        if new.phase == .VOTING, old.phase == .VOTING, votes(new) > votes(old) { GameSoundEffect.vote.play() }
        if old.phase == .VOTING, new.phase != .VOTING { GameSoundEffect.voteLockIn.play() }
        if new.phase == .LOBBY, old.phase == .LOBBY,
           old.players.contains(where: { p in p.id != new.me.id && !new.players.contains { $0.id == p.id } }) {
            GameSoundEffect.playerLeft.play()
        }
        // The alarm stops with the sabotage (fixed, a meeting, the game ending), however we hear of it.
        if !["reactor", "oxygen"].contains(new.sabotage?.kind ?? "") || new.phase != .PLAYING { GameSoundEffect.sabotageAlarm.stop() }
    }

    func dismissBodyReport(_ id: UUID) {
        guard bodyReportPresentation?.id == id else { return }
        bodyReportPresentation = nil
        bodyReportBackdrop = nil
    }

    /// Sends an action and waits for the server's ack. Throws the server's rejection reason.
    func send(_ action: String, _ payload: [String: Any] = [:]) async throws {
        guard let socket, isSynced else { throw ClientError.server("Not connected. Reconnecting…") }
        let isKill = action == "kill"
        let id = nextRequestId
        nextRequestId += 1
        let data = try JSONSerialization.data(withJSONObject: ["id": id, "action": action, "payload": payload])
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            pending[id] = continuation
            socket.send(.string(String(decoding: data, as: UTF8.self))) { error in
                guard let error else { return }
                Task { @MainActor in self.pending.removeValue(forKey: id)?.resume(throwing: error) }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(8))
                self.pending.removeValue(forKey: id)?.resume(throwing: ClientError.server("Server didn't respond"))
            }
        }
        if isKill {
            // The killer: Among Us's impostor kill sound and a slash across the screen (the victim gets the animation).
            GameSoundEffect.impostorKill.play()
            killSlash = UUID()
            Haptics.heavy()
        }
    }

    /// `send` that surfaces errors to the user. Returns whether the server accepted the action.
    @discardableResult
    func perform(_ action: String, _ payload: [String: Any] = [:]) async -> Bool {
        do {
            try await send(action, payload)
            return true
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
            return false
        }
    }

    func updateSetting<T>(_ key: String, _ value: T) {
        Task { await perform("update_settings", [key: value]) }
    }

    /// Only the synced lobby host can waive sign setup. Keep the previous count for restoring it.
    func setDemoSignsRequired(_ required: Bool) async {
        guard demoModeEnabled, isSynced, !isUpdatingDemoSigns,
              let state, state.isHost, state.phase == .LOBBY,
              let perPlayer = state.settings.signsPerPlayer else { return }
        let key = "\(state.code):\(state.me.id)"
        if !required, perPlayer > 0 { demoSignRequirements[key] = perPlayer }
        let count = required ? (demoSignRequirements[key] ?? 3) : 0
        isUpdatingDemoSigns = true
        defer { isUpdatingDemoSigns = false }
        await perform("update_settings", ["signsPerPlayer": count])
    }

    func setDemoContinueAtParity(_ enabled: Bool) async {
        guard demoModeEnabled, isSynced, !isUpdatingDemoVoting,
              let state, state.isHost, state.phase == .LOBBY,
              state.settings.demoContinueAtParity != nil else { return }
        isUpdatingDemoVoting = true
        defer { isUpdatingDemoVoting = false }
        await perform("update_settings", ["demoContinueAtParity": enabled])
    }

    // MARK: - Security cameras

    /// Start or stop watching every player's camera (dead players, or right after scanning Security).
    @discardableResult
    /// Admin map: open it (the server checks you just scanned the Admin sign) or close it.
    func watchAdmin(_ on: Bool) async -> Bool {
        if !on {
            isWatchingAdmin = false
            adminPeople = []
            try? await send("admin_watch", ["on": false])
            return true
        }
        isWatchingAdmin = true
        if await perform("admin_watch", ["on": true]) { return true }
        isWatchingAdmin = false
        return false
    }

    func watchCams(_ on: Bool) async -> Bool {
        if !on {
            isWatchingCams = false
            camFeeds = [:]
            try? await send("cam_watch", ["on": false])
            return true
        }
        isWatchingCams = true
        if await perform("cam_watch", ["on": true]) { return true }
        isWatchingCams = false
        return false
    }

    private func updateLocalTracking() {
        guard let state else { return }
        localTrackingOn = (liveMapOpen && state.phase != .GAME_OVER)
            || LocalMapTracking.isEnabled(phase: state.phase, sharing: state.settings.livePositions == true)
        if localTrackingOn {
            location.start()
            positions.start()
        } else {
            positions.stop()
        }
        updateARTracking()
        updateCameraStream()
    }

    /// Testing: put this phone at the red button now (as the game's start does).
    func startAtRedButton() {
        guard let button = state?.stations.first(where: { $0.kind == .emergency }),
              let lat = button.lat, let lng = button.lng else { return }
        positions.fix(lat: lat, lng: lng, name: "Red button (manual)", buildingId: button.buildingId,
                      floorId: button.floorId, accuracyM: PositionEstimator.startFixM)
    }

    /// AR position mode runs the back camera whenever the map is tracking, except while another camera
    /// view (sign scanning) needs it: a phone can't run both. The security-camera stream doesn't stop it:
    /// in AR mode that stream is ARKit's own picture.
    private func updateARTracking() {
        guard arRuns else { arTracker.stop(); return }
        if CameraUsage.backCameraInUse {
            arTracker.stop(reason: "camera in use (scanning)")
        } else {
            arTracker.start()
        }
    }

    /// Not in the lobby (unless the live map is open): that's where everyone photographs signs, and the
    /// camera going back and forth between ARKit and the sign camera is what's risky.
    private var arRuns: Bool {
        positionMode == .ar && localTrackingOn && ARPositionTracker.isSupported && (state?.phase != .LOBBY || liveMapOpen)
    }

    private enum CameraSource { case front, ar }
    @ObservationIgnored private var cameraSource: CameraSource?

    /// Sends this phone's camera while someone is watching, except while the back camera is busy (scanning
    /// a sign). In AR mode that's what ARKit sees (the back camera), so tracking carries on; otherwise
    /// the front camera.
    private func updateCameraStream() {
        let wanted = state?.phase == .PLAYING && state?.me.camWanted == true && isSynced && !CameraUsage.backCameraInUse
        let source: CameraSource? = wanted ? (arRuns ? .ar : .front) : nil
        guard source != cameraSource else { return }
        cameraSource = source
        isStreamingCamera = source != nil
        if source != .front { frontCamera.stop() }
        arTracker.streamCamera(to: source == .ar ? { [weak self] jpeg in
            Task { @MainActor in self?.sendCameraFrame(jpeg) }
        } : nil)
        if source == .front {
            frontCamera.start { [weak self] jpeg in
                Task { @MainActor in self?.sendCameraFrame(jpeg) }
            }
        }
    }

    private func sendCameraFrame(_ jpeg: String) {
        guard isStreamingCamera, let socket, isSynced,
              let data = try? JSONSerialization.data(withJSONObject: ["id": 0, "action": "cam_frame", "payload": ["jpeg": jpeg]])
        else { return }
        socket.send(.string(String(decoding: data, as: UTF8.self))) { _ in }
    }

    /// Loads the signs' reference photos for recognition (already processed photos are reused).
    func prepareSigns() {
        guard let base = serverURL, let stations = state?.stations else { return }
        Task.detached { [signs] in await signs.prepare(stations: stations, serverURL: base) }
    }

    func checkIn(stationId: String, method: String) async -> Bool {
        var payload: [String: Any] = ["stationId": stationId, "method": method]
        if method == "gps", let loc = location.location {
            payload["lat"] = loc.coordinate.latitude
            payload["lng"] = loc.coordinate.longitude
        }
        let ok = await perform("checkpoint", payload)
        if ok { Haptics.success() }
        return ok
    }

    /// Player QR fallback (host-enabled): impostors try a kill first, everyone else reports a body.
    func handlePlayerQR(_ qrToken: String) async {
        if state?.me.role == .impostor, state?.me.alive == true,
           (try? await send("kill", ["method": "qr", "qrToken": qrToken])) != nil {
            return
        }
        await perform("report_body", ["method": "qr", "qrToken": qrToken])
    }

    private func failPending(_ error: Error) {
        let waiting = pending
        pending = [:]
        waiting.values.forEach { $0.resume(throwing: error) }
    }

    /// Streams BLE sightings to the server once a second during active play.
    private func startProximityReporting() {
        proximityTask?.cancel()
        proximityTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, let socket = self.socket, self.isSynced,
                      let phase = self.state?.phase, phase != .GAME_OVER,
                      phase != .LOBBY || self.livePositionsOn else { continue }
                let sightings = self.ble.freshSightings().map { ["token": $0.token, "rssi": $0.rssi] }
                guard !sightings.isEmpty,
                      let data = try? JSONSerialization.data(withJSONObject: ["id": 0, "action": "proximity", "payload": ["sightings": sightings]])
                else { continue }
                socket.send(.string(String(decoding: data, as: UTF8.self))) { _ in }
            }
        }
    }

    /// Sends this phone's estimate every 2 seconds during play (the Admin map counts rooms from them; only
    /// room counts reach other players) and whenever live positions (testing) are on.
    private func startPositionReporting() {
        positionTask?.cancel()
        positionTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, let socket = self.socket, self.isSynced,
                      self.livePositionsOn || self.state?.phase == .PLAYING,
                      let e = self.positions.estimate else { continue }
                var payload: [String: Any] = ["lat": e.lat, "lng": e.lng, "accuracyM": e.accuracyM,
                                              "levelDelta": e.levelDelta, "sources": e.sources]
                if let roomId = e.roomId { payload["roomId"] = roomId }
                if let room = e.room { payload["room"] = room }
                if let buildingId = e.buildingId { payload["buildingId"] = buildingId }
                if let floorId = e.floorId { payload["floorId"] = floorId }
                guard let data = try? JSONSerialization.data(withJSONObject: ["id": 0, "action": "position", "payload": payload])
                else { continue }
                socket.send(.string(String(decoding: data, as: UTF8.self))) { _ in }
            }
        }
    }
}

enum ClientError: LocalizedError {
    case server(String)
    var errorDescription: String? {
        switch self { case let .server(message): return message }
    }
}

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let scale = min(1, maxDimension / max(size.width, size.height))
        guard scale < 1 else { return self }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
