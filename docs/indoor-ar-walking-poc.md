# Indoor walking POC

Open Developer Mode by shaking the phone, then choose **Indoor AR walking POC**.
This is a separate local experiment. It does not send locations, authorize online
tasks, or change the game's existing position estimator.

## Physical walking test

1. Use a physical ARKit-capable iPhone or iPad with camera permission enabled.
2. In a well-lit, clear room, slowly point the camera toward a textured floor until
   **Place task here** becomes available. Aim at a floor point and tap it.
3. A yellow ring marks the task. The local map uses a two-metre grid; the white
   circle marks your starting position, cyan marks you, and yellow marks the task.
4. Walk toward the task. **Use** becomes available after remaining within two
   horizontal metres at a measured speed at or below 0.35 m/s for 0.5 seconds.
   Passing through the radius while moving does not enable it.
5. Tap **Use**, then **Complete task**. This is a local test action, not a game task.
6. Reset to try another route. Camera interruptions or leaving the app require
   fresh task placement; old coordinates never transfer into a reset AR session.

Limited or missing camera tracking freezes the last map position and disables
interaction. Normal tracking recovery requires a new continuous dwell. Frame gaps
above 0.35 seconds reset dwell; absence of frames for 0.5 seconds pauses the UI.
An implausible pose change above 8 m/s requires reset and fresh task placement.

## Measure before expanding

Use tape marks at known distances (for example 0, 2, 4 and 8 metres) and compare the
displayed distance while walking toward/away from the task. Walk a loop and return
to the start: **From start** should return close to zero. Record the observed error,
whether the marker stays fixed, and where tracking fails. Try turns, different
lighting, faster movement and brief camera obstruction. Test brisk movement in a
clear area before testing running. Automated tests cannot establish venue accuracy.

**Simulation** supplies explicitly labelled synthetic movement for trying the UI
without a camera. Place a task, Run past, Walk toward, Stop, Lose tracking/Recover,
and complete it. Simulation does not measure AR accuracy.

## Limits of this first experiment

- Relative coordinates are valid only within the current AR session. There is no
  sign alignment, persisted world map, campus floor-plan alignment or shared origin.
- Horizontal planes are detected, but rooms/walls/floors are not identified.
  Place the task on the floor in the same unobstructed room as the player.
- Camera speed measures phone movement, including hand movement. The stop threshold
  and interaction radius are starting values to tune after physical measurements.
- There is one task, no server connection, multiplayer proximity, or real task
  authorization. Online sign/checkpoint validation remains unchanged.

Next steps depend on the walking results: align known visual markers to the venue
map, validate recovery against those markers, enforce room boundaries, then integrate
with game tasks and the server's existing checkpoint rules.

Apple references: [world tracking configuration](https://developer.apple.com/documentation/arkit/arworldtrackingconfiguration),
[camera tracking state](https://developer.apple.com/documentation/arkit/arcamera/trackingstate-swift.enum).
