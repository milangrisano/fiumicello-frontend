# Changelog — Fiumicello Frontend

All notable changes to the fiumicello frontend. Format follows [Keep a Changelog](https://keepachangelog.com/).
Dates are UTC.

## [Unreleased]

### Added (2026-09-04)
- **Login screen** (`lib/views/login_view.dart`): username/password form calling
  `POST /api/auth/login`; on success navigates into the app.
- **Session gate** (`lib/app.dart`): restores a persisted session and routes to
  `/login` or `/app` accordingly.
- **JWT in API client** (`lib/core/data/api_client.dart`):
  - `login()`, `logout()`, `restoreSession()`, `isLoggedIn`, `currentUsername`.
  - Sends `Authorization: Bearer <token>` on every request.
  - Resolves a relative `/api` base against the app origin (Nginx prod proxy).
- Session persisted via `shared_preferences`.

### Changed (2026-09-04)
- Mobile bottom `NavigationBar` now uses `labelBehavior: alwaysHide` → **icons only**
  (no text labels under them).

### Fixed (2026-09-04)
- **Money formatting bug**: Postgres `numeric` values arrive over the API as strings
  (e.g. `"20200.0000"`). `money()` now parses numeric strings, fixing amounts showing `$0`.

---

## How to deploy
- Push to `main` triggers GitHub Actions → builds + pushes `milangrisano/fiumicello-frontend` to Docker Hub.
- `docker compose -f docker-compose.prod.yml up -d` (Nginx serves the build and proxies `/api`).