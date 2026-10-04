# Map data attribution

The bundled Student Union Building level 2 room geometry is an extracted subset of [SFU Companion](https://gitlab.com/HolyChicken99/sfu-companion), created by Akki Singh (`@HolyChicken99`). It is based on room data published through Simon Fraser University's ArcGIS services.

- Upstream snapshot: `ef4a47a8d564033d5b9cdd76b621f86f5bdb3e55`
- Building: Student Union Building (`SUB`)
- Floor: level 2 (`floorId` `2000`)
- Bundled file: `IRLAmongUs/Assets.xcassets/SUBLevel2Map.dataset/SUB-Level2.geojson`
- Scope: room and corridor polygons plus room metadata; no routing or live-position data

The project maintainer confirmed permission from the SFU Companion owner to use this data for the POC. SFU Companion is an independent student project and is not an official Simon Fraser University application. SFU names and data remain the property of their respective owners.

## Room map colors

The indoor maps use the room palette and room-type classification adapted from
[SFU Companion's mobile RoomFinderScreen](https://gitlab.com/HolyChicken99/sfu-companion/-/blob/b458870/screens/RoomFinderScreen.tsx),
snapshot `b458870`. Source code is copyright (c) 2026 TCombinator, MIT licensed;
the license is retained in `licenses/SFU-Companion-MIT.txt`.

Teaching rooms are blue, student amenities pink, washrooms green, general rooms slate,
and corridors dark. Selection uses pale yellow. Adaptations share the palette across
SwiftUI floor maps, use contrasting label text, and retain gameplay fog, task/player
markers and the admin occupancy tint. Campus 3D models and textures are not bundled.
