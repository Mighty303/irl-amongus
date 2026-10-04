# Player faces on character sprites

The server's `PlayerView.id` identifies a character; `faceId` identifies their uploaded cut-out photo.
Map dots, voting cards, role and result lineups, ejection, security-camera labels, the AR POC and lobby
all carry that character's face along with their suit color. Reordering a lineup does not reorder the faces.
The Shhh intro uses its layered source artwork for a character with a photo, preserving the 2.5-second reveal timing.
Demo lineups use the selected local face only on their explicitly labeled “You” character.

Kill presentations capture the victim's face and server URL, and resolve a late attacker event by player ID.
The emergency banner uses the caller's face. The separate animation windows receive their face URLs in the
presentation, so they do not depend on a SwiftUI game-store environment inherited from another window.
Uploaded faces are cached by complete URL and prefetched for the roster. Missing or failed photos leave
the original visor visible; they never fall back to somebody else's face.

Neck-kill head positions come from the visible visor components in the exact 47 source frames. Run
`python3 scripts/generate-neck-kill-face-placements.py` (Pillow required) after changing those frames.
Positions use source pixels and scale with the same aspect fit as the animation. The victim's photo hides
when the helmet turns away. A reported torso has no head to display a photo on.

Tests cover duplicate suit colors, lineup filtering/reordering, late attacker identity, removed photos,
identical face IDs on different servers, and frame-to-head-position coverage. Existing UI tests cover
role reveal, voting, neck kill, emergency meeting, ejection and the result screens.
