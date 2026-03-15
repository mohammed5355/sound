# Sound - Native iOS Audio Player

A SwiftUI audio/video player with speed control, pitch adjustment, and A-B loop functionality.

## Project Structure

```
sound/
├── sound/
│   ├── soundApp.swift       # App entry point (@main)
│   ├── ContentView.swift    # Main UI + AudioPlayerManager
│   ├── Info.plist           # App configuration
│   └── Assets.xcassets/     # App icon and colors
│
└── sound.xcodeproj/         # Xcode project
```

## Features

| Feature | Description |
|---------|-------------|
| **File Selection** | Import audio/video files via system picker |
| **Playback Controls** | Play/pause, skip forward/backward 3 seconds |
| **Speed Control** | Adjust playback speed (0.5x - 2.0x) |
| **Pitch Control** | Adjust audio pitch (0.5x - 2.0x) |
| **A-B Loop** | Set loop start (A) and end (B) points for segment repetition |
| **Progress Slider** | Custom gradient slider with drag gesture |
| **Haptic Feedback** | Tactile feedback on button interactions |

## Design System

- **Background**: Light gradient (`#f8f9ff` → `#e8eaf6`)
- **Cards**: White with 20px rounded corners, subtle shadows
- **Accent**: Indigo-to-cyan gradient (`#6366f1` → `#06b6d4`)
- **Play Button**: 100px circular gradient with glow shadow
- **Text**: Dark gray (`#374151`) for labels

## Architecture

### Audio Engine Pipeline

```
[AVAudioPlayerNode] → [AVAudioUnitTimePitch] → [MainMixerNode] → Output
```

### Components

| Component | Location | Description |
|-----------|----------|-------------|
| `ContentView` | Line 6 | Main UI with gradient background |
| `ControlCard` | Line 293 | Reusable speed/pitch control card |
| `LoopButtonModern` | Line 340 | A-B loop point buttons |
| `AudioPlayerManager` | Line 378 | Audio engine controller |

### AudioPlayerManager

Main audio controller class:
- **Published properties**: `isPlaying`, `currentTime`, `duration`, `fileName`, `speed`, `pitch`, `loopA`, `loopB`, `showPicker`
- **Key methods**:
  - `loadFile(url:)` - Load and prepare audio file
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
if let a = loopA, let b = loopB, currentTime >= b {
    seekTo(a)
}
```

### File Import
```swift
.fileImporter(isPresented: $player.showPicker,
              allowedContentTypes: [UTType.audio, UTType.movie])
```

## UI Notes

- **Language**: Arabic with RTL layout direction
- **Navigation**: Hidden navigation bar, gradient background fills safe area

## Building

```bash
open sound.xcodeproj
# Press Cmd+R to build and run in Xcode
```

## Dependencies

- **SwiftUI** - UI framework
- **AVFoundation** - Audio engine
- **Combine** - State management
- **UniformTypeIdentifiers** - File type filtering
