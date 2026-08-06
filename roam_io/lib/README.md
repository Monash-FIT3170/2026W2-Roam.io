# `lib/` Architecture Guide

This document defines the Flutter codebase structure and the conventions the team should follow when adding or refactoring code.

## Guiding Principles

- Use **feature-first structure** (`features/<feature>/...`) for product code.
- Keep files **close to where they are used**.
- Put only truly reusable code in `shared/` or `theme/`.
- Prefer simple, predictable conventions over one-off exceptions.

## Current `lib/` Layout

```text
lib/
  features/
    analytics/
      screens/      # transitional compatibility aliases for You
      widgets/      # transitional compatibility exports for You widgets
    auth/
      data/
      providers/
      screens/
    home/
      screens/
    journeys/
      screens/
    map/
      data/
      domain/
      screens/
      widgets/
    navigation/
      screens/
    profile/
      domain/
      screens/      # transitional compatibility aliases for Settings
    quests/
      screens/
    settings/
      screens/
      widgets/
    social/
      screens/
    you/
      screens/
      widgets/

  services/
  shared/
    widgets/
  theme/
  firebase_options.dart
  main.dart
```

## What Goes Where

### Top-Level Authenticated Navigation

The authenticated shell uses five bottom-navigation destinations:

1. `Home` — activity-oriented surface that currently consolidates Journeys and Quests.
2. `Social` — foundation for future friend and community tools.
3. `Map` — existing map experience.
4. `You` — personal activity dashboard, migrated from the old Analytics tab.
5. `Settings` — account and app preferences, migrated from the old Profile tab.

Journey, Quest, Analytics, and Profile terms should remain where they describe
domain concepts or transitional compatibility wrappers, but they should not be
introduced as new top-level navigation destinations.

### Settings Account Editing

`Settings` uses grouped rows for account and preference actions. The primary
Settings screen shows profile picture, display name, and username in the account
header, then routes edits to dedicated screens for display name, username, email,
and password. Account rows should show action labels only; current values belong
inside the dedicated edit screens. Email remains an account setting and uses
Firebase's verified email change flow rather than a direct profile overwrite.
Successful display-name and username saves keep the user on the edit screen so
the updated value can be reviewed before manually navigating back.

### You Dashboard

`You` owns personal profile context and personal activity surfaces. It uses
internal `Profile` and `Activities` tabs rather than adding more bottom-nav
destinations. `Profile` keeps a compact identity block (avatar, name, username,
level/XP bar) above the five-stat row, then a metric-selectable interactive line
graph. Locations Visited and Tiles Unlocked use existing visit/polygon
timestamps. XP Gained uses timestamped `profiles/{uid}/xp_events` recorded
**after** the canonical `profiles/{uid}` XP/level update succeeds. History is
secondary analytics: a failure to write an XP event must never roll back or
block progression. History accumulates from the point event tracking was
introduced — existing aggregate XP is not reverse-engineered into fabricated
past weeks. Weekly buckets use
Monday-start local calendar weeks. Tapping a graph point selects it and shows
that week's exact value; changing metric resets selection. Journey and sidequest
graph modes remain empty until those domain sources exist. Bottom scroll padding
uses `AppBottomNavBar.clearanceFromScreenBottom` with `SafeArea(bottom: false)`
so content is not double-inset under the floating nav. `Activities` shows a
static placeholder via reusable `ActivityFeedCard` for the upcoming feed work;
kudos/comment/share are UI-only.

### Notifications

The authenticated shell listens for production notification actions and displays
shared app toasts. User-facing manual Test Notification controls should not be
added to app chrome; notification templates, overlays, and services remain under
`lib/notifications/`.

### `features/<feature>/screens`

- Flutter screens/pages routed or shown as top-level views.
- **Rule:** screen file names must end with `_screen.dart`.
- Examples:
  - `login_screen.dart`
  - `profile_screen.dart`
  - `map_screen.dart`

### `features/<feature>/widgets`

- UI components used inside a feature but not shared app-wide.
- If a widget is reused across multiple features, move it to `shared/widgets`.

### `features/<feature>/providers`

- `ChangeNotifier`/Provider state classes for that feature.
- Keep provider logic focused on orchestration, state, and UI-facing actions.
- Move heavy I/O and persistence logic into `data/` services/repositories.

### `features/<feature>/data`

- Repositories, API clients, data sources, and feature-specific services.
- External dependencies (Firebase, HTTP, platform APIs) should be accessed from this layer.

### `features/<feature>/domain`

- Domain models/value objects and business entities.
- Keep this layer framework-light where practical.

### `services/`

- Cross-feature services used by multiple features.
- If a service becomes feature-specific, move it into that feature’s `data/`.

### `shared/widgets/`

- Reusable UI building blocks used by multiple features.
- Must be feature-agnostic (no auth/map/profile-specific logic).

### `theme/`

- App-wide theme tokens and styling utilities.
- No feature logic here.

## Naming Conventions

- **Files:** `snake_case.dart`.
- **Screens:** always `_screen.dart`.
- **Widgets/classes:** `PascalCase`.
- **Variables/functions:** `camelCase`.
- Avoid uppercase file names like `MapPage.dart`; use `map_screen.dart`.

## Import Rules

- Prefer **package imports** when crossing major boundaries, e.g.:
  - `package:roam_io/features/...`
  - `package:roam_io/shared/...`
- Relative imports are acceptable for nearby files within the same feature.
- After moving files, always run `flutter analyze` to catch stale imports.

## Folder Creation Rules

- Only create folders that are needed.
- Do not force empty `data/` or `domain/` folders for simple UI-only features.
- If a feature grows, add layers incrementally.

## Ownership and Boundaries

- A feature should not directly manipulate another feature’s internals.
- Cross-feature interactions should happen via:
  - shared services,
  - exported models/contracts,
  - or clearly scoped provider/repository APIs.

## Refactor Checklist (Team Standard)

When moving/renaming files:

1. Move files to the target feature/layer folder.
2. Update imports and class references.
3. Ensure screen files still end with `_screen.dart`.
4. Run:
   - `flutter analyze`
   - relevant app smoke test (`flutter run` on target platform)
5. Update docs/comments if structure semantics changed.

## Anti-Patterns to Avoid

- Dumping all screens under one global folder.
- Putting feature-specific widgets/services in `shared/`.
- Mixing inconsistent folder styles (`presentation/screens` in one feature, `screens` in another).
- Leaving outdated imports after refactors.
