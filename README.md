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
