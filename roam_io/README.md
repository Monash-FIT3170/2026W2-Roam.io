# Roam.io (Flutter)

Roam.io is a Flutter app using Firebase Authentication and Cloud Firestore.

This README explains how a new teammate can clone the repo, set up local tools, get access to the shared Firebase project, and run the app.

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

1. Firestore rules are already deployed for normal development.
  You only need to deploy rules if you changed `firestore.rules`:

```bash
firebase deploy --only firestore:rules
```

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

## Firestore Rules

Rules are stored in:

- `firestore.rules`

Deploy rules:

```bash
firebase deploy --only firestore:rules --project roam-io-71e2c
```

Current rules allow authenticated users to read/write only their own profile document:

- `profiles/{uid}` where `request.auth.uid == uid`

## Auth Flow Implemented

- Sign up (email, password, username, display name)
- Email verification gate before entering app
- Login
- Forgot password (email reset flow)
- Change password (requires current password reauth)
- Logout
- Session restoration after app restart (Firebase Auth persistence)

Note: Firebase emails (verification/reset password) can often land in spam/junk folders, especially in dev/testing environments.