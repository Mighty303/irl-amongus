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

In a Debug build, shake the phone (Simulator: Device → Shake) and choose **Open Voting POC**.
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

1. Start the server: clone the backend repo, then `npm install && npm start`. On campus Wi-Fi or behind a VPN, use `cloudflared tunnel --url http://localhost:3000`.
2. Open `IRLAmongUs.xcodeproj`, set your signing team, and run on each iPhone.
3. The app opens on the main menu. **Shake the phone** (Debug builds) to open Developer Mode and choose **Online game (server POC)**: enter the server URL (the scheme is optional; `https://` is assumed), a name, and **Create game**. Other phones scan the lobby QR (it carries the server URL too) or type the code.

Testing with one phone: in the backend repo, `npm run bots -- <CODE> 3` fills the lobby with bots. In the lobby host settings, the `DEV:` toggles skip BLE and checkpoint checks for simulator testing.

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
| BLE proximity kills | Phones advertise a per-game random token and stream RSSI sightings. The **server** decides who's in kill / report range (either direction, freshness window, host-tunable dBm thresholds) | `Device/BLEProximity.swift`, `Game.isNear` |
| Bodies & reporting | Victim's phone becomes a red BODY screen and keeps advertising; nearby living players get REPORT. REPORT also works on the body phone itself | `Screens/BodyView.swift` |
| Signage checkpoints | Host photographs signs + tags GPS. Players prove presence by pointing the camera at the sign (Vision feature print + optional OCR text), with a QR fallback or server-validated GPS geofence | `Device/SignRecognizer.swift`, `Screens/CheckpointScannerView.swift` |
| Tasks | Wiring, Upload (server enforces on-site duration), Sequence, Delivery (two stations in order). Impostors get fake tasks that never move the bar | `Screens/TaskViews.swift` |
| Meetings / voting | Body report or emergency button station; gather check-in at the meeting point; discussion → hidden voting → tally, ties, skip, optional role reveal | `Screens/MeetingView.swift` |
| Sabotage | Reactor (two stations within 10s, timer → impostors win) and Lights (crew screens dim until Electrical) | `PlayingView.swift` |
| Win conditions | Tasks complete, impostors ejected, impostors ≥ crew, reactor meltdown | `Game.checkWin` |
| Mini-map | MapKit with GPS-tagged station pins, your task pins, meeting point and your own location only | `Screens/MiniMapView.swift` |
| Haptics / alerts | Full-screen alerts plus vibration for body reported, emergency and sabotage; subtle buzz when a kill target enters range | `Device/Haptics.swift` |

### Things to validate on real phones

1. **BLE RSSI threshold.** In a game, open *Diagnostics* on two phones, hold them at "kill distance", note the smoothed dBm, and set the host's *Kill RSSI ≥* just below it. Default is -65.
2. **Sign recognition threshold.** In the station scanner, turn on *Show distances* and compare the right sign with wrong signs and surroundings, then tune the slider. Entering the sign's text on the station makes OCR match too, which is often more reliable.
3. **Indoor GPS** will be rough. Treat it as a map aid, not proof of presence.

### Not in the POC yet

the game's mini-map still uses MapKit (the SFU SUB floor plan from the Physical Map POC should replace it), security logs, comms sabotage, horizontal scaling (one server instance holds all live games), and polished UI.
