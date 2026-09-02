<div align="center">

<h1>2026W2-Roam.io</h1>

<h2>Vision Statement</h2>

<blockquote>
  Roam.io aims to make exploration feel meaningful by turning the real world into a discoverable, evolving experience.
</blockquote>

</div>

<hr>

<h2>About Roam.io</h2>

<p>
  Roam.io is a gamified real-world exploration app that turns everyday movement into discovery.
  Users uncover hidden map regions, discover nearby places, gain XP, and build a personal map of
  where they have explored.
</p>

<p>
  The app is built with <strong>Flutter</strong> (iOS and Android) and backed by <strong>Firebase</strong>
  (Auth, Firestore, Storage, Cloud Functions) plus a <strong>PostGIS spatial API</strong> for region and
  place-of-interest queries.
</p>

<h2>Key Features</h2>

<ul>
  <li><strong>Fog of War Exploration</strong> — Unexplored map regions are hidden and revealed as users physically move through the world. Explored tiles can fog over again based on a configurable decay difficulty (monthly, quarterly, or yearly).</li>
  <li><strong>Location Discovery & Visits</strong> — Nearby landmarks, cafes, parks, and points of interest surface as regions are unlocked. Users can log visits with custom names, descriptions, and photos.</li>
  <li><strong>XP, Levels & Milestones</strong> — Users earn XP for unlocking tiles, discovering places, completing journeys, and finishing side quests. Seven milestone tracks (e.g. Map Magnate, Tile Collector, Kilometre Crusader) reward long-term exploration.</li>
  <li><strong>Journey Tracking</strong> — Record walks, drives, and public transport journeys with GPS route tracking, distance, and tile XP. Supports background location on iOS and Android, with iOS Live Activities and an Android foreground service during active journeys.</li>
  <li><strong>Side Quests</strong> — Optional exploration tasks with GPS, photo, and AI-assisted photo verification (Google Gemini). Quests award XP and can be published to the activity feed.</li>
  <li><strong>Social & Activity Feed</strong> — Follow other explorers, browse a home feed of journeys and quest completions, give kudos, and comment on activities. Includes a Find People search and XP-based leaderboard.</li>
  <li><strong>You Dashboard</strong> — Personal profile with statistics, weekly charts, recent visits, top places, home base, and owned activities.</li>
  <li><strong>Notifications</strong> — In-app banners for social events (follows, follow requests) and local notifications for fog decay warnings on Android.</li>
  <li><strong>Settings</strong> — Profile editing, theme (light / dark / dynamic day-night), fog decay difficulty, and private account toggle.</li>
</ul>

<blockquote>
  <p><strong>Note</strong></p>
  <p>
    Roam.io focuses on making exploration feel meaningful by turning the real world into a discoverable,
    evolving experience.
  </p>
</blockquote>

<hr>

<h2>Handover Documentation</h2>

<p>
  <em>Structured draft for future developers. This section will be refined in Milestone 4.</em>
</p>

<h3>Requirements</h3>

<h4>Software</h4>

<table>
  <thead>
    <tr>
      <th>Tool</th>
      <th>Purpose</th>
      <th>Notes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Flutter SDK</strong> (stable)</td>
      <td>Mobile app development</td>
      <td>Dart SDK <code>^3.11.3</code>. Run <code>flutter doctor</code> to verify setup.</td>
    </tr>
    <tr>
      <td><strong>Xcode + CocoaPods</strong></td>
      <td>iOS builds and simulator</td>
      <td>Required for iOS. Team typically uses the <em>iPhone 17 Pro</em> simulator.</td>
    </tr>
    <tr>
      <td><strong>Android Studio / Android SDK</strong></td>
      <td>Android builds and emulator</td>
      <td>Required for Android. Location permissions needed for map and journey features.</td>
    </tr>
    <tr>
      <td><strong>Node.js 22 + npm</strong></td>
      <td>Firebase Cloud Functions and spatial API</td>
      <td>Used in <code>roam_io/functions/</code> and <code>roam_io/spatial-api/</code>.</td>
    </tr>
    <tr>
      <td><strong>Firebase CLI</strong></td>
      <td>Deploy rules, indexes, and functions</td>
      <td>Run <code>firebase login</code> and accept the team project invite.</td>
    </tr>
    <tr>
      <td><strong>Git</strong></td>
      <td>Version control</td>
      <td>Clone from the GitHub repository.</td>
    </tr>
  </tbody>
</table>

<h4>Hardware</h4>

<ul>
  <li><strong>macOS</strong> — Required for iOS development and TestFlight builds.</li>
  <li><strong>Physical device (recommended)</strong> — GPS, background location, Live Activities, and fog-of-war exploration are best tested on a real phone rather than a simulator alone.</li>
  <li>Windows or Linux can be used for Android-only development and backend work.</li>
</ul>

<h4>External Services & Access</h4>

<ul>
  <li><strong>Firebase project</strong> — <code>roam-io-71e2c</code>. New teammates must accept the Google Cloud/Firebase invite before deploying or managing resources.</li>
  <li><strong>Google Maps / Places</strong> — Used for map rendering and nearby place discovery (keys configured in the app and Cloud Functions).</li>
  <li><strong>Google Gemini</strong> — Used server-side for AI quest photo verification.</li>
  <li><strong>PostgreSQL/PostGIS</strong> — Hosted database for spatial region queries, accessed via Cloud Functions (<code>DATABASE_URL</code> secret).</li>
</ul>

<p>
  Firebase config files are already committed in the repo — you do <strong>not</strong> need to regenerate them
  unless project or app IDs change:
</p>

<ul>
  <li><code>roam_io/lib/firebase_options.dart</code></li>
  <li><code>roam_io/android/app/google-services.json</code></li>
  <li><code>roam_io/ios/Runner/GoogleService-Info.plist</code></li>
</ul>

<h3>Getting Started</h3>

<h4>1. Clone and install dependencies</h4>

```bash
git clone <repo-url>
cd roam_io
flutter pub get
```

<h4>2. Connect to Firebase</h4>

```bash
firebase login
firebase use roam-io-71e2c
```

Confirm the project appears in <code>firebase projects:list</code> after accepting the team invite.

<h4>3. Run the app</h4>

<p><strong>iOS</strong></p>

```bash
flutter clean
flutter pub get
cd ios && pod install --repo-update && cd ..
flutter run -d "iPhone 17 Pro"
```

<p><strong>Android</strong></p>

```bash
flutter run -d <android-device-id>
```

<p>
  List available devices with <code>flutter devices</code>. VS Code / Cursor launch configs are in
  <code>.vscode/launch.json</code> and point at <code>roam_io/</code>.
</p>

<h4>4. Deploy Firestore rules and indexes (when needed)</h4>

<p>
  From <code>roam_io/</code>, redeploy whenever <code>firestore.rules</code> or
  <code>firestore.indexes.json</code> change on the branch you are shipping:
</p>

```bash
firebase deploy --only firestore:rules,firestore:indexes --project roam-io-71e2c
```

<p>Validate rules locally before deploying:</p>

```bash
cd roam_io/functions
firebase emulators:exec --only firestore "npm run test:rules" --project roam-io-71e2c
```

<h4>5. Cloud Functions (optional — backend changes)</h4>

```bash
cd roam_io/functions
npm install
npm run deploy
```

<h4>6. Local spatial API (optional — backend development)</h4>

```bash
cd roam_io/spatial-api
npm install
DATABASE_URL="postgresql://..." node index.js   # defaults to port 3000
```

<p>
  Override the hosted API URL at build time with
  <code>--dart-define=SPATIAL_API_BASE_URL=http://localhost:3000</code>.
</p>

<h3>Project Structure</h3>

<pre>
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
</pre>

<p>
  Flutter architecture and folder conventions are documented in
  <a href="roam_io/lib/README.md"><code>roam_io/lib/README.md</code></a>.
  Detailed setup notes are also in <a href="roam_io/README.md"><code>roam_io/README.md</code></a>.
</p>

<h3>CI / Quality Gates</h3>

<ul>
  <li><strong>Flutter CI</strong> (<code>develop</code> / <code>main</code>) — format check, static analysis, tests with a <strong>70% minimum coverage</strong> threshold, and debug APK build.</li>
  <li><strong>iOS TestFlight</strong> (<code>develop</code>) — signed IPA uploaded via Fastlane.</li>
  <li><strong>iOS build check</strong> (feature branches) — simulator build and Live Activity extension verification.</li>
</ul>

<h3>Common Issues & Notes</h3>

<ul>
  <li>
    <strong>Firestore rules branch mismatch</strong> — <code>develop</code> may still carry older MVP rules
    that lack social/activity collections. Deploying rules from the wrong branch will cause
    <code>permission-denied</code> errors for Find People, follows, notifications, kudos, and activity
    creation. Always deploy rules from the branch that owns the current feature surface.
  </li>
  <li>
    <strong>Find People requires deployed rules and indexes</strong> — After deploying rules/indexes, backfill
    search fields if needed: <code>cd roam_io/functions && npm run backfill:public-profiles</code>.
  </li>
  <li>
    <strong>Firebase emails in spam</strong> — Verification and password-reset emails often land in junk
    folders during development.
  </li>
  <li>
    <strong>iOS Firebase package pinning</strong> — Keep FlutterFire packages on a BOM matching
    <code>firebase-ios-sdk 12.18.x</code>. Newer <code>cloud_firestore</code> versions can fail iOS archive builds.
  </li>
  <li>
    <strong>Location permissions</strong> — Map exploration and journey tracking require "Always" or
    "While Using" location access. Background location is needed for journey recording on both platforms.
  </li>
  <li>
    <strong>Quest verification is partially implemented</strong> — Only GPS, photo, and GPS+photo
    verification types are supported. Other types return "not supported yet."
  </li>
  <li>
    <strong>Spatial data import script</strong> — <code>roam_io/spatial-api/import_sa3.js</code> contains a
    hardcoded local GeoJSON path and must be edited for your machine before use.
  </li>
  <li>
    <strong>Test on a real device</strong> — Simulators cannot fully replicate GPS movement, background
    location, or iOS Live Activities.
  </li>
</ul>

<hr>

<h2>👥 Team</h2>

<table>
  <thead>
    <tr>
      <th>Name</th>
      <th>Email</th>
      <th>Agile Team</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Jacob de la Paz</td>
      <td>jdel0034@student.monash.edu</td>
      <td>1</td>
    </tr>
    <tr>
      <td>Kevin Phan</td>
      <td>kpha0032@student.monash.edu</td>
      <td>1</td>
    </tr>
    <tr>
      <td>Amarprit Singh</td>
      <td>asin0135@student.monash.edu</td>
      <td>1</td>
    </tr>
    <tr>
      <td>Rushil Patel</td>
      <td>rpat0045@student.monash.edu</td>
      <td>1</td>
    </tr>
    <tr>
      <td>Sanjevan Rajasegar</td>
      <td>sraj0063@student.monash.edu</td>
      <td>2</td>
    </tr>
    <tr>
      <td>Alvin Liong</td>
      <td>alio0007@student.monash.edu</td>
      <td>2</td>
    </tr>
    <tr>
      <td>Sam Sutherland</td>
      <td>ssut0006@student.monash.edu</td>
      <td>2</td>
    </tr>
    <tr>
      <td>Nathan Nunes</td>
      <td>nnun0002@student.monash.edu</td>
      <td>2</td>
    </tr>
  </tbody>
</table>
