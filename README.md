# 2026W2-Roam.io

## Vision Statement

> Roam.io aims to make exploration feel meaningful by turning the real world into a discoverable, evolving experience.

---

## About Roam.io

Roam.io is a gamified real-world exploration app that turns everyday movement into discovery. Users uncover hidden map regions, discover nearby places, gain XP, and build a personal map of where they have explored.

The app is built with **Flutter** (iOS and Android) and backed by **Firebase** (Auth, Firestore, Storage, Cloud Functions) plus a **PostGIS spatial API** for region and place-of-interest queries.

## Key Features

- **Fog of War Exploration** — Unexplored map regions are hidden and revealed as users physically move through the world. Explored tiles can fog over again based on a configurable decay difficulty (monthly, quarterly, or yearly).
- **Location Discovery & Visits** — Nearby landmarks, cafes, parks, and points of interest surface as regions are unlocked. Users can log visits with custom names, descriptions, and photos.
- **XP, Levels & Milestones** — Users earn XP for unlocking tiles, discovering places, completing journeys, and finishing side quests. Seven milestone tracks (e.g. Map Magnate, Tile Collector, Kilometre Crusader) reward long-term exploration.
- **Journey Tracking** — Record walks, drives, and public transport journeys with GPS route tracking, distance, and tile XP. Supports background location on iOS and Android, with iOS Live Activities and an Android foreground service during active journeys.
- **Side Quests** — Optional exploration tasks with GPS, photo, and AI-assisted photo verification (Google Gemini). Quests award XP and can be published to the activity feed.
- **Social & Activity Feed** — Follow other explorers, browse a home feed of journeys and quest completions, give kudos, and comment on activities. Includes a Find People search and XP-based leaderboard.
- **You Dashboard** — Personal profile with statistics, weekly charts, recent visits, top places, home base, and owned activities.
- **Notifications** — In-app banners for social events (follows, follow requests) and local notifications for fog decay warnings on Android.
- **Settings** — Profile editing, theme (light / dark / dynamic day-night), fog decay difficulty, and private account toggle.

> **Note**
>
> Roam.io focuses on making exploration feel meaningful by turning the real world into a discoverable, evolving experience.

---

## Handover Documentation

_This section is to be refined in Milestone 4._

### Requirements

#### Software

| Tool                             | Purpose                                  | Notes                                                                           |
| -------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------- |
| **Flutter SDK** (stable)         | Mobile app development                   | Dart SDK `^3.11.3`. Run `flutter doctor` to verify setup.                       |
| **Xcode + CocoaPods**            | iOS builds and simulator                 | Required for iOS. Team typically uses the _iPhone 17 Pro_ simulator.            |
| **Android Studio / Android SDK** | Android builds and emulator              | Required for Android. Location permissions needed for map and journey features. |
| **Node.js 22 + npm**             | Firebase Cloud Functions and spatial API | Used in `roam_io/functions/` and `roam_io/spatial-api/`.                        |
| **Firebase CLI**                 | Deploy rules, indexes, and functions     | Run `firebase login` and accept the team project invite.                        |
| **Git**                          | Version control                          | Clone from the GitHub repository.                                               |

#### Hardware

- **macOS** — Required for iOS development and TestFlight builds.
- **Physical device (recommended)** — GPS, background location, Live Activities, and fog-of-war exploration are best tested on a real phone rather than a simulator alone.
- Windows or Linux can be used for Android-only development and backend work.

#### External Services & Access

- **Firebase project** — `roam-io-71e2c`. New teammates must accept the Google Cloud/Firebase invite before deploying or managing resources.
- **Google Maps / Places** — Used for map rendering and nearby place discovery (keys configured in the app and Cloud Functions).
- **Google Gemini** — Used server-side for AI quest photo verification.
- **PostgreSQL/PostGIS** — Hosted database for spatial region queries, accessed via Cloud Functions (`DATABASE_URL` secret).

Firebase config files are already committed in the repo — you do **not** need to regenerate them unless project or app IDs change:

- `roam_io/lib/firebase_options.dart`
- `roam_io/android/app/google-services.json`
- `roam_io/ios/Runner/GoogleService-Info.plist`

### Getting Started

#### 1. Clone and install dependencies

```bash
git clone <repo-url>
cd roam_io
flutter pub get
```

#### 2. Connect to Firebase

```bash
firebase login
firebase use roam-io-71e2c
```

Confirm the project appears in `firebase projects:list` after accepting the team invite.

#### 3. Run the app

**iOS**

```bash
flutter clean
flutter pub get
cd ios && pod install --repo-update && cd ..
flutter run -d "iPhone 17 Pro"
```

**Android**

```bash
flutter run -d <android-device-id>
```

List available devices with `flutter devices`. VS Code / Cursor launch configs are in `.vscode/launch.json` and point at `roam_io/`.

#### 4. Deploy Firestore rules and indexes (when needed)

From `roam_io/`, redeploy whenever `firestore.rules` or `firestore.indexes.json` change on the branch you are shipping:

```bash
firebase deploy --only firestore:rules,firestore:indexes --project roam-io-71e2c
```

Validate rules locally before deploying:

```bash
cd roam_io/functions
firebase emulators:exec --only firestore "npm run test:rules" --project roam-io-71e2c
```

#### 5. Cloud Functions (optional — backend changes)

```bash
cd roam_io/functions
npm install
npm run deploy
```

#### 6. Local spatial API (optional — backend development)

```bash
cd roam_io/spatial-api
npm install
DATABASE_URL="postgresql://..." node index.js   # defaults to port 3000
```

Override the hosted API URL at build time with `--dart-define=SPATIAL_API_BASE_URL=http://localhost:3000`.

### Project Structure

```
2026W2-Roam.io/
├── roam_io/                  # Flutter app (main development directory)
│   ├── lib/
│   │   ├── features/         # Feature modules (auth, map, journeys, quests, social, you, settings)
│   │   ├── notifications/  # In-app and local notification system
│   │   └── shared/           # Shared widgets and utilities
│   ├── functions/            # Firebase Cloud Functions (spatial API, triggers, quest verification)
│   ├── spatial-api/          # Local dev copy of the spatial API
│   ├── firestore.rules       # Firestore security rules
│   └── firestore.indexes.json
├── .github/workflows/        # CI (Flutter analyze/test/coverage) and iOS TestFlight
└── README.md                 # This file

```

Flutter architecture and folder conventions are documented in `roam_io/lib/README.md`. Detailed setup notes are also in `roam_io/README.md`.

### CI / Quality Gates

- **Flutter CI** (`develop` / `main`) — format check, static analysis, tests with a **70% minimum coverage** threshold, and debug APK build.
- **iOS TestFlight** (`develop`) — signed IPA uploaded via Fastlane.
- **iOS build check** (feature branches) — simulator build and Live Activity extension verification.

### Common Issues & Notes

- **Firestore rules branch mismatch** — `develop` may still carry older MVP rules that lack social/activity collections. Deploying rules from the wrong branch will cause `permission-denied` errors for Find People, follows, notifications, kudos, and activity creation. Always deploy rules from the branch that owns the current feature surface.
- **Find People requires deployed rules and indexes** — After deploying rules/indexes, backfill search fields if needed: `cd roam_io/functions && npm run backfill:public-profiles`.
- **Firebase emails in spam** — Verification and password-reset emails often land in junk folders during development.
- **iOS Firebase package pinning** — Keep FlutterFire packages on a BOM matching `firebase-ios-sdk 12.18.x`. Newer `cloud_firestore` versions can fail iOS archive builds.
- **Location permissions** — Map exploration and journey tracking require "Always" or "While Using" location access. Background location is needed for journey recording on both platforms.
- **Quest verification is partially implemented** — Only GPS, photo, and GPS+photo verification types are supported. Other types return "not supported yet."
- **Spatial data import script** — `roam_io/spatial-api/import_sa3.js` contains a hardcoded local GeoJSON path and must be edited for your machine before use.
- **Test on a real device** — Simulators cannot fully replicate GPS movement, background location, or iOS Live Activities.

---

## Team

| Name               | Email                       | Agile Team |
| ------------------ | --------------------------- | ---------- |
| Jacob de la Paz    | jdel0034@student.monash.edu | 1          |
| Kevin Phan         | kpha0032@student.monash.edu | 1          |
| Amarprit Singh     | asin0135@student.monash.edu | 1          |
| Rushil Patel       | rpat0045@student.monash.edu | 1          |
| Sanjevan Rajasegar | sraj0063@student.monash.edu | 2          |
| Alvin Liong        | alio0007@student.monash.edu | 2          |
| Sam Sutherland     | ssut0006@student.monash.edu | 2          |
| Nathan Nunes       | nnun0002@student.monash.edu | 2          |
