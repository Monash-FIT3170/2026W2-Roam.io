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

1. `Home` — friend activity feed surface (temporary stubs until the social feed lands).
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

### Public Profile Dashboards

Registered users have public social profiles by default. Private accounts are
authoritative at `profiles/{uid}.privacy.isPrivateAccount`, mirrored as the
safe discovery bit `public_profiles/{uid}.isPrivateAccount`. Aggregate identity
data stays public for private profiles: avatar, display name, username,
following/follower counts, level, and XP. Detailed visits, XP event graphs,
locations, tiles, and activity feeds are gated to the owner or approved
followers. `You` owns authenticated-user state, while
`OtherUserProfileScreen(selectedUserId)` owns selected-user state and composes
the same dashboard presentation only after access is resolved. Every external
analytics watch must bind to `selectedUserId`, not `AuthProvider.currentUser.uid`
(except Follow relationship actions, which always use the authenticated user's
follow graph).

Find People (`FindPeopleScreen` → `FriendshipService.searchUsers`) lists
`public_profiles` with prefix queries on `usernameSearch` /
`displayNameSearch`. Deployed Firestore rules must allow signed-in
`read` (get/list) on `public_profiles` — without that, clients get
`permission-denied` on `orderBy(displayNameSearch|usernameSearch)` even
though Auth and Map still work. Keep rules in sync via
`firebase deploy --only firestore:rules --project roam-io-71e2c` from
`roam_io/`. Search does not depend on Follow documents or Follow UI state;
Follow / Following is resolved per row after results render. Missing
search fields cause empty hits, not permission errors — backfill with
`npm run backfill:public-profiles` in `roam_io/functions` when needed.

Public avatars use `public_profiles.photoUrl` (HTTPS Firebase Storage download
URLs with `alt=media` + token). Shared `SocialAvatar` loads HTTP(S) via
`Image.network` (same path as Settings); `gs://` / relative storage paths are
resolved with `getDownloadURL` first. Author: Sanjevan Rajasegar,
Last Updated: 9 August 2026.

Profile headers show identity, level/XP, and six public stats:
Following, Followers, Tiles, XP Gained, Journeys, and Sidequests. Following /
Followers come from one-way `follows/{followerId_followeeId}` documents
(`followerId`, `followeeId`, `createdAt`). Following count =
relationships where `followerId == profileId`; Followers count =
relationships where `followeeId == profileId`. Counts and
`FollowConnectionsScreen` lists share those queries. Tapping Following or
Followers on You or an external profile opens the list for that profile id;
row Follow / Following buttons still reflect whether **the authenticated user**
follows each listed person. Public discovery (`FindPeopleScreen`) and external
profiles use Follow / Following stadium buttons (filled Follow, outlined
Following with immediate silent unfollow for public profiles). Private targets
resolve to `Requested` through `follow_requests/{requesterId_targetId}` until
the owner accepts. Accepted requests create the same one-way
`follows/{followerId_followeeId}` document with request-acceptance metadata so
the target does not receive a redundant followed-you notification. Lists and
counts stream from the same `follows` collection, so unfollow on an external
profile updates any open Following/Followers list and profile counts without a
manual refresh. Tiles use selected-user visited polygon records.
The top-level XP Gained stat uses lifetime/current profile XP, while the XP
Gained graph uses timestamped `profiles/{uid}/xp_events` recorded **after**
the canonical `profiles/{uid}` XP/level update succeeds. Journey and sidequest
counts are explicit zeroes in the profile stats view model until persisted
completion sources exist.

Failed Firestore analytics queries must not silently render Tiles as `0`.
`YouAnalyticsProvider` distinguishes loading, real empty results, and errors
for tiles (Tiles show `—` when unavailable). Following / Followers always
render a numeric value: empty or unavailable relationships show `0`, never
`—`. Recent visits and
most-visited surfaces show an unavailable state on error.

`YouAnalyticsProvider` holds the latest visits / tiles / XP events / follow
counts for its bound profile id so Profile data survives Activities tab
remounts and Activity Detail push/pop. Weekly graph buckets use Monday-start
local calendar weeks; tapping a graph point selects it and changing metric
resets selection. The metric pill carousel clips to its outer rounded card
(`clipBehavior: Clip.antiAlias`) so pills never protrude; each pill stays
stadium/capsule shaped (`BorderRadius.circular(999)`).
`You → Activities` still uses the personal stub card with Kudos + live comment
count + Share. External profile Activities must only render persisted
`activities` documents for the selected profile; when none exist, show the
normal empty state and do not render stubs. Public dashboard reads of visits,
XP events, and tile records are temporary public-by-default access and must be
replaced by ART2-84 privacy/projection rules.

### Notifications

ART2-96 in-app banners (`NotificationService` + `NotificationOverlay`) remain
the presentation layer. Friend-request banners continue to listen to
`friend_requests` from `MainShellScreen`.

Public-profile **Follow** notifications are persisted at
`profiles/{recipientId}/notifications/{followerId_followeeId}`. Creation is
idempotent on that ID: after `follows/{id}` is written, a best-effort client
write from `FollowService.follow` creates the inbox row for the followee even
when the recipient is offline; Cloud Function `onFollowCreated` (when
deployed) uses the same document. Clients may create only as
`actorId == auth.uid` when the matching `follows/{id}` document exists.
Recipients may only update `readAt`. Notification write failures never roll
back Follow. Unfollow is silent (no notification create or delete).

`SocialNotificationCoordinator` (shell-scoped, keyed/rebound by auth UID)
watches the inbox:

- On auth UID change: cancels prior subscriptions, clears
  `_surfacedBannerIds` / cold-start state / unread, then starts the new
  user's unread query + recent listener. Account switch on one device must
  behave like cold-start session init.
- Cold start: skips provisional empty cache emits; then one summary banner
  (`N people followed you` / single name) for unread follows; does **not**
  mark them read.
- Live: each new unread follow after cold start surfaces one green in-app
  banner (`showOnDevice: false`).
- Per-session `_surfacedBannerIds` is cleared on UID change so Account A
  dedupe cannot suppress Account B.

Unread count drives a numeric You bottom-nav badge and the You tab bell badge
(counts above 99 show as `99+`). Opening
You does not clear unread. Opening `NotificationsScreen` calls `markAllRead`
and keeps historical rows. Rows support Follow Back / Following (immediate
unfollow) and Remove follower (delete `follows/{actor_recipient}` with no
notify).

User-facing manual Test Notification controls should not be added to app
chrome; templates, overlays, and services remain under `lib/notifications/`.

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
