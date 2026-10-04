The client plays the supplied neck-kill animation on confirmed direct/QR kills
and on the victim's death event or snapshot, once per victim per round. It uses
the same colours as lobby sprites.

The current backend's `PLAYER_KILLED` event includes only `victimId`. The companion
`kill-animation.patch` adds `killerId` to that existing private event and
`killedBy` to the requesting player's own `me` snapshot. This lets the victim's
device colour the attacker correctly, including when the snapshot arrives first.
The event remains restricted to its existing recipients (victim and impostors).

Apply the patch in `kaisamson/amongus-irl-backend` with:

```sh
git apply /path/to/irl-amongus/docs/backend/kill-animation.patch
npm test
```

Deploying that backend change is required for attacker colour matching on the
victim's device. Older servers remain compatible: victims use the source red
attacker and their own suit colour, while direct killers use both roster colours.
For old-server QR kills, the client uses the victim ID received during the
acknowledgement; if no unambiguous ID is available, it keeps the existing audio
behaviour without guessing another player's colour.

Offline preview: shake to open Developer Mode → GPS, QR, haptics & mini-games →
Kill animation & colours. Both pickers offer all 15 suit colours.
