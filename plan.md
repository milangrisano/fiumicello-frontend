# Fiumicello Frontend — Development Plan (Trace / Roadmap)

> **Permanent rule: ALL code must be written in ENGLISH. No Spanish in code.**
> This file keeps the trace of how we plan, think, and structure the frontend.
> It lives alongside the code so it can be read and committed to git when ready.

---

## 1. Project overview

**Fiumicello** is a restaurant management app. This is the **frontend** (Flutter, web), which
consumes a NestJS + TypeORM backend that reads the restaurant's accounts
(`payment_vouchers.db`: supplier invoices, invoice items, payment vouchers).

- **Frontend:** Flutter (web), responsive
- **Backend:** NestJS + TypeORM, SQLite (read-only on the expense DB)
- **Orchestration:** Docker Compose (dev containers)
- **Languistics:** code in English only; user-facing copy in Spanish (product language)

**Goal of this refactor:** reorganize the frontend into a clean, modular, maintainable
architecture, with responsive behavior that chooses **one of three app-shells** depending
on screen width.

---

## 2. Architecture principles

1. **One responsibility per file** (Dart).
2. **Separation of concerns:** data access (API) vs presentation (views).
3. **Responsive, 3 breakpoints,** centralized:
   - **mobile** width < 800
   - **tablet** 800 ≤ width < 1200
   - **desktop** width ≥ 1200
4. **App-shells:** the app chooses ONE of 3 distinct app shells per screen range.
   Each shell is its own `Scaffold` with its own navigation style. The shell's body
   only redraws the **active view**; the navigation chrome stays stable.
5. **Views** are classes, each in its own file under `lib/views/`.

---

## 3. The 3 App-Shells (responsive)

| Screen range   | App type     | Navigation style                              | Shell file           |
|----------------|--------------|-----------------------------------------------|----------------------|
| width < 800    | Mobile app   | **NavigationBar** (bottom navigation), no AppBar | `mobile_shell.dart`  |
| 800–1200       | Tablet app   | **AppBar with ONLY icons**                    | `tablet_shell.dart`  |
| width ≥ 1200   | Desktop app  | **Collapsible/ocultable sidebar** on the left | `desktop_shell.dart` |

`responsive_layout.dart` decides which shell to render based on `MediaQuery` width.

---

## 4. Final folder structure (all in English)

```
lib/
├── main.dart                    # entry point (only runApp)
├── app.dart                    # MaterialApp + theme (debugShowCheckedModeBanner:false)
├── navigation/
│   ├── mobile_shell.dart       # Shell #1: AppBar + NavigationBar (bottom nav)  [mobile <800]
│   ├── tablet_shell.dart       # Shell #2: AppBar only icons                    [800-1200]
│   ├── desktop_shell.dart      # Shell #3: collapsible sidebar                  [>=1200]
│   └── sidebar.dart            # reusable lateral menu for the desktop shell
├── responsive/
│   ├── breakpoints.dart        # 3 cutoffs: mobile <800, tablet <1200, desktop >=1200
│   └── responsive_layout.dart  # picks ONE of the 3 shells based on screen width
├── views/
│   ├── invoices_view.dart      # Module 1: Invoices list + Payment vouchers (tabs)
│   ├── pos_sales_view.dart     # Module 2: placeholder (class, no logic yet)
│   └── summaries_view.dart     # Module 3: placeholder (class, no logic yet)
└── core/
    ├── utils/
    │   └── formatters.dart     # money() centralized (replaces local _money)
    └── data/
        └── api_client.dart     # centralized HTTP client (getApiBase + getJson)
```

---

## 5. Implementation phases

### Phase 1 — Base of the architecture (empty scaffold)
1. Create `lib/responsive/breakpoints.dart` and `responsive_layout.dart` (breakpoints + shell picker).
2. Create `lib/core/utils/formatters.dart` (money()).
3. Create `lib/core/data/api_client.dart` (HTTP client: getApiBase, getJson).
4. Create `lib/views/pos_sales_view.dart` and `lib/views/summaries_view.dart` as placeholder classes.
5. Create `lib/app.dart` (MaterialApp), `main.dart` only as entry.
- Verify: `flutter analyze` clean; correct structure.

### Phase 2 — The 3 App-Shells
1. `mobile_shell.dart`: Scaffold with NavigationBar (bottom nav) for <800.
2. `tablet_shell.dart`: Scaffold with AppBar only icons for 800-1200.
3. `desktop_shell.dart`: Scaffold with collapsible sidebar for >=1200.
4. `sidebar.dart`: reusable lateral menu for desktop shell.
5. `responsive_layout.dart` wires the 3 shells; each keeps its index and only redraws body.
- Verify: changing menu option only changes the body; navigation chrome stable.

### Phase 3 — Refactor Module 1 into invoices_view.dart
1. `InvoicesView` (StatefulWidget): tabs Invoices/Payment vouchers, list, detail (bottom sheet), states (loading/error).
2. Move all current logic from `main.dart` (HTTP via api_client, ListTiles, money()).
3. Clean `main.dart` (leave only entry point).
- Verify: web app loads the 119 real invoices and vouchers as before.

### Phase 4 — Integration and end-to-end verification
1. Recreate `dev-frontend` container (flutter create + build web).
2. Verify in browser (host): responsive picks the correct shell when resizing:
   - <800 → bottom NavigationBar
   - 800-1200 → AppBar with icons
   - >=1200 → collapsible sidebar
   - Module 1 shows real data.

---

## 6. Environment & known notes

- Docker daemon sees the host path as **`/Hermes/data`** (== `/opt/data` in this backend).
  Bind mounts in docker-compose must use `/Hermes/data/...`, NOT `/opt/data/...`.
- Docker Compose plugin installed as a binary at `~/.docker/cli-plugins` (v5.5.1).
- The frontend dev container runs `flutter run -d web-server` (debug mode, hot-reload).
- Backend dev container runs NestJS with `--watch` (hot-reload), port 3000.
- `getApiBase()` builds the API URL from the current browser host so it works when
  opening from a mobile device via the LAN IP (e.g. `192.168.0.201:3000/api`).

## 7. Verification / tests

- `flutter analyze` no errors (inside dev container).
- App compiles (`flutter build web` / `flutter run -d web-server`).
- Navigation: switching menu option only redraws body (shell nav chrome stable).
- Responsive: resizing width picks the correct shell (mobile/tablet/desktop).
- Data: Module 1 loads 119 real invoices and payment vouchers from the API.

## 8. Open / pending

- Approve this plan before executing (Enrique approves in planning mode).
- After refactor, continue with Module 2 (POS) and Module 3 (Summaries) reusing this pattern.