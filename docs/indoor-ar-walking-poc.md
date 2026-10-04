# Indoor walking POC

Shake the phone to open Developer Mode, then choose **Indoor AR walking POC**.
The **Floor task** mode keeps the original one-task walking experiment. **Preset
map** adds a saved measured layout and marker-aligned task beacons. Both are local
experiments; neither sends locations nor authorizes online game tasks.

## Preset map: prepare the space

1. Open **Preset map → Map setup**. The POC map covers 12 × 12 metres; grid lines
   are two metres apart. Its origin is the floor directly below the alignment marker.
   Right means right when facing the upright marker; away extends from its wall into
   the room. These are measured local coordinates, not GPS coordinates.
2. Select Electrical, Reactor or Medbay, then tap the map to move its pin (0.25 m
   increments). Use the Right/Away fields for exact measured offsets. Sample positions
   are Electrical (0, 3), Reactor (−3, 6), and Medbay (3, 8) metres.
3. **Save map** persists the three task positions and marker measurements on this
   device. Editing and saving the map clears alignment and requires another scan.
4. Print [the alignment marker](ar-alignment/print-marker-20cm.pdf) at **Actual Size /
   100%**. The entire square, including its outer black border, must measure **20 cm wide**.
   Map setup also provides **Print / share ALIGN marker** for AirPrint or sharing.
5. Mount it upright, flat, and stationary on a vertical wall. The arrow and “THIS SIDE
   UP” must point up. Measure the printed image's centre height above the floor and
   enter **Centre height** in Map setup (default 1.2 m). If the printed width differs
   from 20 cm, enter the measured width too. Do not move the marker during the test.

## Scan and walk

Point the rear camera at the entire marker. When normal tracking detects it,
**Align map** becomes available. Tap it. Its measured height locates the floor, its
horizontal direction aligns map-right, and all three task positions become beacons
in the same AR world space. There is no need to place tasks again on the camera view.

Beacons have a floor ring, a vertical stem, a floating orb and a task label. Yellow
marks the selected task, cyan marks the other tasks, and green marks completed tasks.
Choose a task from the task menu; the minimap and interaction distance refer to that
same task. The map shows your camera-derived position in pink.

Approach the task and remain within **two horizontal metres** at a measured speed
at or below **0.35 m/s for 0.5 seconds**. Then tap **Use → Complete task**. Passing
through while moving never unlocks it. Completion is local and remains set when
rescanning the marker. **Reset** clears completion and alignment but preserves the
saved measured layout.

To correct drift, point at the fixed marker again and tap **Rescan**. It replaces the
map-to-AR transform and clears the current interaction dwell. It does not silently
move task pins or discard completed tasks.

Limited or missing tracking hides the beacons, holds the last minimap position, and
disables interaction. Normal tracking recovery requires a fresh dwell. Camera/app
interruptions require reset and a new marker scan. Frame gaps over 0.35 seconds clear
dwell; absence of frames for 0.5 seconds pauses the UI. Implausible pose changes over
8 m/s require reset.

## Test accuracy before integrating

Use tape marks at the task's measured position and at known distances along a route.
Check whether each beacon sits over its physical mark while walking toward it, away
from it and around it. Walk a loop and return to a known mark; compare the displayed
map coordinates. Test turns, lighting, brisk motion, temporary camera obstruction,
and rescanning. Record observed error and tracking failures. Automated tests validate
transforms and UX, not physical image detection or venue accuracy.

**Simulation** offers synthetic marker alignment and movement to try setup, saved
pins, task selection, completion, running past and recovery without a camera. It is
explicitly labelled and does not establish AR accuracy.

## Limits

- This is a measured local grid, not the campus floor plan. Campus alignment requires
  a trusted map scale, marker pose and task coordinates in that same map.
- One upright marker establishes the current session's origin. There is no persisted
  AR world map, multi-device shared session or automatic correction across a venue.
- All tasks must be on the same floor in a clear space. Walls/rooms are not modeled;
  beacons can render through walls and proximity cannot authorize cross-wall tasks.
- Printed scale, mounting orientation, centre height, map measurements and tracking
  drift all affect accuracy. Phone movement includes hand movement; thresholds need
  physical testing and tuning.
- Online sign/checkpoint validation remains unchanged.

Regenerate the reference PNG and exact-size PDF with
`swift scripts/generate-ar-alignment-marker.swift` from the repository root.

Apple references: [image detection](https://developer.apple.com/documentation/arkit/detecting-images-in-an-ar-experience),
[world tracking](https://developer.apple.com/documentation/arkit/arworldtrackingconfiguration),
[camera tracking state](https://developer.apple.com/documentation/arkit/arcamera/trackingstate-swift.enum).
