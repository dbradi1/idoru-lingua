# Lingua iOS App

## Setup

### Option A: XcodeGen (recommended)

```bash
brew install xcodegen
cd ios/Lingua
xcodegen generate
open Lingua.xcodeproj
```

### Option B: Manual

1. Open Xcode
2. File → New → Project
3. iOS → App
4. Product name: **Lingua**
5. Interface: **SwiftUI**
6. Language: **Swift**
7. Copy the Swift files from `Lingua/` into the new project
8. Set deployment target to **iOS 17.0**
9. Build

## Architecture

- **SwiftUI** + iOS 17+ (NavigationStack, Charts)
- **MVVM-ish** — views own their state, `AppState` for global
- **APIClient** — single shared instance, async/await
- **No third-party dependencies** — pure Apple frameworks

## File Structure

```
Lingua/
├── LinguaApp.swift        — App entry point
├── AppState.swift         — Global state (connectivity, auth)
├── Models/
│   └── Models.swift       — All Codable data models
├── Networking/
│   └── APIClient.swift    — FastAPI client (async/await)
├── Views/
│   ├── RootView.swift     — Tab navigation
│   ├── Components/
│   │   └── OfflineBanner.swift
│   ├── Home/
│   │   └── HomeView.swift
│   ├── Card/
│   │   └── CardSessionView.swift
│   ├── Journey/
│   │   └── JourneyView.swift
│   ├── Stats/
│   │   └── StatsView.swift
│   └── Settings/
│       └── SettingsView.swift
└── Utilities/
    └── LinguaTheme.swift  — Color palette
```

## Configuration

The app connects to the FastAPI backend at:
- **Base URL:** `http://100.66.129.43:5051/api/v1`
- **Health URL:** `http://100.66.129.43:5051/api/v1/health`

Update `APIConfig` in `APIClient.swift` if the IP changes.

## API Key

Set the API key in Settings tab after first launch. It's stored in UserDefaults (will migrate to Keychain for production).

## What Works

- ✅ Home: due card count, session start, session resume
- ✅ Cards: text answer submission, skip, grade results, session summary
- ✅ Journey: 8-city map, cluster breakdown
- ✅ Stats: review history chart, accuracy, leech queue
- ✅ Settings: API key, server settings sync, app preferences
- ✅ Offline detection with retry banner

## TODO

- [ ] MC answer input (needs MC card data in backend)
- [ ] Audio recording for pronunciation (AVAudioEngine)
- [ ] Keychain for API key storage
- [ ] Local data caching (Core Data for offline)
- [ ] Push notifications (morning session reminder)