# ThreadTrack

Smart Wardrobe & Laundry Tracker for macOS.

A SwiftUI app that lets users catalog their wardrobe, take a daily outfit photo, automatically identify clothing articles, track wear counts, and remind them when each item is due for laundry.

## Tech Stack

- **Swift / SwiftUI** — UI framework
- **SwiftData** — Persistence layer
- **Vision** — On-device image classification
- **CoreML** — Machine learning model inference
- **AVFoundation** — Camera capture
- **UserNotifications** — Laundry reminders

## Project Structure

```
ThreadTrack/
├── ThreadTrack/
│   ├── ThreadTrackApp.swift      # App entry point
│   ├── ContentView.swift         # Main view
│   ├── Models/
│   │   ├── ClothingCategory.swift
│   │   ├── ClothingItem.swift    # @Model SwiftData entity
│   │   ├── DailyOutfit.swift     # @Model SwiftData entity
│   │   └── LaundryBatch.swift    # @Model SwiftData entity
│   ├── Services/
│   │   ├── CameraService.swift   # AVFoundation camera wrapper
│   │   ├── MLService.swift       # Vision/CoreML clothing classification
│   │   ├── NotificationService.swift  # Local notification scheduling
│   │   └── WardrobeService.swift # CRUD + laundry tracking logic
│   ├── Resources/
│   │   └── Assets.xcassets/
│   ├── Info.plist
│   └── ThreadTrack.entitlements
├── ThreadTrackTests/
├── ThreadTrackUITests/
└── .github/workflows/build.yml
```

## Setup

```bash
# Clone the repo
git clone https://github.com/VibeCoder360/ThreadTrack.git
cd ThreadTrack

# Open in Xcode
open ThreadTrack.xcodeproj

# Or build from CLI
xcodebuild build -project ThreadTrack.xcodeproj -scheme ThreadTrack -destination 'platform=macOS'
```

## Requirements

- macOS 15.0+
- Xcode 16+
- Swift 5.0+

## License

MIT
