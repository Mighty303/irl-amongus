# UI sprite attribution

## Body report

`BodyReportStreak`, `BodyReportLettering`, `BodyReportCorpse` and `BodyReportSkull`
are unchanged crops from [BeforeVoting-sharedassets0.assets-196.png](https://github.com/AlvajoyAsante/among-us-assets/blob/main/Voting/BeforeVoting-sharedassets0.assets-196.png).
Playback recolours the corpse suit to the reported player's lobby palette and
maps the atlas's green visor channel to the silver visor. Regenerate the crops
with `python3 scripts/import-body-report-assets.py` (requires ImageMagick).
Among Us and its original artwork belong to Innersloth.

## Neck kill animation

`IRLAmongUs/Assets/KillAnimation/Neck_Kill.gif` is the original user-supplied
animation, retained byte-for-byte. Despite its filename, the file contains
animated WebP: 47 frames at 338×200, lasting 1.6 seconds.

`KillAnimation/NeckKillFrame*` assets are full composited frames extracted without
redrawing. `NeckKillMask*` assets identify the attacker (including hands) and
victim suit regions. Playback recolours those regions with the existing lobby
palette while retaining the source shading, background, visors and outlines.
Regenerate the assets from the repository root with
`swift scripts/import-neck-kill.swift` (requires ImageMagick).

Among Us and its original artwork belong to Innersloth. The supplied file does
not include source or licence metadata.

The UI image assets added under `IRLAmongUs/Assets.xcassets` were extracted
without redrawing from the supplied sprite sheet:

- **Sheet:** PC / Computer - Among Us - Miscellaneous - Buttons & Menu Elements
- **Sheet credit:** Ripped by LukeWarnut
- **Reference:** https://www.spriters-resource.com/pc_computer/amongus/

Among Us and its original artwork belong to their respective rights holders.
Use and redistribution remain subject to the applicable source and game-asset
terms.

## Role reveal

- Win screen backgrounds (`CrewmateWinBackground`, `ImpostorWinBackground`): user-supplied PNGs retained byte-for-byte, including their original pixel lettering and glow. The winning roster is drawn on top using the existing lobby suit sprites. The supplied files do not include source or licence metadata.

- Shhh sprite layers (`RoleShhhBackground`, `RoleShhhCrew`, `RoleShhhHand`, `RoleShhhText`): [AlvajoyAsante/among-us-assets — SHHHHH!](https://github.com/AlvajoyAsante/among-us-assets/tree/main/SHHHHH!). Original PNGs retained.
- Bundled intro video (`shhh-intro.mp4`): [user-supplied Tenor animation](https://tenor.com/view/among-us-shhhhhhh-imposter-shh-be-quiet-gif-19235492), posted by masoncarr2244. Downloaded from the linked page's MP4 rendition and played once locally without network access.
- Role lettering is drawn as bitmap glyphs in SwiftUI; colored glow is drawn in SwiftUI from the supplied screenshot references.

## Task mini-game sprites and sounds

The `Task*` assets under `IRLAmongUs/Assets.xcassets/Tasks` are imported
unchanged (sounds re-encoded to AAC) by `scripts/import-task-assets.py`:

- **Sprites:** PC / Computer - Among Us - Miscellaneous - Tasks, extracted by
  Schubert (https://github.com/schuberty) —
  https://www.spriters-resource.com/pc_computer/amongus/asset/141567/
- **Accept Diverted Power sprites:** `electricity_Receive_Bg` and
  `electricity_Receive_switch` from
  https://github.com/AlvajoyAsante/among-us-assets/tree/main/Tasks
- **Sounds:** PC / Computer - Among Us - Sound Effects - Task Panels and
  General Sounds, uploaded by imJJ —
  https://www.sounds-resource.com/pc_computer/amongus/

Among Us and its original artwork and audio belong to Innersloth. Use and
redistribution remain subject to the applicable source and game-asset terms.

## Lobby player sprite

`LobbyPlayer.imageset` is an unchanged crop of the standing crewmate frame
from the following user-supplied sprite sheet:

- **Sheet:** `Player-sharedassets0.assets-55.png`
- **Source:** https://github.com/AlvajoyAsante/among-us-assets/blob/main/Players/Player-sharedassets0.assets-55.png

The source repository does not declare a license. Among Us and its original
artwork belong to Innersloth; confirm the applicable permissions before
redistributing the extracted sprite.

The `LobbyPlayer<Color>.imageset` variants recolor only the suit pixels from
that crop while preserving its original silhouette, visor, outline, and floor
shadow. Regenerate them with `python3 scripts/generate-lobby-player-colors.py`.

- Role-reveal audio (`RoleRevealSound`): original `Roundstart_MAIN.wav` from [Among Us — General Sounds](https://sounds.spriters-resource.com/pc_computer/amongus/asset/431696/), uploaded by imJJ. Bundled without re-encoding.

## Emergency meeting

`EmergencyMeetingLettering`, `EmergencyMeetingTable`, `EmergencyMeetingHand`, `EmergencyMeetingCrewmate`
and `EmergencyButtonIcon` are unchanged crops (transparent edges trimmed, neighbouring sprites cleared)
from the same [BeforeVoting atlas](https://github.com/AlvajoyAsante/among-us-assets/blob/main/Voting/BeforeVoting-sharedassets0.assets-196.png)
as the body report. Playback recolours the crewmate and hand to the caller's suit. Regenerate with
`swift scripts/import-emergency-meeting-assets.swift`. Among Us and its original artwork belong to Innersloth.

## Game sounds

The `Sound*` data assets under `IRLAmongUs/Assets.xcassets/Sounds` (emergency alarm, sabotage alarm,
eject text, voting, panels, player leaving) are re-encoded to AAC by `scripts/import-game-sounds.py` from
the "General Sounds" and "Player" packs on https://www.sounds-resource.com/pc_computer/amongus/,
uploaded by imJJ. Among Us and its original audio belong to Innersloth.

## Sabotage panels

`SabotageReactorHand` and `SabotageReactorGlow` (reactor meltdown hand scanner, unchanged) and `SabotageKeypad`
and `SabotageKeypadNote` (O2 keypad and its sticky note, cropped from the KeypadGame atlas) come from the Tasks
folder of https://github.com/AlvajoyAsante/among-us-assets. Regenerate with
`swift scripts/import-sabotage-assets.swift`. Among Us and its original artwork belong to Innersloth.

## Map arrow and font

`MapArrow` is the arrow from the Gui folder of https://github.com/AlvajoyAsante/among-us-assets, unchanged and
tinted in the app. `FontVarelaRound` is Varela Round (https://fonts.google.com/specimen/Varela+Round, SIL Open
Font License), the rounded font Among Us's text uses. Both come from `swift scripts/import-sabotage-assets.swift`.
