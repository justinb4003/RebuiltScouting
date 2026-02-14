# Rebuilt Scouting

An FRC scouting app built with Flutter. Designed for teams to collect match and pit data at competitions, store it offline, and sync to a backend when connectivity is available.

Deployed as a PWA at [justinb4003.github.io/RebuiltScouting](https://justinb4003.github.io/RebuiltScouting/).

## Features

- **Match Scouting** — Record autonomous and teleop performance, fuel scored/missed, tower levels, defense ratings, and notes. Supports practice mode when no match schedule is loaded.
- **Pit Scouting** — Capture drive train type, wheel configuration, robot ratings, photos, and notes during pit visits.
- **Offline-First** — All data is stored locally and can be batch-uploaded to a backend server when ready.
- **Match Schedule Integration** — Pulls match schedules and team lists from The Blue Alliance API.
- **Settings** — Configure scouter name, team key, and event selection with persistent storage.

## Getting Started

### Prerequisites

- Flutter SDK (stable channel)

### Run Locally

```bash
flutter pub get
flutter run -d chrome
```

### Build for Deployment

```bash
flutter build web --release --base-href=/RebuiltScouting/
```

The built app will be in `build/web/`. A GitHub Actions workflow handles deployment to GitHub Pages automatically on push to `main`.
