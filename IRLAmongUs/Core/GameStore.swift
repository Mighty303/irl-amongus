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
    /// serverTime - localTime, in ms
    private(set) var clockOffset: Double = 0
    var signThreshold: Float { didSet { preferences.set(signThreshold, forKey: "signThreshold") } }

    let ble = BLEProximity()
    let location = LocationService()
    let signs = SignRecognizer()

    @ObservationIgnored private let killAudio = KillAudioPlayer()
    @ObservationIgnored private var deathSound = DeathSoundState()
    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private let httpSession: URLSession
    @ObservationIgnored private var socket: URLSessionWebSocketTask?
    @ObservationIgnored private var pending: [Int: CheckedContinuation<Void, Error>] = [:]
    @ObservationIgnored private var nextRequestId = 1
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var proximityTask: Task<Void, Never>?
    @ObservationIgnored private var reconnectAttempt = 0

    init(defaults: UserDefaults = .standard, httpSession: URLSession = .shared, restoresSession: Bool = true) {
        self.preferences = defaults
        self.httpSession = httpSession
        // Saved addresses from local testing (Cloudflare quick tunnels, the old LAN placeholder) are dead;
        // move them to the hosted server. Any other saved address (e.g. a laptop on purpose) is kept.
        let saved = defaults.string(forKey: "serverURL")
        let isStale = saved.map { $0.contains("trycloudflare.com") || $0 == "http://192.168.1.100:3000" } ?? true
        serverURLString = isStale ? Self.defaultServerURL : saved!
        playerName = defaults.string(forKey: "playerName") ?? ""
        signThreshold = defaults.object(forKey: "signThreshold") as? Float ?? 0.6
        if restoresSession, let data = defaults.data(forKey: "session") {
            session = try? JSONDecoder().decode(Session.self, from: data)
        }
        if session != nil { connect() }
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
        await enterLobby(path: "games", body: ["name": playerName, "mapId": "default"])
    }

    func joinGame(code: String) async {
        guard Self.isValidRoomCode(code) else { errorMessage = "Enter a four-character room code."; return }
        let code = Self.normalizedRoomCode(code)
        await enterLobby(path: "games/\(code)/join", body: ["name": playerName])
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

    func uploadPhoto(_ image: UIImage) async throws -> String {
        guard let base = serverURL else { throw ClientError.server("Invalid server URL") }
        let jpeg = image.resized(maxDimension: 800).jpegData(compressionQuality: 0.8) ?? Data()
        let response = try await postJSON(base.appendingPathComponent("photos"), body: ["jpegBase64": jpeg.base64EncodedString()])
        guard let id = response["photoId"] as? String else { throw ClientError.server("Upload failed") }
        return id
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
        disconnect()
        alert = nil
        killAudio.stop()
        deathSound = DeathSoundState()
        session = nil
        state = nil
        ble.stop()
        location.stop()
    }

    // MARK: - WebSocket

    func connect() {
        guard let session, let base = serverURL,
              var comps = URLComponents(url: base.appendingPathComponent("ws"), resolvingAgainstBaseURL: false) else { return }
        comps.scheme = base.scheme == "https" ? "wss" : "ws"
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
    }

    func disconnect() {
        reconnectTask?.cancel()
        proximityTask?.cancel()
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        connection = .disconnected
        isSynced = false
        failPending(ClientError.server("Disconnected"))
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
        default:
            break
        }
    }

    private func apply(_ newState: GameState) {
        let old = state
        clockOffset = newState.serverTime - Date().timeIntervalSince1970 * 1000
        state = newState
        if deathSound.update(wasAlive: old?.me.alive, isAlive: newState.me.alive, isBody: newState.me.isBody) {
            killAudio.play(.victim)
        }
        connection = .connected
        isSynced = true
        reconnectAttempt = 0

        if newState.phase == .LOBBY || newState.phase == .GAME_OVER {
            ble.stop()
        } else {
            ble.start(token: newState.me.bleToken)
        }
        location.start()

        if old?.stations != newState.stations, let base = serverURL {
            let stations = newState.stations
            Task.detached { [signs] in await signs.prepare(stations: stations, serverURL: base) }
        }
        // Discreet buzz when a kill target first comes into range.
        if newState.me.role == .impostor, old?.me.killTargets.isEmpty ?? true, !newState.me.killTargets.isEmpty {
            Haptics.killInRange()
        }
        if old?.me.nearbyBodies.isEmpty ?? true, !newState.me.nearbyBodies.isEmpty {
            Haptics.heavy()
        }
    }

    private func handleEvent(_ event: String, data: [String: Any]) {
        switch event {
        case "ROLE_ASSIGNED":
            Haptics.heavy()
        case "PLAYER_KILLED":
            if deathSound.killed(victimID: data["victimId"] as? String, localID: session?.playerId) {
                killAudio.play(.victim)
            }
            if data["victimId"] as? String == session?.playerId { Haptics.alarm(times: 2) } else { Haptics.success() }
        case "BODY_REPORTED":
            let body = data["bodyName"] as? String
            alert = Alert(title: "🚨 BODY REPORTED", subtitle: "\(body.map { "\($0)'s body was found. " } ?? "")Return to the meeting area.", color: .red)
            Haptics.alarm()
        case "EMERGENCY_MEETING":
            alert = Alert(title: "🚨 EMERGENCY MEETING", subtitle: "\(data["callerName"] as? String ?? "Someone") pressed the button. Return to the meeting area.", color: .red)
            Haptics.alarm()
        case "VOTING_STARTED":
            Haptics.heavy()
        case "SABOTAGE_STARTED":
            let kind = data["kind"] as? String
            alert = Alert(title: kind == "reactor" ? "☢️ REACTOR MELTDOWN" : "💡 LIGHTS SABOTAGED",
                          subtitle: kind == "reactor" ? "Two people must activate both reactor stations!" : "Fix the lights at Electrical.",
                          color: .orange)
            Haptics.alarm(times: 2)
        case "SABOTAGE_RESOLVED":
            Haptics.success()
        case "CREWMATES_WIN", "IMPOSTORS_WIN":
            Haptics.alarm(times: 1)
        case "KICKED":
            errorMessage = "You were removed from the lobby."
            leave()
        default:
            break
        }
    }

    // MARK: - Actions

    /// Sends an action and waits for the server's ack. Throws the server's rejection reason.
    func send(_ action: String, _ payload: [String: Any] = [:]) async throws {
        guard let socket, isSynced else { throw ClientError.server("Not connected. Reconnecting…") }
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
        if action == "kill" { killAudio.play(.killer) }
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
                      let phase = self.state?.phase, phase != .LOBBY, phase != .GAME_OVER else { continue }
                let sightings = self.ble.freshSightings().map { ["token": $0.token, "rssi": $0.rssi] }
                guard !sightings.isEmpty,
                      let data = try? JSONSerialization.data(withJSONObject: ["id": 0, "action": "proximity", "payload": ["sightings": sightings]])
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
