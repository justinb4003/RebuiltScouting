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
- `PickListProvider` — shared live pick list. Polls `GetScoutingResults` every 3s while a screen calls `watch()` and the tab is visible; edits are applied optimistically and sent one team at a time to `UpdatePickListTeam`. `PickList.apply` in `models/pick_list.dart` must stay in sync with `trisonics-api/pick_list.py` in FRCScout.
- `PickBoardProvider` — per-person pick lists ("ballots", keyed by scouter name) plus a shared taken list, from the API's `PickVotes` container. Live via Azure Web PubSub: while the Pick Board is on screen and the tab visible it holds a receive-only WebSocket (`NegotiatePickBoard` → `web_socket_channel`) and the API pushes every saved doc; a 60s poll is the safety net. Without a socket (dropped, live updates off, or the Free tier's 20 connections full) it polls `GetPickVotes` every 2s and keeps retrying the socket with jittered backoff. The socket closes when the tab hides or nobody's watching. Optimistic writes as before: your own ballot (`UpdatePickVote`) and taken flags (`SetPickTaken`); incoming docs only replace older versions. The board is built spot by spot (row #k = the team the most people put at #k, ties show every tied team; a team shows once, at the first spot it wins; DNP-only teams are hidden) with agreement = share of voters who have it at exactly that spot; computed client-side in `models/pick_board.dart`. No points/totals.
- `EventDataProvider` — scouted match rows (`GetResults`, filtered to the secret key) and official match results with score breakdowns (`GetMatchesForEvent` → `MatchResult`). Pure aggregation lives in `lib/analytics/`. Screens call `context.ensureEventData()`.
- `RankingsProvider` — official TBA rankings via `GetRankings`.

Analytics data policy: show the per-event SharedPreferences cache immediately, fetch from the API at most once automatically per app session, and re-fetch only on the refresh button.

**Services** (singletons via `static final instance`):
- `ApiService` — all HTTP calls to `trisonics-scouting-api.azurewebsites.net/api`. Uses `package:http` with a global timeout constant. Override the base URL for local dev with `--dart-define=API_BASE_URL=http://localhost:7071/api`.
- `StorageService` — local persistence via `SharedPreferences`. Handles settings, per-event caches (teams/matches/pit results), and held (unsent) scouting data.

**Offline-first pattern**: Scouting results are saved locally as "held data" and batch-uploaded from the Held Data screen. API responses are cached per-event in SharedPreferences so the app works without connectivity.

**Screens** (routed via named routes in `app.dart`):
- `/settings` (home) — scouter name, event year/selection, theme
- `/scout` — match scouting form
- `/pit` — pit scouting form (includes photo capture)
- `/held` — queued data awaiting upload
- `/scouting-status` — table showing which teams have been scouted per match
- `/pit-status` — table showing pit scouting completion per team
- `/pick-board` — Board (everyone's ballots, Total, 0–100 agreement bar, DNP/taken badges) My List (your own drag-and-drop ballot) and Other Lists (everyone else's ballots as side-scrolling read-only columns)
- `/pick-list` — shared drag-and-drop pick order, DNP/Decline, "taken" flags, notes (same doc the Streamlit Scouting Breakdown page uses)
- `/clusters` — KMeans groups from the API's `GetClusters`, with per-group scatter (fl_chart) and feature profile. Results are cached in memory per request for the app session (refresh button clears); the screen's controls are static so they persist across visits
- `/rankings` — official event rankings table + ranking-score chart
- `/team-details` (argument: `int` team number; or `openTeamDetails(context, tn)`) — reusable `TeamDetailView`: pit data, scouted averages, and a `MatchCard` per match
- `/match-breakdowns` — every match as a `MatchCard` (shared with Team Details), filterable by team
- `/head-to-head` — 2–6 teams side by side

`NavDrawer(selectedIndex:)` indexes follow `_routes` in `widgets/nav_drawer.dart`; inserting a destination shifts every later screen's index.

**Forced update mechanism**: `web/index.html` fetches `version.json` on each load; if the version changed, it clears all caches/service workers and hard-reloads. No-cache headers are set globally in `staticwebapp.config.json` (Azure deployment).

**Build info**: `lib/build_info.dart` is auto-generated by `tool/update_build_info.dart` — do not edit by hand.
