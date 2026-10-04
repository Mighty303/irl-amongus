# IRL Among Us

A native iOS starter project built with SwiftUI.

## Requirements

- Xcode 16 or newer
- iOS 17 or newer

## Getting started

Open `IRLAmongUs.xcodeproj` in Xcode, select an iPhone simulator, and press Run.

From the command line, you can inspect available schemes and destinations with:

```sh
xcodebuild -project IRLAmongUs.xcodeproj -scheme IRLAmongUs -showdestinations
```

## Voting proof of concept

In a Debug build, shake the phone (Simulator: Device → Shake) and choose **Open Voting**.
The Map POC opens in portrait for walking with the phone, with the map above checkpoint and task details. The main menu, developer menu, and voting demo use landscape; closing the map restores landscape. It contains ten mock players, including you as Ben and one dead player.
Select a living player or Skip Vote, then confirm with the green checkmark or cancel with the red cross.
Your confirmed vote is final. Bots vote over time, and the 60-second deadline continues while the app is in the background.
Results reveal colored vote markers and totals; Play Again starts a fresh round.

The bot schedule is repeatable: three votes for Dale, three for Lars, and two skips.
Voting for Dale or Lars ejects that player; skipping, abstaining, or voting for another player produces a tie.
No network connection, lobby, discussion phase, or live multiplayer is required.

For UI automation, `-showDeveloperMenu -disableAudio` opens the menu silently.
Debug builds also accept `-votingTestDuration <seconds>` (1–60) to shorten test rounds.

Previews: [Map (portrait)](docs/map-portrait.png), [Main menu](docs/main-menu-landscape.png), [Voting](docs/voting-landscape.png), [Selection](docs/voting-selection.png), [Results](docs/voting-results.png).

Voting artwork is extracted from the user-supplied **Among Us — Voting Screen / Chat** sprite sheet (sheet credit: JJ314).
The tablet, glass, player cards, stamps, reporter icon, dead-player cross, and confirm/cancel controls use those sprites. Menu buttons, account/settings icons, skip, close, and replay reuse the shared assets from main (see [sprite attribution](SPRITE_ASSET_ATTRIBUTION.md)).
Crewmate suit colors are derived from the supplied red icon while retaining its visor and shading.
To regenerate the assets, run `python3 scripts/extract-voting-assets.py /path/to/sprite-sheet.png` from the repository root (requires ImageMagick).

## Online multiplayer POC (server)

The networked game: real roles, BLE proximity kills, sign check-ins, meetings and voting across phones, with the authoritative game server in its own repo: **[kaisamson/amongus-irl-backend](https://github.com/kaisamson/amongus-irl-backend)** (Node/TypeScript, deployed on Render with Redis).

### Requirements

- Xcode 16 or newer, iOS 17+ iPhones (BLE and camera need **physical devices**; the simulator has neither)
- A running game server (see the backend repo)

### Run it

1. Open `IRLAmongUs.xcodeproj`, set your signing team, and run on each iPhone.
2. The app opens on the main menu. **Shake the phone** (Debug builds) to open Developer Mode and choose **Online game (server POC)**, enter a name and **Create game**. Other phones scan the lobby QR or type the code.
3. The app uses the hosted server, **https://irl-amongus-server.onrender.com** (Render + Redis), by default. To run your own instead, clone the backend repo, `npm install && npm start`, and launch the app with the `-serverURL http://<your-server>` argument (Xcode: Product → Scheme → Edit Scheme → Arguments). On campus Wi-Fi or behind a VPN, use `cloudflared tunnel --url http://localhost:3000`.

Testing with one phone: in the backend repo, `npm run bots -- <CODE> 3` fills the lobby with bots. In the lobby host settings, the `DEV:` toggles skip BLE and checkpoint checks for simulator testing.

### Test lab (no server needed)

Developer Mode (shake) also has test benches for each device component:
- **Sign recognition test**: capture reference photos, then point the camera around to see live match distances, OCR text and per-frame timing.
- **Bluetooth proximity test**: run on two iPhones; shows each phone's token, live RSSI and estimated distance, an "in kill range" indicator for a range in meters, and 1 m calibration you can apply to your lobby.
- **GPS, QR, haptics & mini-games**: GPS (fix accuracy, indoor floor, pins with live distance and inside/outside geofence), QR scanner/generator, haptics, the task mini-games and a body-screen preview.

### Server

Hosting, storage (Redis), live-game restore and the WebSocket protocol are documented in the
[backend repo](https://github.com/kaisamson/amongus-irl-backend). File references in the table below that start with
`server/` live there (without the prefix).

### What's in the POC

| PRD area | How it works | Where |
| --- | --- | --- |
| Authoritative state machine | `LOBBY → ROLE_REVEAL → PLAYING → MEETING (gathering → discussion) → VOTING → RESULT → PLAYING / GAME_OVER`; every action is phase-checked | `server/src/game.ts` |
| Hidden information | Each player gets their own redacted snapshot: no other roles, no unreported deaths, no locations, no "who did which task" | `Game.viewFor` |
| Real-time sync / reconnect | WebSocket pushes full snapshots + events. On foreground the app reconnects, and actions stay disabled until a fresh snapshot arrives | `Core/GameStore.swift` |
| BLE proximity kills | Phones advertise a per-game random token and stream RSSI sightings. The **server** decides who's in kill / report range (either direction, freshness window); the host sets the range in meters, converted to RSSI with a log-distance model | `Device/BLEProximity.swift`, `Game.isNear` |
| Bodies & reporting | Victim's phone becomes a red BODY screen and keeps advertising; nearby living players get REPORT. REPORT also works on the body phone itself | `Screens/BodyView.swift` |
| Signage checkpoints | Host photographs signs + tags GPS; a sign is just a place. Players are guided by the sign's photo, distance and a compass arrow, then prove presence by pointing the camera at it (Vision feature print + optional OCR text), with a QR fallback or server-validated GPS geofence | `Device/SignRecognizer.swift`, `Screens/SignGuide.swift`, `Screens/CheckpointScannerView.swift` |
| Tasks | Each game assigns every player random signs, each with a random mini-game from the host's rotation: Wiring, Upload (server enforces on-site duration), Sequence, Delivery (carry to a second sign). Impostors get fake tasks that never move the bar | `Screens/TaskViews.swift` |
| Host tuning | Force a specific impostor (testing), every timer, mini-games in rotation, kill/report range in approximate meters with 1 m calibration | `Screens/LobbyView.swift` |
| Meetings / voting | Body report or emergency button station; gather check-in at the meeting point; discussion → hidden voting → tally, ties, skip, optional role reveal | `Screens/MeetingView.swift` |
| Sabotage | Reactor (two stations within 10s, timer → impostors win) and Lights (crew screens dim until Electrical) | `PlayingView.swift` |
| Win conditions | Tasks complete, impostors ejected, impostors ≥ crew, reactor meltdown | `Game.checkWin` |
| Mini-map | MapKit with GPS-tagged station pins, your task pins, meeting point and your own location only | `Screens/MiniMapView.swift` |
| Haptics / alerts | Full-screen alerts plus vibration for body reported, emergency and sabotage; subtle buzz when a kill target enters range | `Device/Haptics.swift` |

### Things to validate on real phones

1. **Bluetooth range.** On two phones, open the **Bluetooth proximity test**, hold them 1 m apart and tap *Set 1 m from the closest phone*, then walk apart and check the distance estimates (raise the indoor factor if they read too close). As host, *Apply to my lobby*, then pick the kill/report distance in meters in the lobby.
2. **Sign recognition threshold.** In the **Sign recognition test**, capture a few signs and compare the distance on the right sign with other signs and surroundings, then tune the slider (the game's scanner has the same slider). Entering the sign's text on the station makes OCR match too, which is often more reliable.
3. **Indoor GPS** will be rough. Treat it as a map aid, not proof of presence.

### Not in the POC yet

the game's mini-map still uses MapKit (the SFU SUB floor plan from the Physical Map POC should replace it), security logs, comms sabotage, horizontal scaling (one server instance holds all live games), and polished UI.

## Role reveal POC

Shake the phone to open Developer Mode, then choose **Open Role Reveal**. Choose **Crewmate** or **Impostor** to play the bundled Shhh intro followed by the role screen. The role remains visible for three seconds, then opens the portrait Map automatically. The reveal has no exit or replay controls. This preview uses landscape and runs offline. It does not assign roles or contact the game server.

Asset sources are recorded in [sprite attribution](SPRITE_ASSET_ATTRIBUTION.md).

Original artwork previews (before the automatic map transition): [Shhh](docs/role-shhh.png), [Crewmate](docs/role-crewmate.png), [Impostor](docs/role-impostor.png).

## LOCAL server lobby

Open **LOCAL**, enter your display name and the POC server address, then choose
**Classic** to create a room. Other phones use the same address and enter the
four-character room code, or scan the host's **Share lobby QR**. Join links from
the system camera also open LOCAL with the room code filled in.

The landscape waiting room shows the server's room code and live player roster.
The host can **Add bot**, open **SETTINGS** to configure rules and venue signs,
and press **START** once the configured minimum player count is reached. Start
and all settings changes are validated by the server. Gameplay uses the existing
portrait server POC screens; returning to the lobby restores landscape.

Saved sessions resume in LOCAL when the app launches. During reconnects, actions
pause until a fresh snapshot arrives, and **Leave Game** remains available.
A running POC server is required. Nearby discovery and Hide n Seek are not yet
implemented.

To replay the LOCAL lobby UI smoke test, run `python3 scripts/test-local-lobby-server.py`
in one terminal, then run:

```sh
TEST_RUNNER_LOCAL_LOBBY_TEST_SERVER=http://127.0.0.1:39872 xcodebuild \
  -project IRLAmongUs.xcodeproj -scheme IRLAmongUs \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -parallel-testing-enabled NO \
  -only-testing:IRLAmongUsUITests/IRLAmongUsUITests/testLocalServerLobbyStartsAuthoritativeGame test
```

This fixture verifies client requests and screen transitions. It does not verify
the backend's game rules or physical-device BLE/camera behavior.

The Map shows the original Kill action sprite only for impostors. In a live game, it uses available targets and cooldowns from the server and plays `among-us-kill.mp3` on the killer’s device after a successful kill. The victim’s device plays `among-us-killed.mp3` when it receives the kill event or death state, once per death. QR kills use the same audio behavior. Host lobbies initialize the kill cooldown to 10 seconds for playtesting; the host can adjust it afterward. The standalone impostor preview plays the same sound and starts a 10-second local cooldown.
