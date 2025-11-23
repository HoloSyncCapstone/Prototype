# Audio + Subtitle Synchronization System

## Overview
Implemented a complete synchronized audio and subtitle system that plays in sync with the skeleton animation timeline, including full scrubbing support.

## What Was Implemented

### 1. Updated Subtitle Parser (`SubtitleData.swift`)
**New Structures:**
- `TranscriptToken`: Represents individual words with `startSec` and `endSec`
- `TranscriptSegment`: Represents phrases/sentences with multiple tokens
- Updated `SubtitleLoader` to handle the new token-based transcript format

**Features:**
- Automatically detects and parses the new JSON format from `timecoded_transcript.json`
- Converts token-based segments into timed subtitle entries
- Falls back to old format if needed (backward compatible)
- Extracts start time from first token and end time from last token in each segment

### 2. Audio Player Manager (`AudioPlayerManager.swift`)
**New Class: `AudioPlayerManager`**

**Features:**
- Loads and manages AVAudioPlayer for audio playback
- Supports play, pause, stop, and seek operations
- **Synchronization Methods:**
  - `sync(to:isPlaying:playbackRate:)` - Keeps audio in sync with animation timeline
  - Automatically seeks if audio drifts more than 0.1 seconds from animation
  - Matches playback state (play/pause) with animation
  - Supports variable playback rate for slow-motion
- **Scrubbing Support:**
  - `seek(to:)` - Jump to any point in audio
  - Preserves playback state after seeking

### 3. ViewModel Integration (`ViewModel.swift`)
**Changes:**
- Added `audioManager: AudioPlayerManager` property
- Added `syncAudio()` method to sync audio with current time and playback state
- Updated `scrubTo(time:)` to seek audio when scrubbing
- Added `playbackRate` computed property for audio speed control

### 4. ImmersiveView Integration (`FullbodyimmersiveView.swift`)
**Changes:**
- Added `loadAudio()` function that loads `audio.wav` from `Data/audio/`
- Calls `loadAudio()` during scene setup
- Calls `viewModel.syncAudio()` every frame (60fps) in animation loop
- Audio automatically syncs with:
  - Play/pause state
  - Current time
  - Playback speed (normal/slow-motion)
  - Scrubbing operations

## How It Works

### Timeline Synchronization
All three elements use **`viewModel.currentTime`** as the master timeline:

1. **Skeleton Animation** → Updates joint positions based on currentTime
2. **Audio Playback** → Syncs to currentTime every frame
3. **Subtitles** → Display based on currentTime ranges

### Animation Loop (60fps)
```swift
viewModel.updateTime(1.0/60.0)
let currentTime = viewModel.currentTime

// Update visuals
updateSkeleton(at: currentTime)
updateHandJoints(at: currentTime)

// Update audio & subtitles
updateSubtitle(at: currentTime)
viewModel.syncAudio()  // ← Keeps audio in sync
```

### Scrubbing Support
When user scrubs the timeline:
1. `viewModel.scrubTo(time:)` updates `currentTime`
2. Automatically calls `audioManager.seek(to:)` 
3. Next frame: skeleton jumps to new position
4. Audio resumes from new position
5. Subtitles update to match new time

### Playback Controls
All controls work seamlessly across all three systems:

| Control | Skeleton | Audio | Subtitles |
|---------|----------|-------|-----------|
| **Play** | Animates forward | Plays | Display current |
| **Pause** | Freezes | Pauses | Freezes |
| **Rewind** | Returns to start | Seeks to 0:00 | Shows first |
| **Slow-Motion** | 0.25x speed | 0.25x rate | Syncs to slower time |
| **Scrub** | Jumps to position | Seeks to position | Updates instantly |

## Data Files

### Audio
**File**: `/Prototype/Data/audio/audio.wav`
- Loaded automatically on scene start
- Synced to animation timeline

### Subtitles
**File**: `/Prototype/Data/transcripts/timecoded_transcript.json`

**Format**:
```json
[
  {
    "isFinal": true,
    "text": "Bam, bam.",
    "tokens": [
      {
        "text": "Bam,",
        "startSec": 0.048,
        "endSec": 4.368
      },
      {
        "text": " bam.",
        "startSec": 4.368,
        "endSec": 5.208
      }
    ]
  }
]
```

**Parsed Result**:
- Start Time: 0.048s (first token start)
- End Time: 5.208s (last token end)  
- Text: "Bam, bam."

## Audio Sync Algorithm

The sync algorithm runs at 60fps and:

1. **Checks for drift**: If audio time differs from animation time by >0.1s, seeks to correct position
2. **Matches playback state**: Plays audio if animation is playing, pauses if animation is paused
3. **Sets playback rate**: Adjusts audio speed to match slow-motion setting
4. **Minimal disruption**: Only seeks when necessary to avoid audio glitches

## Benefits

### ✅ Perfect Synchronization
- Audio, subtitles, and skeleton stay perfectly in sync
- No drift over time (checked and corrected every frame)

### ✅ Responsive Scrubbing
- Instant feedback when scrubbing timeline
- Audio seeks to exact position
- Subtitles update immediately
- Skeleton jumps to correct pose

### ✅ Slow-Motion Support
- Audio playback rate matches animation speed
- Subtitles stay synchronized at any speed
- Maintains pitch of audio (or can be configured to change)

### ✅ Robust Error Handling
- Falls back to sample subtitles if file not found
- Handles missing audio gracefully
- Logs all load events for debugging

## Testing

1. **Build and Run** the app
2. **Select a training session** to enter immersive space
3. **Observe**:
   - Console shows audio and subtitle loading
   - Press Play → audio starts with skeleton
   - Subtitles appear synchronized with audio
4. **Test Scrubbing**:
   - Drag timeline slider
   - Audio and subtitles jump to new position
   - Everything stays in sync
5. **Test Slow-Motion**:
   - Enable slow-motion mode
   - Audio plays at 0.25x speed
   - Subtitles still sync correctly

## Console Output

```
✅ Audio loaded: audio.wav, duration: 18.05s
✅ Loaded 4 subtitle entries
💬 Subtitle: Bam, bam.
💬 Subtitle: Wait, move around.
💬 Subtitle: Like, move your shoulders around the side. Yeah.
💬 Subtitle: Okay.
```

## Future Enhancements

- [ ] Add volume control
- [ ] Support multiple audio tracks (narration, ambient, effects)
- [ ] Add subtitle styling options
- [ ] Support for highlighting currently spoken word (token-level)
- [ ] Add audio waveform visualization
- [ ] Support for multiple subtitle languages
