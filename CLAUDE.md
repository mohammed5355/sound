# Sound - Native iOS Audio Player

A SwiftUI audio/video player with speed control, pitch adjustment, and A-B loop functionality.

## Project Structure

```
sound/
├── soundApp.swift       # App entry point (@main)
├── ContentView.swift    # Main UI + AudioPlayerManager
├── Info.plist           # App configuration
└── Assets.xcassets/     # App icon and colors
```

## Features

| Feature | Description |
|---------|-------------|
| **File Selection** | Import audio/video files via system picker |
| **Playback Controls** | Play/pause, skip forward/backward 3 seconds |
| **Speed Control** | Adjust playback speed (0.5x - 2.0x) |
| **Pitch Control** | Adjust audio pitch (0.5x - 2.0x) |
| **A-B Loop** | Set loop start (A) and end (B) points for segment repetition |
| **Progress Slider** | Seekable timeline with time display |
| **Haptic Feedback** | Tactile feedback on button interactions |

## Architecture

### Audio Engine Pipeline

```
[AVAudioPlayerNode] → [AVAudioUnitTimePitch] → [MainMixerNode] → Output
```

### Key Classes

#### AudioPlayerManager
Main audio controller (`ContentView.swift:162-266`):
- Inherits from `NSObject`, conforms to `ObservableObject`
- Properties published for SwiftUI binding:
  - `isPlaying`, `currentTime`, `duration`, `fileName`
  - `speed`, `pitch`, `loopA`, `loopB`, `showPicker`
- Methods:
  - `loadFile(url:)` - Load and prepare audio file
  - `togglePlay()` - Play/pause toggle
  - `seekTo(_:)` / `seek(_:)` - Position seeking
  - `applySpeed()` - Set rate on pitchControl
  - `applyPitch()` - Set pitch in cents (`log2(pitch) * 1200`)
  - `setA()` / `setB()` / `clearLoop()` - Loop point management

#### LoopButton
Reusable component for A-B loop controls (`ContentView.swift:268-279`)

## Implementation Details

### Speed Control
```swift
pitchControl.rate = Float(speed)  // Range: 0.5 - 2.0
```

### Pitch Control
```swift
// Convert multiplier to cents (1200 cents = 1 octave)
pitchControl.pitch = Float(log2(pitch) * 1200)
```

### A-B Loop
Timer-based implementation checks position every 50ms:
```swift
if let a = loopA, let b = loopB, currentTime >= b {
    seekTo(a)
}
```

### File Import
Uses `.fileImporter` with `UTType.audio` and `UTType.movie`:
```swift
.fileImporter(isPresented: $player.showPicker,
              allowedContentTypes: [UTType.audio, UTType.movie]) { ... }
```

## UI Notes

- **Language**: Arabic UI with RTL layout (`\.layoutDirection, .rightToLeft`)
- **Navigation**: Wrapped in `NavigationView` with title "المشغل الذكي"
- **Haptics**: `UIImpactFeedbackGenerator(style: .light)` on interactions

## Building

```bash
open sound.xcodeproj
# Press Cmd+R to build and run in simulator/device
```

## Dependencies

- **SwiftUI** - UI framework
- **AVFoundation** - Audio engine (AVAudioEngine, AVAudioPlayerNode, AVAudioUnitTimePitch)
- **Combine** - Published properties for state management
- **UniformTypeIdentifiers** - File type filtering
