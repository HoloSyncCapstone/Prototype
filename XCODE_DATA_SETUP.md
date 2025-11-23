# Adding Data Folder to Xcode Bundle - Quick Guide

## Problem
Audio and subtitle files exist on disk but aren't found at runtime because they're not included in the app bundle.

## Current Status
✅ Code is ready and working
⚠️ Files need to be added to Xcode project

## Quick Fix (Choose One)

### Option A: Add Folder in Xcode (Recommended)

**Steps:**
1. Open `Prototype.xcodeproj` in Xcode
2. In Project Navigator (left sidebar), right-click on **Prototype** folder
3. Select **"Add Files to 'Prototype'..."**
4. Navigate to and select the **Data** folder
5. **IMPORTANT**: In the dialog:
   - ✅ Check **"Create folder references"** (makes it blue)
   - ❌ Uncheck **"Create groups"** 
   - ✅ Check **"Copy items if needed"** (optional)
   - ✅ Ensure **Target: Prototype** is checked
6. Click **Add**
7. Verify: Data folder appears as **BLUE** folder icon (not yellow)
8. Build and run!

**Why folder references?**
- Blue folder = preserves directory structure
- Yellow folder = flattens all files
- We need `Data/audio/audio.wav` path structure preserved

### Option B: Development Fallback (Already Implemented)

The code now includes a fallback that tries to load files from the project directory if they're not in the bundle. This works for simulator development but won't work for TestFlight or App Store builds.

## Verification

After adding the Data folder, run the app and check console:

### Success:
```
✅ Audio loaded: audio.wav, duration: 18.05s from /path/to/audio.wav
✅ Loaded 4 subtitle entries
💬 Subtitle: Bam, bam.
```

### Still failing:
```
⚠️ Audio file not found: audio.wav in bundle or at direct path
⚠️ Failed to load subtitles from file: fileNotFound
📝 Using sample subtitles as fallback
```

If still failing after adding folder:
1. Clean build folder (Cmd+Shift+K)
2. Delete app from simulator
3. Build and run again

## Files That Will Be Loaded

Once added, these files will be accessible:
- `/Data/audio/audio.wav` (3.2 MB)
- `/Data/transcripts/timecoded_transcript.json` (2 KB)
- All other Data subfolders preserved

## Alternative: Add Files Individually

If folder reference doesn't work:

1. Right-click Prototype folder → "Add Files..."
2. Select `audio.wav` from `Prototype/Data/audio/`
3. Check "Copy items if needed"
4. Repeat for `timecoded_transcript.json` from `Prototype/Data/transcripts/`

Then update code to load from root:
```swift
// In AudioPlayerManager.swift
loadAudio(filename: "audio.wav", subdirectory: "")

// In SubtitleLoader.swift  
url = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "")
```

## Script Helper

Run the included script for detailed instructions:
```bash
./add_data_folder.sh
```

This will show you exactly what to do in Xcode.
