# Doremi Teacher Watch Special

Watch-only ear trainer. Hear a note and name it, with note names that can follow
concert pitch or your own instrument's naming (for example a saz whose Re sounds
E). Product decisions live in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md),
the frequency model in [docs/PITCH_REFERENCE.md](docs/PITCH_REFERENCE.md), and
everything deliberately left out of v1 in [TODO.md](TODO.md).

There is no iPhone app: the iOS target is an empty container that exists only so
the app can reach the App Store. Same layout as Morse Teacher, Metronome and
Bubble Level.

| | |
|---|---|
| App name | Doremi Teacher Watch Special |
| Bundle ID (container) | `com.hoshinosoftware.doremiteacher` |
| Bundle ID (watch app) | `com.hoshinosoftware.doremiteacher.watchkitapp` |
| Apple ID (App Store Connect) | 6810227571 |
| Support / privacy | https://hoshinosoftware.com/doremiteacher/ · https://hoshinosoftware.com/doremiteacher/#privacy |
| Version | 1.0 |
| Deployment target | watchOS 8.0 (Series 3 and later), iOS 15.0 container |
| Architectures | armv7k, arm64_32, arm64 |

## Layout

```
DoremiTeacher.xcodeproj
DoremiTeacher/               watch app target
  DoremiTeacherApp.swift     @main scene, stops audio when the scene leaves .active
  HomeView.swift             menu: Start, Stats, Settings
  PitchMath.swift            Hz ↔ cents ↔ MIDI around A4 = 440 Hz, unit tested
  ToneSynth.swift            pure PCM rendering of tone/rest segments, unit tested
  TonePlayer.swift           AVAudioEngine playback of one finite buffer per sound
  VolumeView.swift           Digital Crown volume control
  FillButtonStyle.swift      buttons that share a screen's height (no scrolling in rounds)
  Assets.xcassets            AppIcon (1024, from design/icons), AccentColor
  en/ja/tr.lproj             InfoPlist.strings + Localizable.strings
DoremiTeacherContainer/      iOS container, no code at all
  Assets.xcassets            the same AppIcon, iOS idiom
DoremiTeacherTests/          XCTest, runs on the watch simulator
scripts/                     watchOS 8 floor check, clock OCR
design/icons/                icon source files and prompts
```

Both catalogs carry the same 1024×1024 PNG from `design/icons/` (no alpha
channel) and must stay identical.

## Build, test, run

```sh
xcodebuild -project DoremiTeacher.xcodeproj -scheme DoremiTeacher \
  -destination 'generic/platform=watchOS Simulator' -derivedDataPath build/DerivedData build

xcodebuild -project DoremiTeacher.xcodeproj -scheme DoremiTeacher \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -derivedDataPath build/DerivedData test

xcrun simctl boot "Apple Watch Series 11 (46mm)"
xcrun simctl install booted "build/DerivedData/Build/Products/Debug-watchsimulator/Doremi Teacher Watch App.app"
xcrun simctl launch booted com.hoshinosoftware.doremiteacher.watchkitapp
```

## Install on a paired watch

```sh
xcodebuild -project DoremiTeacher.xcodeproj -scheme DoremiTeacher \
  -destination 'generic/platform=watchOS' -derivedDataPath build/DerivedData-device \
  -allowProvisioningUpdates build
xcrun devicectl device install app --device <watch-udid> \
  "build/DerivedData-device/Build/Products/Debug-watchos/Doremi Teacher Watch App.app"
```

The first install attempt sometimes times out on the tunnel; retry.

## Archiving for App Store Connect

```sh
xcodebuild -project DoremiTeacher.xcodeproj -scheme DoremiTeacher \
  -destination 'generic/platform=watchOS' \
  archive -archivePath build/DoremiTeacher.xcarchive
```

The archive must contain the container with the watch app nested inside it:

```
Products/Applications/Doremi Teacher Watch Special.app
  └─ Watch/Doremi Teacher Watch App.app
```

## Keeping the watchOS 8 floor

```sh
./scripts/test-watchos8-compatibility.sh
```
