# Changelog — Fiumicello Frontend

All notable changes to the fiumicello frontend. Format follows [Keep a Changelog](https://keepachangelog.com/).
Dates are UTC.

## [Unreleased]

### Added (2026-09-04)
- **Registration (email → code → password)** in a single advancing page (`register_view.dart`):
  email → enter the 6-digit code sent to the email → set password (stored as hash on the backend).
- **Password recovery** (`forgot_password_view.dart`, `reset_password_view.dart`): email →
  link/token → new password.
- **Superadmin panel** (`admin_tokens_view.dart`, only `superadmin` role sees it):
  - Generate service tokens (shown once, stored as hash), list them, revoke them.
  - Approve pending registrations (`pendiente` → `aprobado`).
- **Login with email**: identifier field is now the email, plus subtle links to create an
  account and recover password.
- `ApiClient`: `register`, `verify`, `forgotPassword`, `resetPassword`, `listServicios`,
  `generarServicio`, `revocarServicio`, `listPendientes`, `aprobar`.
- Navigation now filters the admin section by role (`AppSections.visible()`); non-superadmins
  don't see "Administración".

### Changed (2026-09-04)
- Mobile bottom `NavigationBar` uses `labelBehavior: alwaysHide` (icons only).

### Fixed (2026-09-04)
- **Money formatting bug**: Postgres `numeric` values arrive over the API as strings
  (e.g. `"20200.0000"`). `money()` now parses numeric strings, fixing amounts showing `$0`.

---

## How to deploy
- Push to `main` triggers GitHub Actions → builds + pushes `milangrisano/fiumicello-frontend` to Docker Hub.
- `docker compose -f docker-compose.prod.yml up -d` (Nginx serves the build and proxies `/api`).