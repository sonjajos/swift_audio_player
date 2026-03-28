# Swift Audio Player

An iOS audio player built natively with Swift and SwiftUI, featuring real-time FFT audio visualization and waveform display. This project is part of a master thesis comparing performance characteristics between Flutter, React Native, and native Swift implementations of an equivalent audio player application.

<table>
  <tr>
    <td>
      <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-03-28 at 17 29 00" src="https://github.com/user-attachments/assets/5d25e862-c0c0-43d5-8c47-265cc09dccd4" />
    </td>
    <td>
      <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-03-28 at 17 29 27" src="https://github.com/user-attachments/assets/476ac9b6-1122-4309-b387-6abe1ebbeb6f" />
    </td>
    <td>
      <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-03-28 at 17 29 32" src="https://github.com/user-attachments/assets/2f0c0876-41ed-4f75-8132-ae76a5475015" />
    </td>
    <td>
      <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-03-28 at 17 29 38" src="https://github.com/user-attachments/assets/56cc68ae-bb2d-40a9-8222-9c47dd14e380" />
    </td>
    <td>
      <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-03-28 at 17 29 45" src="https://github.com/user-attachments/assets/db39261f-8b00-48bb-a8fd-294ab1284fb2" />
    </td>
  </tr>
</table>
---

## Table of Contents

- [App Description](#app-description)
- [Prerequisites & Tools](#prerequisites--tools)
- [Running the App](#running-the-app)
- [Use Cases](#use-cases)
- [Architecture](#architecture)
  - [Overview](#overview)
  - [Directory Structure](#directory-structure)
  - [AppStore (State Management)](#appstore-state-management)
  - [Services](#services)
  - [Views & Navigation](#views--navigation)
  - [Audio Visualizer](#audio-visualizer)
  - [Waveform Seeker](#waveform-seeker)
  - [AudioEnginePlayer](#audioengineplayerswift)
  - [Waveform C++ Module](#waveform-c-module)
  - [SQLite Storage](#sqlite-storage)
  - [FFT Data Flow](#fft-data-flow)
  - [End-to-End Playback Flow](#end-to-end-playback-flow)

---

## App Description

This audio player allows users to import audio files from their device, browse a local library, and play tracks with a real-time circular audio visualizer and waveform seeker. It is architected to be performance-measurable — specifically designed for comparison against equivalent Flutter and React Native implementations as part of a master thesis on cross-platform mobile performance.

---

## Prerequisites & Tools

### System Requirements

- macOS (required for iOS development)
- Xcode 16.2 or later (with iOS 18+ SDK)
- iOS Simulator or physical iOS device running iOS 18+

### Required Tools

| Tool    | Version | Purpose                                  |
| ------- | ------- | ---------------------------------------- |
| Xcode   | 16.2+   | Build toolchain, simulator, code signing |
| Swift   | 5.0+    | Programming language                     |
| iOS SDK | 18+     | Target platform                          |

### No External Dependencies

This project has zero third-party Swift packages. All functionality is implemented using Apple system frameworks only:

| Framework      | Purpose                                           |
| -------------- | ------------------------------------------------- |
| `AVFoundation` | Audio playback, file decoding, session management |
| `Accelerate`   | vDSP FFT computation (SIMD-accelerated)           |
| `SwiftUI`      | Declarative UI framework                          |
| `Combine`      | Reactive state binding                            |
| `SQLite3`      | Local metadata persistence (raw C API)            |
| `QuartzCore`   | `CADisplayLink` for frame-synced animation        |

---

## Running the App

```bash
# Open the project in Xcode
open SwiftAudioPlayer.xcodeproj

# Build and run on the iOS simulator (Xcode UI or command line)
xcodebuild -scheme SwiftAudioPlayer \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           -configuration Debug \
           build

# Push sample audio files to the running simulator
cd SwiftAudioPlayer/Resources
bash push_audio.sh
```

Or simply open `SwiftAudioPlayer.xcodeproj` in Xcode, select an iOS simulator, and press **Run (⌘R)**.

---

## Use Cases

1. **Import audio files** — Pick one or more audio files (MP3, M4A, WAV, AAC, FLAC, AIFF) from the device using the system document picker. Files are copied to the app's Documents directory for persistence across restarts.

2. **Browse audio library** — View all imported audio files in a scrollable list showing title, artist, and duration. Swipe left on any track to delete it.

3. **Play a track** — Tap any track in the library to open the full-screen player. Playback begins immediately.

4. **Playback controls** — Play, pause, resume, skip to next, or go to previous track. Controls are available both on the full-screen player and the mini player bar.

5. **Real-time visualization** — View a circular audio visualizer that reacts to the audio frequency spectrum in real time using FFT analysis.

6. **Waveform navigation** — View a waveform representation of the current track with a progress indicator showing elapsed and remaining time.

7. **Adjust FFT resolution** — Cycle through band count presets (16 / 32 / 64 / 128 bands) from the player screen to change visualizer detail. Selection persists for the session.

8. **Mini player** — While browsing the library with a track loaded, a compact player bar at the top (below the nav bar) shows a mini visualizer, track info, and playback controls. Tap it to return to the full player.

9. **Audio session management** — Playback pauses automatically on phone calls, Siri activation, or headphone disconnection, and resumes if the system recommends it.

---

## Architecture

### Overview

```
┌─────────────────────────────────────────────────────┐
│                  SwiftUI (Swift)                    │
│                                                     │
│  ┌──────────────┐  ┌──────────────────────────────┐ │
│  │    Views     │  │         AppStore             │ │
│  │ AudioListView│  │  @MainActor @Observable      │ │
│  │NowPlayingView│  │  var state properties        │ │
│  │MiniPlayerBar │  │  Action methods              │ │
│  └──────┬───────┘  └──────────────┬───────────────┘ │
│         │  @Environment           │                 │
│  ┌──────▼─────────────────────────│ Combine .sink   │
│  │       VisualizerModel          │                 │
│  │  CADisplayLink-driven smoothing│                 │
│  └────────────────────────────────┘                 │
└────────────────────────────────┬────────────────────┘
                                 │
              ┌──────────────────▼──────────────────┐
              │         AudioPlayerService          │
              │   @MainActor ObservableObject       │
              │   Bridges engine callbacks →        │
              │   @Published Combine publishers     │
              └──────────────────┬──────────────────┘
                                 │
              ┌──────────────────▼──────────────────┐
              │         AudioEnginePlayer           │
              │   AVAudioEngine + AVAudioPlayerNode │
              │   vDSP FFT pipeline                 │
              │   DispatchSourceTimer (position)    │
              └──────────────────┬──────────────────┘
                                 │
              ┌──────────────────▼──────────────────┐
              │       WaveformCppBridge (Obj-C++)   │
              │                 │                   │
              │                 ▼                   │
              │      waveform_peaks.h / .mm         │
              │      (C++ RMS peak algorithm)       │
              └─────────────────────────────────────┘
                                 │
                                 ▼
              SQLite Database (raw C API via SQLiteService)
              Documents/audio_files/ (filesystem)
```

---

### Directory Structure

```
SwiftAudioPlayer/
├── SwiftAudioPlayer.xcodeproj/       # Xcode project (file-system synchronized)
│
└── SwiftAudioPlayer/
    ├── SwiftAudioPlayerApp.swift     # @main entry point, WindowGroup root
    ├── ContentView.swift             # Root view: NavigationStack, mini player, file picker
    │
    ├── AudioEngine/
    │   ├── AudioEnginePlayer.swift   # Core AVAudioEngine player + FFT pipeline
    │   ├── WaveformCppBridge.h       # Obj-C++ bridge header (Swift ↔ C++)
    │   ├── WaveformCppBridge.mm      # Obj-C++ unity build (includes C++ impl inline)
    │   └── waveform_peaks.h          # C extern declaration for the RMS algorithm
    │
    ├── Models/
    │   ├── AudioTrack.swift          # AudioTrack struct (Identifiable, Codable, Hashable)
    │   ├── FFTData.swift             # FFTData struct (bands, nativeFftTimeUs)
    │   └── PlaybackState.swift       # PlaybackState enum (idle/playing/paused/stopped)
    │
    ├── Services/
    │   ├── AudioPlayerService.swift  # Wraps AudioEnginePlayer, exposes @Published state
    │   ├── AudioMetadataService.swift# AVAsset-based ID3 tag extraction
    │   ├── AudioSessionManager.swift # AVAudioSession configuration + interruptions
    │   ├── FileImportService.swift   # File copy, delete, scan; relative path management
    │   ├── SQLiteService.swift       # Raw SQLite3 C API actor for metadata persistence
    │   └── WaveformService.swift     # PCM decode + C++ peak generation (async)
    │
    ├── Store/
    │   └── AppStore.swift            # @MainActor central state + all action methods
    │
    ├── Views/
    │   ├── AudioListView.swift       # Track list with swipe-to-delete, NavigationLink
    │   ├── NowPlayingView.swift      # Full-screen player: visualizer, waveform, controls
    │   ├── MiniPlayerBarView.swift   # Compact player bar pinned below nav bar
    │   ├── CircularVisualizerView.swift # CADisplayLink-driven circular FFT visualizer
    │   ├── WaveformSeekerView.swift  # Static waveform with frozen-on-pause progress
    │   ├── DocumentPicker.swift      # UIDocumentPickerViewController SwiftUI wrapper
    │   └── FFTVisualizerView.swift   # Bar-graph FFT visualizer (alternative, unused in UI)
    │
    ├── Utilities/
    │   └── Utilities.swift           # Int.formattedTime, Array<Float>.normalized, etc.
    │
    ├── SwiftAudioPlayer-Bridging-Header.h  # Imports WaveformCppBridge.h into Swift
    │
    └── Resources/
        ├── push_audio.sh             # Push sample audio files to iOS simulator
        └── add_audio_files_to_simulator.sh
```

---

### AppStore (State Management)

`AppStore` is a `@MainActor`-isolated `@Observable` class that serves as the single source of truth for all application state. It is passed into the SwiftUI view hierarchy via `.environment()` from `ContentView`.

This mirrors the Riverpod `StateNotifier` pattern used in the Flutter implementation — all state mutations go through `AppStore` action methods, never directly from views.

Using `@Observable` (Swift Observation framework, iOS 17+) instead of `ObservableObject` means SwiftUI tracks only the specific properties accessed during each view's `body` evaluation. Views that do not read `fftData` (e.g. `AudioListView`) are not invalidated by the 60fps FFT updates.

**State:**

```swift
var tracks: [AudioTrack]          // All imported audio files
var currentTrack: AudioTrack?     // Currently loaded track
var playbackState: PlaybackState  // idle / playing / paused / stopped
var currentPositionMs: Int        // Playback position in milliseconds
var durationMs: Int               // Track duration in milliseconds
var fftData: FFTData?             // Latest FFT band data from the engine
var bandCount: Int                // Active FFT band count (16/32/64/128)
var waveformPeaks: [Float]?       // 300-point normalized RMS waveform
var isLoading: Bool               // File import in progress
var isLoadingWaveform: Bool       // Waveform computation in progress
var error: String?                // Last error message for alert display
```

**Key Action Methods:**

```swift
func playTrack(_ track: AudioTrack)       // Load + play; triggers waveform generation
func togglePlayPause()                    // Play/pause/resume depending on current state
func playNext() / playPrevious()          // Skip through the track list
func seek(to positionMs: Int)             // Seek to position
func setBandCount(_ count: Int)           // Update FFT resolution on the engine
func importFiles(_ urls: [URL]) async     // Full import pipeline (copy, metadata, SQLite)
func deleteTrack(_ track: AudioTrack) async
func loadTracks() async                   // Reload all tracks from SQLite
```

**Combine Bindings:**

`AppStore.setupBindings()` uses `.sink` to pipe `AudioPlayerService`'s `@Published` properties into `AppStore`'s corresponding properties. `.assign(to: &$)` is unavailable on `@Observable` types (which have no `@Published` wrapper), so `.sink` with explicit assignment is used instead:

```swift
audioPlayerService.$playbackState    .sink → playbackState
audioPlayerService.$currentPositionMs.sink → currentPositionMs
audioPlayerService.$durationMs       .sink → durationMs
audioPlayerService.$fftData          .sink → fftData
audioPlayerService.$currentTrack     .sink → currentTrack
```

---

### Services

All services are instantiated once as private properties of `AppStore` and never destroyed.

#### `AudioPlayerService`

A `@MainActor ObservableObject` that wraps `AudioEnginePlayer` and exposes a Combine-friendly interface. It translates raw engine callbacks (closures) into `@Published` properties.

```swift
// Playback control
func load(track: AudioTrack) async throws  // AVAudioFile init runs off main thread
func play(), pause(), resume(), stop()
func seek(to positionMs: Int)
func setBandCount(_ count: Int)

// Published state (piped to AppStore via Combine)
@Published private(set) var playbackState: PlaybackState
@Published private(set) var currentPositionMs: Int
@Published private(set) var durationMs: Int
@Published private(set) var fftData: FFTData?
@Published private(set) var currentTrack: AudioTrack?

// Track completion callback
var onTrackCompleted: (() -> Void)?
```

#### `AudioMetadataService`

Extracts ID3 tags asynchronously from audio files using the modern `AVAsset` async API.

```swift
func getMetadata(filePath: String) async throws -> AudioMetadata
// Returns: { title: String, artist: String, durationMs: Int }
```

Uses `await asset.load(.commonMetadata)` and `await asset.load(.duration)` — the non-deprecated async API introduced in iOS 16.

#### `AudioSessionManager`

Configures `AVAudioSession` for playback and handles system audio events.

- Category: `.playback` — audio plays even when the device is silenced
- Handles **interruptions** (phone calls, Siri, alarms): pauses on began, optionally resumes on ended based on `AVAudioSession.InterruptionOptions.shouldResume`
- Handles **route changes**: pauses when headphones are unplugged (`oldDeviceUnavailable`)

#### `FileImportService`

An `actor` that manages the app's `Documents/audio_files/` directory.

```swift
// Copy a user-picked file into the app's sandboxed audio directory
func copyToDocuments(from sourceURL: URL) throws -> String  // returns relative path

// Delete a stored audio file
func deleteFile(at filePath: String) throws

// List all audio files as relative paths
func listAudioFiles() throws -> [String]

// Find files on disk not yet in the SQLite database
func findOrphanedFiles(excluding: Set<String>) throws -> [String]

// Resolve a stored relative path to the current absolute container path
static func resolvedPath(for relativePath: String) -> String
```

**Key design:** Files are always stored and retrieved as **relative paths** (`"audio_files/foo.mp3"`), never absolute paths. iOS container UUIDs change on clean Xcode installs; `resolvedPath(for:)` resolves to the current absolute path at the point of use, making stored references stable across rebuilds.

#### `SQLiteService`

An `actor` that wraps the raw SQLite3 C API for thread-safe metadata persistence.

**Schema:**

```sql
CREATE TABLE IF NOT EXISTS audio_tracks (
  id          TEXT    PRIMARY KEY,   -- UUID string
  file_path   TEXT    NOT NULL,      -- relative path, e.g. "audio_files/foo.mp3"
  title       TEXT    NOT NULL,
  artist      TEXT    NOT NULL,
  duration_ms INTEGER NOT NULL,      -- stored as int64 to handle long tracks
  date_added  REAL    NOT NULL       -- Unix timestamp
);
```

**Methods:** `setup()`, `insertTrack(_:)`, `getAllTracks()`, `deleteTrack(id:)`

All `sqlite3_bind_text` calls use `SQLITE_TRANSIENT` to ensure SQLite copies string data before the Swift temporaries are released. Duration uses `sqlite3_bind_int64` / `sqlite3_column_int64` to avoid 32-bit overflow on long tracks.

#### `WaveformService`

Decodes an audio file to mono PCM float32 and generates normalized RMS peaks via the C++ bridge.

```swift
func generatePeaks(absolutePath: String) async throws -> [Float]
// Returns 300 floats in [0, 1] — one per waveform bar
```

The implementation runs entirely on a `Task.detached` background thread. An `autoreleasepool` wraps the PCM decode step so the large `AVAudioPCMBuffer` is freed immediately after decoding — before the C++ peak computation allocates its output — halving peak memory usage.

---

### Views & Navigation

Navigation uses SwiftUI's type-safe `NavigationStack` with `NavigationLink(value:)` and `.navigationDestination(for:)`.

```
ContentView (NavigationStack root)
    │
    ├── AudioListView             (/ — track list)
    │       │
    │       └── NowPlayingView    (/player — full screen player, via NavigationLink(value: track))
    │
    └── NowPlayingView            (programmatic, via mini player tap → nowPlayingTrack binding)
```

#### `ContentView`

Root view. Owns the `NavigationStack`, the `AppStore` `@StateObject`, the file picker binding, and the `nowPlayingTrack` state that drives programmatic navigation from the mini player.

#### `AudioListView`

Library view. Shows all imported tracks in a `List` with `NavigationLink(value: track)` per row. Swipe-to-delete triggers `store.deleteTrack(_:)`. Empty state shows instructional text.

#### `NowPlayingView`

Full-screen player. Layout top to bottom:

1. Track title and artist name
2. Large `CircularVisualizerView` (fills available space, 1:1 aspect ratio)
3. `WaveformSeekerView` with elapsed/total time labels
4. Playback controls: Previous | Play/Pause (72pt circle) | Next

A button in the top-right corner cycles the FFT band count: 16b → 32b → 64b → 128b → 16b. The displayed value is doubled (e.g. 32 bands shown as "64b") because the visualizer mirrors bands left/right.

#### `MiniPlayerBarView`

Compact player shown below the nav bar whenever `store.currentTrack != nil`. Contains:

- Small `CircularVisualizerView` (fixed 16 bands, 64×64pt)
- Track title and artist
- Previous / Play-Pause / Next buttons

Tapping anywhere sets `nowPlayingTrack` in `ContentView`, triggering programmatic navigation to `NowPlayingView`.

---

### Audio Visualizer

`CircularVisualizerView` renders a rotating circular FFT visualizer using SwiftUI's `Canvas` API with `rendersAsynchronously: true`.

#### Architecture

A `VisualizerModel: ObservableObject` owns all mutable state and drives animation via `CADisplayLink` — matching Flutter's `AnimationController` tick pattern:

```swift
class VisualizerModel: ObservableObject {
    @Published private(set) var bands: [Float]      // smoothed band values
    @Published private(set) var rotationFraction: Double  // 0...1, 12s period
    private(set) var colors: [Color]                // pre-computed, never re-allocated
}
```

#### Geometry

`2 × bandCount` bars arranged in a full circle:

- Right half: bands 0 to N-1 (angle step = π / (N-1))
- Left half: mirrored bands, same amplitudes
- Inner radius: 28% of the widget's shorter dimension
- Max bar length: 22% of the shorter dimension
- Color: HSL gradient from pink (hue 340°) at top → cyan (hue 180°) at bottom

A continuous rotation completes one revolution every 12 seconds.

#### Smoothing

Exponential interpolation (`α = 0.3`) is applied every `CADisplayLink` tick, matching Flutter's `lerpDouble(..., 0.3)`:

```swift
// In-place mutation — no CoW array copy
for i in 0..<bandCount {
    bands[i] += (targetBands[i] - bands[i]) * alpha
}
```

#### Performance Optimizations

- **Pre-computed colors**: The `[Color]` array is computed once at init and on band count change — never allocated per frame. Eliminates ~30,000 `Color` object allocations per second at 128 bands.
- **In-place band mutation**: `bands` is mutated directly without creating a copy, eliminating 60 CoW allocations/second.
- **`rendersAsynchronously: true`**: Canvas rendering is offloaded from the main thread.
- **`CADisplayLink`** drives animation instead of `TimelineView`, giving frame-synchronized 60fps updates directly on the main run loop.

---

### Waveform Seeker

`WaveformSeekerView` displays a static waveform of the current track with a cyan progress indicator. Mirrors Flutter's `WaveformSeeker` widget.

**States:**

- **Loading** (`peaks == nil`): Placeholder rendered as 60 sine-envelope tick marks on a center line
- **Loaded**: 300 rounded-rectangle bars; bars left of the playhead are bright cyan with a white tip, bars to the right are dim cyan

**Border styling** matches the Flutter original: thin semi-transparent cyan lines on top/bottom, solid cyan 3pt borders on left/right.

**Freeze on pause:** The view holds `@State private var frozenProgress` that only updates when `isPlaying == true`. When the user pauses, the waveform progress position freezes instantly with no easing or animation drift.

**Time labels** show elapsed and total time below the waveform in monospaced digits.

---

### AudioEnginePlayer.swift

Core playback engine built on `AVAudioEngine` + `AVAudioPlayerNode`.

**Playback:**

- Files loaded with `AVAudioFile` via `async throws load()` — `AVAudioFile(forReading:)` runs on a `Task.detached` background thread to avoid blocking the main thread during codec initialization (eliminates 500–900ms hangs on track change)
- Scheduled via `playerNode.scheduleSegment()`
- Seek: stops player, updates `seekFrameOffset`, reschedules from new position
- Position tracked via `playerNode.playerTime(forNodeTime:)` + `seekFrameOffset`
- `DispatchSourceTimer` on a utility queue fires every 100ms to emit position updates via `onStateChanged`
- `loadGeneration` counter prevents stale completion callbacks from previous tracks

**FFT Pipeline:**

```
Audio Output (MainMixerNode tap, 4096 samples/buffer)
        │
        ▼
Stereo → Mono (vDSP_vadd + vDSP_vsdiv)
        │
        ▼
Backpressure check (os_unfair_lock_trylock — non-blocking, never stalls audio thread)
   → drop frame if previous FFT still running
        │
        ▼
Snapshot mono samples into pre-allocated windowedBuffer
        │
        └──► fftQueue.async (QoS: userInteractive) {
                  Hann window        (vDSP_vmul with cached window array)
                  Real→complex       (vDSP_ctoz)
                  FFT                (vDSP_fft_zrip, radix-2, 4096 points)
                  Magnitude²         (vDSP_zvmags)
                  dB conversion      (vDSP_vdbcon)
                  Logarithmic band grouping (bins → N bands)
                  Normalize          (60 dB dynamic range + power curve)
                  → onFFTData callback → AudioPlayerService → AppStore.$fftData
             }
```

All FFT buffers (`fftRealp`, `fftImagp`, `magnitudes`, `monoBuffer`, `windowedBuffer`) are pre-allocated at init and reused every frame — zero per-frame heap allocations in the audio hot path.

---

### Waveform C++ Module

Located at `AudioEngine/WaveformCppBridge.mm`. A small, focused C++ library for computing normalized audio waveform peaks from PCM data, identical in algorithm to the Flutter implementation.

**Function (declared in `waveform_peaks.h`):**

```cpp
extern "C" int generate_waveform_peaks(
    const float* pcm_buffer,    // mono float32 samples in [-1, 1]
    uint64_t     frame_count,   // total sample count
    double       sample_rate,   // Hz (unused — uniform time chunks)
    uint32_t     bar_count,     // number of output bars (300)
    float*       peaks_out,     // caller-allocated output array
    uint32_t*    peaks_count_out
);
// Returns: 1 on success, 0 on error
```

**Algorithm:**

1. Divide audio into `bar_count` uniform time chunks: `chunk_frames = frame_count / bar_count`
2. Per chunk: compute RMS energy — `sqrt(mean(sample²))`
3. Find global maximum RMS across all chunks
4. Normalize: `peaks[i] = rms[i] / global_max_rms` → output in [0, 1]

This produces a perceptually accurate loudness representation — the loudest moment always reaches 1.0, quieter sections are scaled proportionally.

**Integration:** The C++ implementation lives entirely inside `WaveformCppBridge.mm` (no separate `.cpp` translation unit, avoiding duplicate symbol linker errors with Xcode's file-system synchronized build groups). Swift calls it through the Objective-C++ bridge via a standard bridging header.

**PCM decode:** `WaveformService.decodePCMMono()` decodes the audio file to mono float32 using `AVAudioFile` + `AVAudioConverter`, wrapped in `autoreleasepool` so the large native buffer is freed before C++ peak computation begins.

---

### SQLite Storage

Audio file metadata is persisted locally using the raw SQLite3 C API via `SQLiteService` (a Swift `actor`). The database is created automatically in the app's Documents directory on first launch.

**Schema:**

```sql
CREATE TABLE IF NOT EXISTS audio_tracks (
  id          TEXT    PRIMARY KEY,
  file_path   TEXT    NOT NULL,
  title       TEXT    NOT NULL,
  artist      TEXT    NOT NULL,
  duration_ms INTEGER NOT NULL,
  date_added  REAL    NOT NULL
);
```

**Access pattern:** `SQLiteService` is an `actor` — all database operations are automatically serialized by the Swift concurrency runtime, eliminating manual locking.

**Sync strategy:** On each app launch, `AppStore.cleanupOrphanedFiles()` reconciles the database with actual files on disk:

1. Find files in `Documents/audio_files/` not yet in the DB
2. Extract metadata via `AudioMetadataService`
3. Insert into SQLite and add to `AppStore.tracks`

Audio files are stored at: `Documents/audio_files/<filename>` — persisted across app restarts in the app's sandboxed Documents directory.

---

### FFT Data Flow

```
Native Audio Thread (AVAudioEngine MainMixerNode tap)
        │
        │  Buffer: 4096 float32 samples per callback (~11ms at 44.1kHz)
        ▼
AudioEnginePlayer
  - Mix stereo → mono (vDSP_vadd + vDSP_vsdiv)
  - Backpressure: os_unfair_lock_trylock (non-blocking — drops frame if FFT busy)
  - Copy mono samples → pre-allocated windowedBuffer
        │
        ▼  (fftQueue: QoS userInteractive)
  - Apply Hann window (vDSP_vmul, cached window)
  - vDSP_fft_zrip (radix-2 FFT, 4096 points)
  - vDSP_zvmags (magnitude squared)
  - vDSP_vdbcon (convert to dB)
  - Logarithmic band grouping (bins → N bands, log2 spaced edges)
  - Normalize: 60 dB dynamic range, power curve (x²)
  - Record nativeFftTimeUs (CACurrentMediaTime delta in µs)
        │
        ▼  onFFTData callback
AudioPlayerService  →  @Published fftData: FFTData
        │
        ▼  Combine .assign(to:)
AppStore.$fftData
        │
        ▼  .onChange(of: fftData) in CircularVisualizerView
VisualizerModel.updateTarget(bands)  — writes into targetBands[]
        │
        ▼  CADisplayLink tick (60fps, main thread)
  - Lerp: bands[i] += (targetBands[i] - bands[i]) * 0.3  (in-place, no allocation)
  - rotationFraction += dt / 12.0
        │
        ▼  @Published bands change → Canvas redraw
SwiftUI Canvas
  - Draw 2×bandCount radial bars with pre-computed HSL color array
  - rendersAsynchronously: true
```

Key design insight: FFT values arrive at audio tap rate (~60+ Hz) but the Canvas only redraws at `CADisplayLink` rate (60fps). The `updateTarget` → lerp → paint pipeline decouples data production from rendering, identical to Flutter's `AnimationController` tick pattern.

---

### End-to-End Playback Flow

```
1. User taps "+" in AudioListView
   └── DocumentPicker → system document picker (UIDocumentPickerViewController)

2. AppStore.importFiles([URL])
   └── FileImportService.copyToDocuments(from:)
       └── Validates extension, copies to Documents/audio_files/, returns relative path

3. AudioMetadataService.getMetadata(filePath:)
   └── AVAsset async API: await asset.load(.commonMetadata / .duration)
       └── Extracts title, artist, durationMs from ID3 tags

4. SQLiteService.insertTrack(_:)
   └── Persists relative path + metadata to audio_tracks table

5. AppStore.tracks.insert(track, at: 0) → AudioListView re-renders

6. User taps track in AudioListView
   └── NavigationLink(value: track) → NowPlayingView(initialTrack: track)

7. NowPlayingView.onAppear
   └── AppStore.playTrack(track)

8. AppStore.playTrack(_:)
   ├── FileImportService.resolvedPath(for:) → absolute path for current container
   ├── AudioPlayerService.load(track:) → AudioEnginePlayer.load(filePath:)
   │   ├── AVAudioFile opened at absolute path
   │   ├── PlayerNode connected to MainMixerNode with file's format
   │   ├── FFT tap installed on MainMixerNode
   │   └── AVAudioEngine.start()
   ├── AudioPlayerService.play() → playerNode.play() + scheduleSegment()
   │   └── Audio begins playing
   └── AppStore.loadWaveform(absolutePath:) [Task, background]

9. Every 100ms: DispatchSourceTimer fires
   └── onStateChanged → AudioPlayerService.$currentPositionMs, $playbackState
       └── Combine .assign → AppStore.$currentPositionMs → WaveformSeekerView updates

10. Every audio buffer (~11ms): FFT tap fires
    └── onFFTData → AudioPlayerService.$fftData → AppStore.$fftData
        └── VisualizerModel.updateTarget(bands) → CADisplayLink lerp → Canvas redraw

11. AppStore.loadWaveform [background Task]
    └── WaveformService.generatePeaks(absolutePath:) [Task.detached]
        ├── autoreleasepool { AVAudioFile → AVAudioPCMBuffer → mono Float32 array }
        └── WaveformCppBridge.generatePeaks(fromBuffer:...) [C++]
            └── 300-point RMS normalization → [Float] in [0, 1]
    └── AppStore.$waveformPeaks → WaveformSeekerView renders full waveform

12. Track ends: playerNode scheduleSegment completion callback
    └── AudioPlayerService.onTrackCompleted?()
        └── AppStore.playNext()
            └── Loops back to step 8 with next track in tracks array
```
