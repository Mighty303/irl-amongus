# Voting POC verification

- Branch starts at `8b0e522` from `poc/physical-map`; current main was merged before opening the PR, preserving the Local lobby and shared assets.
- The Map POC uses portrait for walking. Main-menu buttons, the developer menu, and voting use landscape. A UI test verifies map entry rotates to portrait and closing it restores landscape.
- Debug and Release simulator builds passed. The portrait-map follow-up passed three focused UI checks: map entry/exit orientation, landscape main menu, and landscape voting selection.
- Seven unit tests and five UI tests passed on iPhone 16e / iOS 18.6. Main-menu and voting checks also passed on iPhone 16 Pro Max.
- Voting checks cover select/cancel, confirmation and locking, dead players, skip, a changing countdown, timeout, results, replay, and exit. Unit tests cover deadline boundaries, background time jumps, bot scheduling, and tie/skip/ejection outcomes.
- Artwork comes from the supplied voting sprite sheet; main-menu buttons and icons, plus skip, close, and replay, reuse the shared assets merged from main.
- Physical-device shake was not exercised; the existing shake detector and developer-menu shortcut are reused.

The existing map station-details UI test failed during verification and was excluded from final voting checks. The developer shortcut still opens the map successfully. Its station-pin accessibility bounds cover the entire floor plan, so its automated center tap does not reliably hit the named station.
