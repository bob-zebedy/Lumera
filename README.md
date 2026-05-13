# Lumera

A focused iOS camera app for photographers who want precise manual control without the bloat. Built with SwiftUI + AVFoundation, targeting iOS 18+.

## Features

- **Full manual control** — ISO, shutter, focus, white balance, exposure compensation with a custom discrete slider
- **Multiple capture formats** — HEIF, RAW (Bayer / ProRAW), RAW + HEIF
- **Lens switching** — ultra-wide, wide, telephoto with smooth chip selector
- **Aspect ratio** — FULL / 16:9 / 1:1 with live preview mask and real photo cropping (RAW always retains full sensor data)
- **Face detection AF** — tap any face to lock focus on it; auto-weighted center bias when no face is selected
- **Burst shooting** — press and hold the shutter to capture multiple frames
- **Flight-in capture animation** — full-screen preview collapses into the thumbnail button
- **Tap-to-focus / -exposure** — including a focus reticle with auto-hide
- **Onboarding** — 10-step coach mark tour walks new users through every control
- **Haptic feedback**, **action button capture event**, **horizon-aware rotation**, **photo embedded GPS**, **custom album save**
- **Localized** — English + Simplified Chinese

## Requirements

- iOS 18.0+
- iPhone (iPad / Mac Catalyst not supported)
- Camera + Photos library permissions

## Project structure

```
Lumera/
├── App/                 entry + Info.plist
├── Camera/              AVFoundation actor wrappers, manual controls, metadata, photo processor
├── Model/               CameraModel (ViewModel), Settings (UserDefaults wrapper)
├── UI/                  SwiftUI views; CameraView split across +Coach/+Controls/+Layout/+Subviews
├── Preview/             UIViewRepresentable preview + tap mapping
├── Assets.xcassets/     AppIcon (default/dark/tinted) + LaunchLogo
└── Localizable.xcstrings + InfoPlist.xcstrings
```

## Building

Open `Lumera.xcodeproj` in Xcode 16+ and run on a real device (camera capture won't work in the simulator).

`CFBundleVersion` is auto-derived from `git rev-list --count HEAD` via the project's Run Script phase, so commit count = build number.

## Privacy

Lumera does not collect, transmit, or store any user data outside the device. See [PRIVACY.md](PRIVACY.md).

## License

Copyright © 2026 Bob. All rights reserved.
