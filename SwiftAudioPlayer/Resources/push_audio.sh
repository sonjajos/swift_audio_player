#!/bin/bash
# Push audio samples to the iOS Simulator's app container.
# Usage: ./push_audio.sh
# Source: ~/Desktop/music (sample1.mp3 - sample12.mp3)

BUNDLE_ID="com.master.SwiftAudioPlayer"
SOURCE_DIR="$HOME/Desktop/music"

# Verify source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory not found: $SOURCE_DIR"
    echo "Please create $SOURCE_DIR and add .mp3 files there"
    exit 1
fi

# Verify simulator is booted
APP_DATA=$(xcrun simctl get_app_container booted "$BUNDLE_ID" data 2>/dev/null)
if [ -z "$APP_DATA" ]; then
    echo "Error: Could not find app container. Is the simulator running and app installed?"
    echo ""
    echo "To fix this:"
    echo "1. Launch the iOS Simulator"
    echo "2. Build and run the app (⌘R in Xcode)"
    echo "3. Wait for the app to appear on the simulator"
    echo "4. Run this script again"
    exit 1
fi

AUDIO_DIR="$APP_DATA/Documents/audio_files"

# Wipe and recreate to avoid duplicates or stale files
rm -rf "$AUDIO_DIR"
mkdir -p "$AUDIO_DIR"

# Copy all audio files from source (mp3, m4a, wav, aiff, etc.)
COPIED=0

# Copy MP3 files
for file in "$SOURCE_DIR"/*.mp3; do
    [ -f "$file" ] || continue
    cp "$file" "$AUDIO_DIR/"
    echo "Copied: $(basename "$file")"
    COPIED=$((COPIED + 1))
done

# Copy M4A files
for file in "$SOURCE_DIR"/*.m4a; do
    [ -f "$file" ] || continue
    cp "$file" "$AUDIO_DIR/"
    echo "Copied: $(basename "$file")"
    COPIED=$((COPIED + 1))
done

# Copy WAV files
for file in "$SOURCE_DIR"/*.wav; do
    [ -f "$file" ] || continue
    cp "$file" "$AUDIO_DIR/"
    echo "Copied: $(basename "$file")"
    COPIED=$((COPIED + 1))
done

# Copy AIFF files
for file in "$SOURCE_DIR"/*.aiff; do
    [ -f "$file" ] || continue
    cp "$file" "$AUDIO_DIR/"
    echo "Copied: $(basename "$file")"
    COPIED=$((COPIED + 1))
done

if [ $COPIED -eq 0 ]; then
    echo "Warning: No audio files found in $SOURCE_DIR"
    echo "Supported formats: .mp3, .m4a, .wav, .aiff"
    exit 1
fi

echo ""
echo "✅ Done. $COPIED file(s) copied to app container:"
ls -lh "$AUDIO_DIR/"
echo ""
echo "Files are in: $AUDIO_DIR"
echo ""
echo "⚠️  Note: These files are NOT in the database yet!"
echo ""
echo "To see them in the app:"
echo "1. Force quit the app in the simulator (⌘⇧H twice, swipe up)"
echo "2. Relaunch the app"
echo "3. The app will scan Documents/audio_files/ on launch"
echo "4. Files will be imported into the database automatically"
echo ""
echo "Or run this to trigger the import manually:"
echo "xcrun simctl launch booted $BUNDLE_ID"
