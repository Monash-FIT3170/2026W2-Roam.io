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
      screens/
    auth/
      data/
      providers/
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
      screens/
    quests/
      screens/

  services/
  shared/
    widgets/
  theme/
  firebase_options.dart
  main.dart
```

## What Goes Where

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
