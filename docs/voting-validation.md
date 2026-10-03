# Voting POC verification

- Branch starts at `8b0e522` from `poc/physical-map`.
- The app uses landscape throughout. Main-menu buttons, developer destinations, the map, and voting adapt to the wider layout.
- Debug and Release simulator builds passed.
- Seven unit tests and five UI tests passed on iPhone 16e / iOS 18.6. Main-menu and voting checks also passed on iPhone 16 Pro Max.
- Voting checks cover select/cancel, confirmation and locking, dead players, skip, a changing countdown, timeout, results, replay, and exit. Unit tests cover deadline boundaries, background time jumps, bot scheduling, and tie/skip/ejection outcomes.
- Artwork comes from the supplied voting sprite sheet; main-menu buttons reuse the existing menu artwork.
- Physical-device shake was not exercised; the existing shake detector and developer-menu shortcut are reused.

The existing map station-details UI test failed during verification and was excluded from final voting checks. The developer shortcut still opens the map successfully. Its station-pin accessibility bounds cover the entire floor plan, so its automated center tap does not reliably hit the named station.
