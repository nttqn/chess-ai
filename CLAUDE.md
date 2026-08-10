# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Flutter Android chess-vs-AI game (`Chess with AI`), Vietnamese-language UI, with
AdMob banner + interstitial ads wired in, intended for Google Play. There is
no native `android/` (or `ios/`) directory in this repo — see "Android
project is generated, not committed" below before assuming any Gradle/Manifest
file exists locally.

## Commands

There is no Flutter/Android SDK installed in this dev environment by design
(see README.md). If Flutter *is* available in your shell:

```
flutter pub get                    # install deps
flutter analyze                    # static analysis (also run non-blocking in CI)
flutter run -d chrome              # fastest way to eyeball UI changes — no Android SDK needed
flutter create --platforms=android --org com.trungchess --project-name chess_app .
                                    # regenerate android/ locally before a real device/emulator run
flutter build apk --release        # debug-signed test APK
flutter build appbundle --release  # AAB for actual Play Store upload (needs real signing config)
```

There is no `test/` directory yet — no automated tests exist in this repo.

Real APK builds happen in CI, not locally: push to `main` (or trigger
`workflow_dispatch`) and GitHub Actions runs
`.github/workflows/build-apk.yml`, which uploads `app-release.apk` as a
build artifact.

## Android project is generated, not committed

`android/`, `ios/`, `web/`, etc. are gitignored on purpose. The CI workflow
regenerates `android/` from scratch on every run via `flutter create
--platforms=android .`, then patches the result before building:

1. Injects the AdMob App ID (`meta-data` in `AndroidManifest.xml`) — reads
   the `ADMOB_APP_ID` GitHub secret, falling back to Google's public test
   App ID if unset.
2. Adds the `INTERNET` permission to the main manifest (Flutter's default
   template only grants it in the debug-variant manifest).
3. Forces `minSdkVersion 24` / `compileSdk 36` in `android/app/build.gradle`
   (or `.gradle.kts` — the patch step handles both DSLs, since which one
   `flutter create` emits depends on the Flutter version CI happens to
   install). This exists because `google_mobile_ads` requires minSdk 24+;
   without the override, the value falls through to Flutter's own
   `flutter.minSdkVersion` default, which can be lower.
4. Forces `isMinifyEnabled`/`shrinkResources` (or the Groovy equivalents)
   off for the release build type. Recent AGP's R8 strips
   `androidx.work.impl.WorkDatabase_Impl` (only referenced via reflection),
   which WorkManager needs — WorkManager itself gets pulled in transitively
   by `google_mobile_ads`. Without this the installed APK crashes on
   launch with "Unable to get provider
   androidx.startup.InitializationProvider" / "Failed to create an
   instance of androidx.work.impl.WorkDatabase". If shrinking is ever
   re-enabled for a smaller release APK, this needs a `proguard-rules.pro`
   keep rule for `androidx.work.impl.WorkDatabase_Impl` instead of just
   turning shrinking off.
5. Runs `dart run flutter_launcher_icons` (after `flutter pub get`, so the
   package is resolvable) to write `assets/icon/icon.png` into every
   `android/app/src/main/res/mipmap-*/ic_launcher` slot, and sets
   `android:label="Chess with AI"` in the manifest. To change the app icon,
   replace `assets/icon/icon.png` (also bundled as a Flutter asset and
   shown on the home screen) — nothing else needs editing.

If you ever need to hand-edit Android native files (custom launcher icon,
permanent signing config, etc.), the intended path is: install Flutter
locally, run `flutter create` once yourself, remove `/android/` from
`.gitignore`, and commit it — at that point it stops being CI-regenerated
and the workflow's `flutter create`/patch steps should be dropped. Don't
try to hand-write Gradle/Manifest files against the *assumption* they'll
be regenerated later; check `.gitignore` first to know which mode the repo
is in.

**Known upstream landmine:** `google_mobile_ads` versions have shipped with
a broken `android/build.gradle` before (5.3.1's `for (config :
configurations.all)` loop uses a property that doesn't exist on modern
Gradle's configuration container, hard-failing `assembleRelease`). If a CI
build fails inside `:google_mobile_ads`'s own Gradle configuration step,
suspect the pinned plugin version before anything else — check the
package's published `android/build.gradle` (download the archive from the
`archive_url` field in `https://pub.dev/api/packages/google_mobile_ads`)
rather than assuming the bug is in this repo's code.

## Architecture

**Chess rules/move generation** come entirely from the `chess` pub.dev
package (`package:chess/chess.dart`, a chess.js port) — this repo does not
implement its own move generator or legality checker. Key facts about that
package worth knowing before touching AI or game-state code:
- `Chess.board` is a public `List<Piece?>` of length 128 using 0x88
  indexing — always skip squares where `(i & 0x88) != 0` when iterating.
- `generate_moves()` returns fully legal `Move` objects by default
  (`legal: true` is the default) with integer `.from`/`.to` and
  `.fromAlgebraic`/`.toAlgebraic` string getters.
- `moves({'square': s, 'verbose': true})` returns `List<Map>` with
  string `from`/`to`/`san`/`flags`/`captured` keys — this is what the UI
  layer uses to find legal target squares for a tap, since it deals in
  algebraic strings rather than 0x88 ints.
- `move({'from': ..., 'to': ..., 'promotion': ...})` and `undo()` are the
  two entry points used for actually mutating game state from algebraic
  squares; `make_move(Move)`/`undo_move()` are the lower-level
  int-indexed versions used inside the minimax search for speed.

**AI (`lib/game/chess_ai.dart`)** is a hand-written minimax + alpha-beta
search over that same `Chess` object — not a real chess engine (no
Stockfish/UCI). `Difficulty` (easy/medium/hard/expert) maps to a search
depth (1-4) plus a "chance of ignoring the search and playing a random
legal move instead" (35%/15%/0%/0%), which is what keeps Easy actually
beatable rather than just "shallow but perfect."

The search runs inside a background isolate via `compute()`. Because
isolate messages must be plain data, the request/response cross that
boundary as `Map<String, dynamic>` (FEN string + params in, from/to/
promotion strings out) — `findBestMoveIsolate` is the top-level function
`compute()` calls; do not change its signature to take/return the `Chess`
object or a custom class directly, since that reintroduces the
isolate-sendability question this design deliberately sidesteps.

**`GameController` (`lib/game/game_controller.dart`)** is the
`ChangeNotifier` gluing the rules engine, the AI, and the UI together: it
owns the one `chesslib.Chess` instance for the active game, tracks
`selectedSquare`/`legalTargets` for tap-to-move interaction, and decides
when to kick off an AI turn (`_scheduleAiMove`). Pawn promotion is
resolved via a caller-supplied `choosePromotion` callback passed into
`onSquareTap` — the controller itself has no UI dependency; `ChessBoard`
supplies the callback and shows the actual picker dialog. `undoLastPlayerMove`
always undoes in pairs (the AI's reply, then the player's move) so the
player lands back on their own turn rather than the AI's.

**Ads (`lib/services/ads_service.dart`)** is a singleton wrapping
`google_mobile_ads`, currently hardcoded to Google's public test ad unit
IDs. Real IDs get swapped in here (and `ADMOB_APP_ID` set as a GitHub
secret for the manifest) before publishing — see README.md's pre-publish
checklist. The interstitial is deliberately throttled to roughly every
other finished game (`_gamesSinceInterstitial`), not shown after every
single game.

`shared_preferences` is in `pubspec.yaml` but not wired to anything yet —
no persistence (saved games, settings) is implemented currently.
