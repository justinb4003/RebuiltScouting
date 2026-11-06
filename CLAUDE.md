# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Communication Style
- Be concise and to the point. Avoid verbose explanations.
- Skip lengthy summaries of what was found or what will be done — just do it.

## Project Overview

FRC (FIRST Robotics Competition) scouting PWA built with Flutter for the 2026 REBUILT game season. Used at competitions to record match and pit scouting data, store it offline, and sync to a backend API.

## Common Commands

```bash
# Run locally
flutter pub get
flutter run -d chrome

# Build for GitHub Pages (main branch)
flutter build web --release --base-href=/RebuiltScouting/

# Build for Azure Static Web Apps (release branch)
flutter build web --release --base-href=/

# Update build timestamp (run before building)
dart run tool/update_build_info.dart

# Analyze
flutter analyze
```

## Deployment

Two deployment targets, both via GitHub Actions:
- **main branch** → GitHub Pages via `.github/workflows/deploy.yml`
- **release branch** → Azure Static Web Apps via `.github/workflows/deploy-release.yml`

Both workflows run `dart run tool/update_build_info.dart` and generate `version.json` for cache-busting before building.

## Architecture

**State management**: Provider (`ChangeNotifierProvider`):
- `AppStateProvider` — global app state: settings, event/team/match lists, pit results. Initialized in `main.dart` before `runApp`. Orchestrates API calls and caches responses via `StorageService`.
- `ScoutingProvider` — match scouting form state
- `PitProvider` — pit scouting form state
- `PickListProvider` — shared live pick list (no screen of its own any more; Pick Board and Team Details use it; same doc the Streamlit Scouting Breakdown page uses). Polls `GetScoutingResults` every 3s while a screen calls `watch()` and the tab is visible; edits are applied optimistically and sent one team at a time to `UpdatePickListTeam`. `PickList.apply` in `models/pick_list.dart` must stay in sync with `trisonics-api/pick_list.py` in FRCScout.
- `PickBoardProvider` — per-person pick lists ("ballots", keyed by scouter name) plus a shared taken list, from the API's `PickVotes` container. Live via Azure Web PubSub: while the Pick Board is on screen and the tab visible it holds a receive-only WebSocket (`NegotiatePickBoard` → `web_socket_channel`) and the API pushes every saved doc; a 60s poll is the safety net. Without a socket (dropped, live updates off, or the Free tier's 20 connections full) it polls `GetPickVotes` every 2s and keeps retrying the socket with jittered backoff. The socket closes when the tab hides or nobody's watching. Optimistic writes as before: your own ballot (`UpdatePickVote`) and taken flags (`SetPickTaken`); incoming docs only replace older versions. The board is built spot by spot (row #k = the team the most people put at #k, ties show every tied team; a team shows once, at the first spot it wins; DNP-only teams are hidden) with agreement = share of voters who have it at exactly that spot; computed client-side in `models/pick_board.dart`. No points/totals.
- `EventDataProvider` — scouted match rows (`GetResults`, filtered to the secret key) and official match results with score breakdowns (`GetMatchesForEvent` → `MatchResult`). Pure aggregation lives in `lib/analytics/`. Screens call `context.ensureEventData()`.
- `RankingsProvider` — official TBA rankings via `GetRankings`.
- `ScheduleProvider` — match-scouting schedule: registered scouters (`GetScouters`) and published schedules (`GetSchedules`, newest first; one per publisher name per secret key + event; the app uses the newest). Same data policy as analytics (cached copy, one auto fetch per session, refresh button). Also holds the Schedule Builder's unpublished draft and its setup (who's scouting, groups who scout together; saved per event + key on the device) plus two device-wide preferences: shifts per person (default 3) and max matches per person (default 10). Pure logic (schedule generation, blocks, problem detection, name normalization matching the API's `voter_key`) is in `models/scout_schedule.dart`, tested in `test/scout_schedule_blocks_test.dart`.
- `ClusterProvider` — cluster settings (dimensions, per-dimension weights, group count; dimensions are always normalized for KMeans, charts show real units) and the event's clustering with them (no exclusions). Settings = this device's custom config (SharedPreferences, per season), else the team default published via `GetClusterConfig`/`SetClusterConfig` (honor system: anyone with the key can publish), else the API's built-in defaults. Loaded at startup without clustering; screens call `context.ensureClusters()`. The last result is cached per event, tagged with the settings signature. Neighbors and "what sets them apart" are computed client-side in `analytics/cluster_similarity.dart` from the result's per-team values (same normalizing/weights as the API).

Analytics data policy: show the per-event SharedPreferences cache immediately, fetch from the API at most once automatically per app session, and re-fetch only on the refresh button.

**Services** (singletons via `static final instance`):
- `ApiService` — all HTTP calls to `trisonics-scouting-api.azurewebsites.net/api`. Uses `package:http` with a global timeout constant. Override the base URL for local dev with `--dart-define=API_BASE_URL=http://localhost:7071/api`.
- `ScouterRegistry` — calls `RegisterScouter` once per (secret key, event, normalized scouter name) per device (5s after settings change, and at startup) and remembers which combinations it sent (SharedPreferences `scouter_registered`). Fire-and-forget; retried next start on failure.
- `ScouterRegistry` also sends the Slack `link_token` (if linked) so the API stores `slack_user_id` on the Scouters doc; a token the API no longer knows (`link_valid: false`) clears the local link.
- `StorageService` — local persistence via `SharedPreferences`. Handles settings, per-event caches (teams/matches/pit results), and held (unsent) scouting data.

**Offline-first pattern**: Scouting results (match, pit, robot notes) are saved locally as "held data" first, then uploaded in the background by `UploadQueue` (`services/upload_queue.dart`): one pass at a time, triggered after each save, at startup, when the tab becomes visible, on the browser `online` event, and on a 60s timer while anything is held (5s→5min jittered backoff after failed passes). A network error/timeout ends the pass; an API rejection records attempts + last error (`StorageService.recordUploadFailure`) and moves on; nothing is auto-deleted. The Held Data screen's "Upload now" runs the same queue. Match/pit/note posts are upserts by client `id` server-side, so retries are safe. All held-data writes go through `StorageService._locked`. On web, held pit photos live in IndexedDB (`services/photo_store_web.dart`, keyed by record id; the record keeps only `held_photo_in_store`), loaded back just before upload; startup migrates inline photos and sweeps orphans. If the IDB write fails the photo stays inline. Browser-only test: `flutter test --platform chrome test/photo_store_web_test.dart`. API responses are cached per-event in SharedPreferences so the app works without connectivity.

**Screens** (routed via named routes in `app.dart`):
- `/settings` (home) — scouter name, secret key, team number, optional Slack link (see Slack link), event year/selection, theme
- `/my-schedule` — My Schedule (first item in the menu): the newest schedule published for this secret key + event, its publisher and time, a one-line summary of my shifts, then a My shifts / Everyone toggle over the same `ScheduleGrid` the builder uses (`onlyMine` keeps real shift numbers). My cell has a primary-color outline, a person icon and bold "(you)"; the shift header says "You: Blue 1" (screen readers hear "you are on Blue 1"). No calendar feed (dropped: Google refreshes subscriptions only every 8–24 h); the app is the one source of truth, and the API DMs linked scouts on Slack ~15 min before each shift (FRCScout `shift_reminders.py`: `ShiftReminders` timer every 5 min, teams with a `bot_token` in `SlackConfigs` only, newest schedule per event, sent-once records in the `ShiftReminders` container; `ShiftRemindersNow` is a local-only HTTP trigger with `dry_run=1&now=<unix>`, since timers don't run on the local func host). **Schedule test mode** (Settings switch, `AppSettings.scheduleTestMode`): Publish offers a practice run that moves every match time so a chosen shift starts at a chosen time today; the offset is saved on the schedule (`time_offset`, `ScoutSchedule.timeOffset`), My Schedule shows the moved times with a Practice run banner, and reminders use them too
- `/schedule-builder` — Schedule Builder (Management group, after Pit Status): 1. tick who's scouting (registry names + names added by hand); 2. groups of 2–6 who always scout together; 3. shifts per person → block count (scouts × shifts ÷ 6) and the quals split evenly into that many blocks; **Generate schedule** rolls a random schedule (six per block, groups never split; the first lap is random, then everyone waits in one line and whoever scouts goes to the back, so later laps repeat the same crews and nobody gets a second shift before everyone has a first, when groups allow; first-lap stations random, then each person returns to their last station when free; Undo snackbar). Shown as one card per block (`widgets/schedule_grid.dart`: red row over blue row); tap a cell to change it. Problems (red: empty positions, overlaps, double-booking, anyone over max matches) and Could be better (amber: uneven shifts, picked but unscheduled). An **Algorithm…** dialog (OK/Cancel checkboxes, `ScheduleOptions`, saved on the device) holds the either-way choices: end shifts at lunch/end of day (off = equal-length shifts, so match counts come out even), same crews every round (off = fewest shifts first, random), keep people on the same station; add new ones there. A Matches per scout table (most first) sits above the schedule. Max matches is checked before generating (quals × 6 ÷ scouts must fit; Generate is disabled with a fix-it message if not), the generator penalizes going over it and re-rolls up to 40 times. Publish as this device's scouter name. Starts from the newest published schedule
- `/scout` — match scouting form
- `/pit` — pit scouting form (includes photo capture)
- `/held` — queued data awaiting upload
- `/scouting-status` — table showing which teams have been scouted per match
- `/pit-status` — table showing pit scouting completion per team
- `/pick-list` — Pick List (`PickBoardScreen`, formerly the Pick Board at `/pick-board`): Board (everyone's ballots, Total, agreement bar with votes/participants, DNP/taken badges) My List (your own drag-and-drop ballot) and Other Lists (everyone else's ballots as side-scrolling read-only columns)
- `/clusters` — KMeans groups from the API's `GetClusters`, with per-group scatter (fl_chart) and feature profile. Shows `ClusterProvider`'s result (ApiService also caches per request for the session; refresh clears). Axes default to `ClusterResult.defaultAxes` (best group separation, R², singleton groups ignored; Y discounted by correlation with X); manual picks are static so they persist across visits. Tapping a team chip marks that team in red on the group's scatter and dimension strips
- `/dimensions` — pick clustering dimensions and weights and the group count; reset to or publish the team default
- `/rankings` — official event rankings table (sticky header, Rank/Team pinned, other columns scroll sideways)
- `/team-details` (argument: `int` team number; or `openTeamDetails(context, tn)`) — reusable `TeamDetailView`: pit data, scouted averages, OPR, Similar teams (cluster group, nearest neighbors, each dimension's share of what sets the team apart), and a `MatchCard` per match
- `/match-breakdowns` — every match as a `MatchCard` (shared with Team Details), filterable by team
- `/head-to-head` — 2–6 teams side by side in three movable, collapsible sections (order and open state saved like Team Details): Official results (table + every match on `MatchCard`, one column per team when each gets ≥340px, else one list in match order; compared teams marked via `MatchCard.markers`), Pit scouting, and Dimensions (every clustering dimension from `ClusterProvider` as a `RangeStrip`, one dot per team, biggest differences first). Teams are saved per event; teams and scroll position survive leaving the screen

`NavDrawer(selectedIndex:)` indexes follow `_routes` in `widgets/nav_drawer.dart`; inserting a destination shifts every later screen's index.

**Slack link** (Settings > Link Slack account; optional, per team): Sign in with Slack (OIDC) via the API (`slack_link.py` + `SlackLinkAvailable`/`SlackLinkStart`/`SlackCallback`/`SlackLinkStatus`/`SlackUnlink` in FRCScout `trisonics-api`; `SlackLinks` container). Each team brings its own Slack app: its client ID/secret and Slack workspace ID live in a `SlackConfigs` Cosmos doc (partition `/secret_key`, matched on secret key + team number, filled in by hand for now; 4003data/4003 → TriSonics 4003 `T8ZBX7UA0`). Nothing from it reaches the app, and there's no global default: no doc = no Slack for that team. Settings shows the button only when `SlackLinkAvailable` says the current key + team number has a config (checked once per session). The app never receives the redirect (an installed iOS PWA opens it in Safari), so `widgets/slack_link_dialog.dart` sends key + team to `SlackLinkStart`, opens `authorize_url` in a new tab and polls `SlackLinkStatus` every 2s for up to 5 min. The callback reloads the team's config from the login session, signs in with that team's credentials and refuses other workspaces. A finished session returns Slack user/name/team and a secret `link_token`, once. The app stores them in `AppSettings` (`slackUserId/Name/TeamId/LinkToken`); only the token's sha256 is on the server, links are per secret key, and the Slack user ID reaches the Scouters doc only through a valid token for the same key, never from the client. Unlink calls `SlackUnlink`; Reset App clears locally. Every team's Slack app registers the same redirect URL, `{API_PUBLIC_URL or request host}/api/SlackCallback`. Local testing without Slack: `SLACK_FAKE=1` on the func host fakes it for secret key `zz-claude-test` only (refused in Azure).

**Forced update mechanism**: `web/index.html` fetches `version.json` on each load; if the version changed, it clears all caches/service workers and hard-reloads. No-cache headers are set globally in `staticwebapp.config.json` (Azure deployment).

**Build info**: `lib/build_info.dart` is auto-generated by `tool/update_build_info.dart` — do not edit by hand.
