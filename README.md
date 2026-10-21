# [2026W2-Roam.io](http://2026W2-Roam.io)

## Table of Contents

- [Vision Statement](#vision-statement)
- [About Roam.io](#about-roamio)
- [Key Features](#key-features)
- [Handover Documentation](#handover-documentation)
  - [Requirements](#requirements)
  - [Getting Started](#getting-started)
  - [Project Structure](#project-structure)
  - [CI / Quality Gates](#ci--quality-gates)
  - [Deployment](#deployment)
  - [Common Bugs](#common-bugs)
- [Contributors](#contributors)

## Vision Statement

> Roam.io aims to make exploration feel meaningful by turning the real world into a discoverable, evolving experience.

---

## About [Roam.io](http://Roam.io)

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
- **Notifications** — In-app banners for social events (follows, follow requests) and local notifications for fog decay warnings.
- **Settings** — Profile editing, theme (light / dark / dynamic day-night), fog decay difficulty, and private account toggle.

> **Note**
>
> Roam.io focuses on making exploration feel meaningful by turning the real world into a discoverable, evolving experience.

---

## Handover Documentation

### Requirements

#### Software

Install the versions below before building. Flutter **3.41.5** stable is the SDK that matches the Dart constraint in `roam_io/pubspec.yaml`. CI checks out the Flutter **stable** channel, so keep local installs on that release rather than an older stable.

| Tool                      | Version                                | Purpose                                                                                              |
| ------------------------- | -------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| **Flutter SDK**           | 3.41.5 (stable)                        | iOS and Android app                                                                                  |
| **Dart SDK**              | 3.11.3 (`sdk: ^3.11.3`)                | Bundled with Flutter 3.41.5                                                                          |
| **Xcode**                 | 27.1                                   | iOS builds, simulator, and archives                                                                  |
| **CocoaPods**             | 1.16.2                                 | iOS native dependencies (`roam_io/ios`)                                                              |
| **iOS deployment target** | 15.0                                   | Minimum iOS version in `roam_io/ios/Podfile`                                                         |
| **Android SDK**           | compileSdk 36, minSdk 24, targetSdk 36 | Android builds. NDK `28.2.13676358`                                                                  |
| **Android Gradle Plugin** | 8.11.1                                 | `roam_io/android/settings.gradle.kts`                                                                |
| **Gradle**                | 8.14                                   | Wrapper in `roam_io/android/gradle/wrapper`                                                          |
| **Kotlin**                | 2.2.20                                 | Android app language                                                                                 |
| **JDK**                   | 17 (language level)                    | Android compile target. A newer JDK that targets 17 is fine                                          |
| **Node.js**               | 22 (developed on 22.22.1)              | Cloud Functions engine in `roam_io/functions/package.json`, and the local spatial API                |
| **npm**                   | bundled with Node.js 22                | Installs function and spatial-api dependencies                                                       |
| **Firebase CLI**          | 15.32.0                                | Deploy rules, indexes, storage, and functions                                                        |
| **Firebase iOS SDK**      | 12.18.x                                | FlutterFire packages must stay on a BOM that matches this SDK                                        |
| **firebase-functions**    | ^6.0.1                                 | Cloud Functions runtime library                                                                      |
| **firebase-admin**        | ^12.6.0 (functions)                    | Admin SDK used by Cloud Functions                                                                    |
| **Fastlane**              | ~> 2.225                               | TestFlight upload (`roam_io/ios/Gemfile`)                                                            |
| **Ruby**                  | 3.3                                    | CI Ruby for Fastlane (`ios-testflight` workflow)                                                     |
| **PostgreSQL + PostGIS**  | Supabase-hosted                        | Spatial region and place queries. Node client `pg` ^8.20.0 in functions and ^8.21.0 in `spatial-api` |
| **Git**                   | any current release                    | Clone from GitHub                                                                                    |

Run `flutter doctor` after installing Flutter, Xcode, and the Android SDK. It should report no missing requirements for the platform you are building.

#### Hardware

- **macOS** — Required for iOS development and TestFlight builds.
- **Physical device (recommended)** — GPS, background location, Live Activities, and fog-of-war exploration are best tested on a real phone rather than a simulator alone.
- Windows or Linux can be used for Android-only development and backend work.

#### External Services & Access

- **Firebase project** — `roam-io-71e2c`. New teammates must accept the Google Cloud/Firebase invite before deploying or managing resources.
- **Google Maps / Places** — Map rendering and nearby place discovery. The Flutter package constraint is `google_maps_flutter: ^2.6.0`. The Places key is the Cloud Functions secret `GOOGLE_PLACES_API_KEY`.
- **Google Gemini** — Server-side quest photo verification via `gemini-3.5-flash-lite`. API key is the Cloud Functions secret `GEMINI_API_KEY`.
- **Supabase PostgreSQL/PostGIS** — Hosted spatial database. Cloud Functions read it through the `DATABASE_URL` secret.

Firebase config files are already committed in the repo — you do **not** need to regenerate them unless project or app IDs change:

- `roam_io/lib/firebase_options.dart`
- `roam_io/android/app/google-services.json`
- `roam_io/ios/Runner/GoogleService-Info.plist`

### Getting Started

#### 1. Clone and install dependencies

```bash
git clone https://github.com/Monash-FIT3170/2026W2-Roam.io.git
cd 2026W2-Roam.io/roam_io
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

List available devices with `flutter devices` and substitute that id. VS Code / Cursor launch configs are in `.vscode/launch.json` and point at `roam_io/`.

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
│   │   ├── notifications/    # In-app and local notification system
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

- **Flutter CI** (`develop` / `main`) — format check, static analysis, tests with a **70% minimum coverage** threshold, and debug APK build. A release APK is built when a `v`\* tag is pushed.
- **iOS TestFlight** (`develop`) — signed IPA uploaded via Fastlane.
- **iOS build check** (feature branches) — simulator build and Live Activity extension verification.

### Deployment

Roam.io ships as a mobile binary plus Firebase backend resources. There is no separate web host. Deploy backend changes before handing a build to testers, and deploy Firestore rules from the branch that owns the current feature surface.

#### Firebase backend

From `roam_io/`, after `firebase login` and `firebase use roam-io-71e2c`:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage --project roam-io-71e2c
```

Cloud Functions (spatial API, social triggers, quest photo verification) deploy from `roam_io/functions`:

```bash
cd roam_io/functions
npm install
npm run deploy
```

The function runtime is **Node.js 22**. These secrets must already exist on the Firebase project before functions that read them will run:

- `DATABASE_URL` — Supabase Postgres connection string
- `GOOGLE_PLACES_API_KEY`
- `GEMINI_API_KEY`

Set a missing secret with `firebase functions:secrets:set SECRET_NAME --project roam-io-71e2c`.

#### Android

CI uploads a **debug APK** artifact on pushes and pull requests to `develop` and `main`. Pushing a `v`\* tag builds a **release APK** and uploads that artifact too.

A local release build:

```bash
cd roam_io
flutter build apk --release
flutter build appbundle --release
```

Release builds are still signed with the **debug** keystore (`signingConfig` in `roam_io/android/app/build.gradle.kts`). That is enough for sideloading a test APK. A Play Store upload needs a release signing config before `flutter build appbundle --release`.

#### iOS (TestFlight)

Pushes to `develop` run `.github/workflows/ios-testflight.yml`. The workflow installs Flutter stable and CocoaPods, signs with the Apple certificate and provisioning profiles stored as GitHub Actions secrets, builds an IPA with `flutter build ipa --release`, and uploads it with Fastlane `2.225` (`bundle exec fastlane upload_testflight`).

Testers install that build from TestFlight. App id `com.fit3170.roamio`, Apple team `AFC5WD785H`. A local upload uses the same Fastlane lane from `roam_io/ios` once `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY`, and `IPA_PATH` are set. The export options plist is generated inside the GitHub workflow and is not committed.

### Common Bugs

- **Social actions fail with** `permission-denied` — Find People, follows, notifications, kudos, and activity creation fail when hosted Firestore rules are the older MVP rules (for example rules deployed from a branch that does not contain the social collections). Auth and the map can still work. Deploy `firestore.rules` and `firestore.indexes.json` from the branch that owns the current feature surface, then retry.
- **Find People returns nobody** — Search reads `public_profiles.usernameSearch` and `displayNameSearch`. Missing fields produce empty results rather than an error. Backfill with `cd roam_io/functions && npm run backfill:public-profiles` after rules and indexes are deployed.
- **Verification and password-reset emails never arrive** — Firebase sends them, and they often land in junk during development. The verify-email screen tells the user to check spam as well as the inbox.
- **iOS archive fails after a FlutterFire bump** — Keep FlutterFire on a BOM matching `firebase-ios-sdk` **12.18.x**. Newer `cloud_firestore` versions can fail the iOS archive against Firebase SPM APIs. The pin is called out at the top of `roam_io/pubspec.yaml`.
- **Quest completion says the verification method is not supported** — Only GPS, photo, and GPS+photo verification run. Any other quest verification type returns "This verification method is not supported yet." A GPS quest with no stored coordinates returns "This quest does not have a verification location."
- **Map, journeys, or Live Activities do nothing on a simulator** — Exploration and journey tracking need location permission ("While Using" at minimum; "Always" / background location for recording a journey with the app backgrounded). Simulators do not fully reproduce GPS movement, background location, or iOS Live Activities. Use a physical device for those flows.
- **Spatial region import fails on a new machine** — `roam_io/spatial-api/import_sa3.js` hardcodes a local GeoJSON path (`SA3_2021_AUST_GDA2020.json`). Point `GEOJSON_PATH` at your file and pass `DATABASE_URL` before running it.
- **Android release APK is not Play-signed** — `flutter build apk --release` and the tagged CI release APK use the debug signing config. Install it for testing only. See [Deployment](#deployment).

---

## Contributors

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

|                                                                                                                                                                                                                             |                                                                                                                                                                                                     |                                                                                                                                                                                                               |                                                                                                                                                                                                                     |                                                                                                                                                                                                                           |                                                                                                                                                                                                              |                                                                                                                                                                                                                  |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ![Jacob de la Paz](https://avatars.githubusercontent.com/u/182462204?v=4?s=100) **[Jacob de la Paz](https://github.com/jacob-delapaz)** [💻](https://github.com/Monash-FIT3170/2026W2-Roam.io/commits?author=jacob-delapaz) | ![Kevin Phan](https://avatars.githubusercontent.com/u/127915941?v=4?s=100) **[Kevin Phan](https://github.com/KVNPHN)** [💻](https://github.com/Monash-FIT3170/2026W2-Roam.io/commits?author=KVNPHN) | ![Amarprit Singh](https://avatars.githubusercontent.com/u/140028404?v=4?s=100) **[Amarprit Singh](https://github.com/Amar723)** [💻](https://github.com/Monash-FIT3170/2026W2-Roam.io/commits?author=Amar723) | ![Rushil Patel](https://avatars.githubusercontent.com/u/127071803?v=4?s=100) **[Rushil Patel](https://github.com/SplitDiagram)** [💻](https://github.com/Monash-FIT3170/2026W2-Roam.io/commits?author=SplitDiagram) | ![Sanjevan Rajasegar](https://avatars.githubusercontent.com/u/140221218?v=4?s=100) **[Sanjevan Rajasegar](https://github.com/sanjevanr)** [💻](https://github.com/Monash-FIT3170/2026W2-Roam.io/commits?author=sanjevanr) | ![Alvin Liong](https://avatars.githubusercontent.com/u/80614359?v=4?s=100) **[Alvin Liong](https://github.com/alvinliong)** [💻](https://github.com/Monash-FIT3170/2026W2-Roam.io/commits?author=alvinliong) | ![Sam Sutherland](https://avatars.githubusercontent.com/u/39617551?v=4?s=100) **[Sam Sutherland](https://github.com/Sam42YOLO)** [💻](https://github.com/Monash-FIT3170/2026W2-Roam.io/commits?author=Sam42YOLO) |
| ![Nathan Nunes](https://avatars.githubusercontent.com/u/131440522?v=4?s=100) **[Nathan Nunes](https://github.com/n8nunes)** [💻](https://github.com/Monash-FIT3170/2026W2-Roam.io/commits?author=n8nunes)                   |                                                                                                                                                                                                     |                                                                                                                                                                                                               |                                                                                                                                                                                                                     |                                                                                                                                                                                                                           |                                                                                                                                                                                                              |                                                                                                                                                                                                                  |

Agile team 1: Jacob de la Paz, Kevin Phan, Amarprit Singh, Rushil Patel. Agile team 2: Sanjevan Rajasegar, Alvin Liong, Sam Sutherland, Nathan Nunes.
