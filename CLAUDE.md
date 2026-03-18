# Sound - Native iOS Audio Player

A SwiftUI audio player with speed control, pitch adjustment, A-B loop, and library management.

## Project Structure

```
sound/
├── sound/
│   ├── soundApp.swift       # App entry point (@main)
│   ├── ContentView.swift    # Main UI + AudioPlayerManager + LibraryManager
│   ├── Info.plist           # App configuration
│   └── Assets.xcassets/     # App icon and colors
│
└── sound.xcodeproj/         # Xcode project
```

## Features

| Feature | Description |
|---------|-------------|
| **Library** | Import videos from Photos, manage tracks with custom names |
| **Playback Controls** | Play/pause, skip forward/backward 5 seconds |
| **Speed Control** | Adjust playback speed (0.5x - 2.0x) |
| **Pitch Control** | Adjust audio pitch (0.5x - 2.0x) |
| **A-B Loop** | Set loop start (A) and end (B) points for segment repetition |
| **Repeat Toggle** | Auto-replay track when finished |
| **Progress Slider** | Custom slider with drag gesture |
| **Haptic Feedback** | Tactile feedback on button interactions |

## Design System

- **Background**: Light color (`#f5f7fa`)
- **Cards**: White with 16px rounded corners, subtle shadows
- **Accent**: Blue (`#2563EB`)
- **Play Button**: 72px circular blue button with glow shadow
- **Text**: Dark gray (`#1e293b`) for titles, (`#64748b`) for secondary

## Architecture

### Audio Engine Pipeline

```
[AVAudioPlayerNode] → [AVAudioUnitTimePitch] → [MainMixerNode] → Output
```

### Components

| Component | Description |
|-----------|-------------|
| `LibraryTrack` | Model for library tracks (stores file name, not full path) |
| `LibraryFileManager` | Manages file storage in Documents/Library/ |
| `LibraryManager` | ObservableObject managing track collection |
| `ContentView` | TabView with Player and Library tabs |
| `PlayerView` | Player UI with controls |
| `LibraryView` | Track list with PhotosPicker import |
| `AudioPlayerManager` | Audio engine controller |

### AudioPlayerManager

Main audio controller class:
- **Published properties**: `isPlaying`, `currentTime`, `duration`, `fileName`, `speed`, `pitch`, `loopA`, `loopB`, `loopEnabled`, `repeatEnabled`
- **Key methods**:
  - `loadFile(url:library:saveToLibrary:customName:)` - Load and prepare audio file
  - `togglePlay()` - Play/pause toggle
  - `seekTo(_:)` / `seek(_:)` - Position seeking
  - `applySpeed()` - Set `pitchControl.rate`
  - `applyPitch()` - Set pitch in cents (`log2(pitch) * 1200`)

## Implementation Details

### Speed Control
```swift
pitchControl.rate = Float(speed)  // Range: 0.5 - 2.0
```

### Pitch Control
```swift
pitchControl.pitch = Float(log2(pitch) * 1200)  // Cents conversion
```

### A-B Loop
Timer-based (50ms interval) position checking:
```swift
if loopEnabled, let a = loopA, let b = loopB, currentTime >= b {
    seekTo(a)
}
```

### Track End Handling
```swift
if currentTime >= duration {
    if repeatEnabled {
        seekTo(0); playerNode.play()  // Replay
    } else {
        isPlaying = false; currentTime = 0  // Stop
    }
}
```

### Library Persistence
Tracks stored in UserDefaults with file names (not full paths) to handle iOS app container path changes:
```swift
func getURL() -> URL? {
    return LibraryFileManager.shared.getURL(for: filePath)
}
```

## UI Notes

- **Language**: Arabic with RTL layout direction
- **Navigation**: Hidden navigation bar
- **Tabs**: Player ("المشغل") and Library ("المكتبة")

## Building

```bash
open sound.xcodeproj
# Press Cmd+R to build and run in Xcode
```

## Dependencies

- **SwiftUI** - UI framework
- **AVFoundation** - Audio engine
- **Combine** - State management
- **PhotosUI** - Photo picker for importing videos
