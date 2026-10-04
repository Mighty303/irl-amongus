# UI sprite attribution

The UI image assets added under `IRLAmongUs/Assets.xcassets` were extracted
without redrawing from the supplied sprite sheet:

- **Sheet:** PC / Computer - Among Us - Miscellaneous - Buttons & Menu Elements
- **Sheet credit:** Ripped by LukeWarnut
- **Reference:** https://www.spriters-resource.com/pc_computer/amongus/

Among Us and its original artwork belong to their respective rights holders.
Use and redistribution remain subject to the applicable source and game-asset
terms.

## Role reveal

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
