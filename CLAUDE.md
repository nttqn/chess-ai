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
4. Turns on `isMinifyEnabled`/`isShrinkResources` (or the Groovy
   equivalents) for the release build type, wires up `proguardFiles`, and
   appends `tool/proguard-rules-extra.pro` onto the freshly-generated
   `android/app/proguard-rules.pro`. That extra file's keep rules exist
   because recent AGP's R8 strips `androidx.work.impl.WorkDatabase_Impl`
   (only referenced via reflection) — WorkManager needs that class, and
   gets pulled in transitively by `google_mobile_ads`. Without the keep
   rules, a *shrunk* release build crashes on launch with "Unable to get
   provider androidx.startup.InitializationProvider" / "Failed to create
   an instance of androidx.work.impl.WorkDatabase" (shrinking was
   disabled entirely as a first-pass fix for this; re-enabled with the
   proper keep rules once Play Console started flagging "Low app
   optimization" for the unshrunk build). If some *other* reflection-used
   class starts getting stripped, this is the file to extend.
5. Runs `dart run flutter_launcher_icons` (after `flutter pub get`, so the
   package is resolvable) to write `assets/icon/icon.png` into every
   `android/app/src/main/res/mipmap-*/ic_launcher` slot, and sets
   `android:label="Chess with AI"` in the manifest. To change the app icon,
   replace `assets/icon/icon.png` (also bundled as a Flutter asset and
   shown on the home screen) — nothing else needs editing.
6. If `KEYSTORE_BASE64` (+ `KEYSTORE_PASSWORD`/`KEY_ALIAS`/`KEY_PASSWORD`)
   secrets are set, decodes the keystore, writes `android/key.properties`,
   then runs `tool/patch_signing.js` (a committed Node script, not
   inline sed — this edit needs a proper multi-line block insert plus an
   import line for the Kotlin DSL case, which is fragile as a heredoc
   nested inside YAML's indentation-sensitive block scalars) to add a
   `release` `signingConfig` in `android/app/build.gradle(.kts)` and point
   the release build type at it instead of the debug key. Without these
   secrets the build silently stays debug-signed (fine to sideload,
   rejected by Play Console). The actual keystore file lives outside the
   repo (never commit one — `.gitignore` also blocks
   `*.jks`/`*.keystore`/`key.properties` as a backstop).
7. Writes `android/app/src/main/res/values/games-ids.xml` (from
   `tool/games-ids.xml.template`, with `__APP_ID__`/`__PACKAGE_NAME__`
   substituted via `sed`) and adds the two
   `com.google.android.gms.games.APP_ID` / `com.google.android.gms.version`
   `meta-data` entries to the manifest, for Play Games Services sign-in +
   leaderboards. `PLAY_GAMES_APP_ID` falls back to a placeholder if the
   secret is unset — same "fails silently, doesn't break the build"
   pattern as `ADMOB_APP_ID`. The leaderboard ID is a separate thing: it's
   not read from a resource, it's baked into the Dart build itself via
   `--dart-define=PLAY_GAMES_LEADERBOARD_ID=...` on the `flutter build
   apk|appbundle` steps (see `PlayGamesConfig` in
   `lib/game/score_service.dart`), because Dart code can't read Android
   string resources at runtime without another plugin.

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

**`games_services` API notes** (v5.3.0, `package:games_services/games_services.dart`):
`GamesServices.signIn()` handles both silent and interactive auth — safe
to call unconditionally on every app start (that's what
`ScoreService.trySilentSignIn` does). `GamesServices.submitScore(score:
Score(androidLeaderboardID: ..., value: ...))` and
`GamesServices.showLeaderboards(androidLeaderboardID: ...)` are the
submit/view calls; there's no `androidID` field on `Score` despite what
some docs/comments say — it's `androidLeaderboardID`. `PlayerData` (from
`GamesServices.player`/`getPlayerName()`) has `displayName`, not `name`.

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
`google_mobile_ads`. `bannerAdUnitId`/`interstitialAdUnitId` hold the real
ad unit IDs (swapped in from Google's test IDs once AdMob was set up —
don't revert these to test IDs). `ADMOB_APP_ID` is set as a GitHub secret
for the manifest, separately from the ad unit IDs (see README.md's
pre-publish checklist for the App-ID-vs-ad-unit-ID distinction). The
interstitial is deliberately throttled to roughly every other finished
game (`_gamesSinceInterstitial`), not shown after every single game.

**Scoring + Play Games Services (`lib/game/score_service.dart`)**: only a
checkmate win earns points — `calculateScore()` is a pure function of
`Difficulty` (base points 100/250/500/1000) and elapsed `Duration` (a
0.5x–1.5x speed multiplier, floored not zeroed, so a slow win still
counts). `GameController` tracks `_startTime`/calls this once per game
(`_maybeAwardScore`, guarded by `_scoreHandled`) and fires off persistence
+ leaderboard submission in the background via `unawaited()` so the UI
isn't blocked on network calls. Local best scores persist through
`shared_preferences` (`best_score_overall` and `best_score_<difficulty
name>` keys) independently of whether Play Games sign-in ever succeeds —
that's the fallback source of truth. The `games_services` package
(Abedalkareem, Play Games Services v2) wraps sign-in/leaderboard; every
call in `ScoreService` swallows its own exceptions, since "not signed in
yet" / "Play Games unavailable" / "leaderboard not configured" are all
expected, non-fatal states here, not bugs to surface to the player.
Scoring/history/achievements only apply to vs-AI games — 2-player mode
(`vsHuman`) skips all of it, see below.

**Achievements**: `PlayGamesConfig._achievementIdsRaw` reads one GitHub
secret, `PLAY_GAMES_ACHIEVEMENT_IDS`, as a comma-separated list in a fixed
order: first win, 10 total wins, a 5-win streak, an Expert-difficulty win.
Create these 4 achievements in Play Console → Play Games Services →
Achievements first, then set the secret (same pattern as
`PLAY_GAMES_LEADERBOARD_ID`); an unset secret or blank entry just skips
that achievement, same fail-silently pattern as everywhere else in
`ScoreService`. Win/streak counters live in `shared_preferences`
(`stat_total_wins`, `stat_current_streak`) and are updated from
`GameController._maybeAwardScore`: a win increments both and calls
`ScoreService.recordWinAndUnlockAchievements`, an AI win calls
`resetWinStreak`.

**Local 2-player mode (`GameController.vsHuman`)**: when true, both sides
are tappable regardless of `humanColor` (`onSquareTap` compares the
selected piece's color to `turn`, not `humanColor`), the AI is never
scheduled, scoring/history/achievements are skipped, the board doesn't
flip, and `undoLastPlayerMove` takes back a single half-move instead of
the usual pair (no AI reply to also undo).

**Save/resume (`lib/game/game_save_service.dart`)**: every successful
move persists a `SavedGame` (FEN + humanColor + difficulty + vsHuman +
SAN history + elapsed seconds) to `shared_preferences`, overwriting the
previous one; it's cleared as soon as the game ends or a new one starts.
`GameController.resume(SavedGame)` is a second constructor that rebuilds
from that snapshot via `Chess.fromFEN` and re-derives `_startTime` from
the saved elapsed seconds so the score's speed multiplier stays roughly
accurate across a resume. `HomeScreen` loads the save on `initState` and
after returning from a game, showing a "Tiếp tục ván đang chơi" card when
one exists.

**Hint (`GameController.requestHint`)**: reuses `findBestMoveIsolate` from
`chess_ai.dart` (same `compute()` isolate as the AI's own move search) at
whichever is deeper, depth 3 or the current difficulty's depth, with
`randomMoveChance: 0` so it never suggests a deliberately bad move. Result
is stored as `hintFrom`/`hintTo` and drawn by `ChessBoard` as a blue
highlight; cleared on the next move. Disabled in `vsHuman` mode.

**Sound/haptics (`lib/game/feedback_service.dart`)**: no bundled audio
assets — uses `SystemSound.play(SystemSoundType.click)` plus
`HapticFeedback` (selection/light/medium/heavy depending on
move/capture/check/game-over), gated by `SettingsService.soundEnabled`.
Called from `GameController._applyMove` right after a move is applied, so
it fires for both the player's and the AI's moves.

**Settings (`lib/game/settings_service.dart`,
`lib/screens/settings_screen.dart`)**: a synchronous singleton loaded once
in `main()` before `runApp` (the board paints every frame and can't await
a prefs lookup per square), persisted to `shared_preferences` on change.
Holds `soundEnabled` and `boardTheme` (`BoardTheme.classic/forest/ocean` —
`ChessBoard` reads `SettingsService.instance.boardTheme.light/.dark`
directly instead of hardcoded colors).
