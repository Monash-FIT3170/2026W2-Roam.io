# Roam.io (Flutter)

Roam.io is a Flutter app using Firebase Authentication and Cloud Firestore.

This README explains how a new teammate can clone the repo, set up local tools, get access to the shared Firebase project, and run the app.

## Codebase Structure

Architecture and folder conventions for Flutter code in `lib/` are documented in:

- `lib/README.md`

## Tech Stack

- Flutter
- Firebase Auth (email/password + email verification)
- Cloud Firestore (`profiles` collection)

## Prerequisites

Install these before running the app:

- Flutter SDK (same major version as the team)
- Xcode + CocoaPods (for iOS)
- Android Studio / Android SDK (for Android)
- Node.js + npm (for Firebase CLI)
- Dart (bundled with Flutter)

Recommended checks:

```bash
flutter --version
flutter doctor
firebase --version
```

## Clone and Install

```bash
git clone <repo-url>
cd roam_io
flutter pub get
```

## Firebase Project Access (Team Onboarding)

This repo is already configured to use the shared Firebase project:

- Project ID: `roam-io-71e2c`

Teammates must accept the Google Cloud/Firebase invite from email before they can manage project resources.

### For teammates: accept, verify access, and connect locally

1. Accept the invite email.
2. Confirm you can open project `roam-io-71e2c` in Firebase Console.
3. Log in locally:

```bash
firebase login
firebase projects:list
```

1. In the output of `firebase projects:list`, confirm `roam-io-71e2c` is visible.
2. Set the default project in this repo:

```bash
firebase use roam-io-71e2c
```

1. Firestore rules/indexes for this feature branch are deployed from
  `roam_io/` against `roam-io-71e2c`. Redeploy whenever
  `firestore.rules` or `firestore.indexes.json` change on the branch you
  are shipping:

```bash
firebase deploy --only firestore:rules,firestore:indexes --project roam-io-71e2c
```

**Warning:** `develop` still carries the older MVP rules (no
`public_profiles`, `follows`, notifications, kudos, or activity create).
Deploying rules from `develop` will overwrite hosted Firebase and break
social/activity features again. Deploy Firestore rules/indexes from the
branch that owns the current socialisation surface (this feature branch)
until those rules are merged into `develop`.

## Firebase Config in This Repo

FlutterFire config files are already committed:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

In normal development, you do **not** need to regenerate these unless the Firebase project/app IDs change.

## Run the App

### iOS

```bash
flutter clean
flutter pub get
cd ios && pod install --repo-update && cd ..
flutter run -d "iPhone 17 Pro"
```

If you use a different simulator name, replace `"iPhone 17 Pro"` with your device from `flutter devices`.

### Android

```bash
flutter clean
flutter pub get
flutter run -d <android-device-id>
```

## Firestore Rules and Indexes

Author: Sanjevan Rajasegar  
Last Updated: 16 August 2026 — Sanjevan Rajasegar

Rules and composite indexes are stored in:

- `firestore.rules`
- `firestore.indexes.json`

Deploy both from `roam_io/`:

```bash
firebase deploy --only firestore:rules,firestore:indexes --project roam-io-71e2c
```

Validate rules locally before deploy:

```bash
cd functions
firebase emulators:exec --only firestore "npm run test:rules" --project roam-io-71e2c
```

Current branch rules cover (among other paths):

- Owner-only `profiles/{uid}` (canonical profile)
- Signed-in `public_profiles` search/read
- `follows` / `follow_requests` and private-account activity visibility
- Owner inbox `profiles/{uid}/notifications`
- Activity create + `activity_counters`, plus kudos/comments/likes under `activities`

Do **not** deploy the older MVP `develop` rules while this socialisation
surface is only complete on the feature branch — that regresses hosted
`permission-denied` failures for Find People, follows, notifications,
kudos, and activity creation.

## Auth Flow Implemented

- Sign up (email, password, username, display name)
- Email verification gate before entering app
- Login
- Forgot password (email reset flow)
- Change password (requires current password reauth)
- Logout
- Session restoration after app restart (Firebase Auth persistence)

Note: Firebase emails (verification/reset password) can often land in spam/junk folders, especially in dev/testing environments.