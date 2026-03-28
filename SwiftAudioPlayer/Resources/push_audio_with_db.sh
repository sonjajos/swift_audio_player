#!/bin/bash
# Push audio samples to the iOS Simulator's app container AND import to database.
# Usage: ./push_audio_with_db.sh
# Source: ~/Desktop/music (sample1.mp3 - sample12.mp3)

BUNDLE_ID="com.master.SwiftAudioPlayer"  # Update this to match your actual bundle ID
SOURCE_DIR="$HOME/Desktop/music"

# Verify source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory not found: $SOURCE_DIR"
    echo "Please create $SOURCE_DIR and add audio files there"
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
DB_PATH="$APP_DATA/Documents/audio_tracks.db"

echo "📁 App container: $APP_DATA"
echo "🎵 Audio directory: $AUDIO_DIR"
echo "💾 Database: $DB_PATH"
echo ""

# Create audio_files directory if it doesn't exist
mkdir -p "$AUDIO_DIR"

# Copy all audio files from source
COPIED=0
FILE_LIST=()

echo "📋 Copying files..."
for ext in mp3 m4a wav aiff aac flac; do
    for file in "$SOURCE_DIR"/*.$ext; do
        [ -f "$file" ] || continue
        
        BASENAME=$(basename "$file")
        DEST="$AUDIO_DIR/$BASENAME"
        
        cp "$file" "$DEST"
        echo "  ✅ Copied: $BASENAME"
        
        FILE_LIST+=("$BASENAME")
        COPIED=$((COPIED + 1))
    done
done

if [ $COPIED -eq 0 ]; then
    echo "❌ Warning: No audio files found in $SOURCE_DIR"
    echo "Supported formats: .mp3, .m4a, .wav, .aiff, .aac, .flac"
    exit 1
fi

echo ""
echo "✅ Copied $COPIED file(s) to app container"
echo ""
echo "📱 Files in audio_files/:"
ls -lh "$AUDIO_DIR/"
echo ""

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
    echo "⚠️  Database not found. App will create it on launch."
    echo ""
    echo "To trigger import:"
    echo "1. Force quit the app in the simulator"
    echo "2. Relaunch the app"
    echo "3. Files will be scanned and imported automatically"
    echo ""
    exit 0
fi

echo "💾 Database found. Checking contents..."
echo ""

# Query database to see what's already there
EXISTING_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM audio_tracks;" 2>/dev/null || echo "0")
echo "📊 Tracks currently in database: $EXISTING_COUNT"

if [ "$EXISTING_COUNT" -gt 0 ]; then
    echo ""
    echo "Existing tracks:"
    sqlite3 "$DB_PATH" "SELECT title, artist FROM audio_tracks ORDER BY date_added DESC;" 2>/dev/null | while read line; do
        echo "  - $line"
    done
fi

echo ""
echo "⚠️  Note: Files are copied but NOT yet in the database!"
echo ""
echo "The app scans Documents/audio_files/ on launch and imports missing files."
echo ""
echo "To trigger the import:"
echo "1. Force quit the app: xcrun simctl terminate booted $BUNDLE_ID"
echo "2. Relaunch: xcrun simctl launch booted $BUNDLE_ID"
echo ""
echo "Or manually in simulator:"
echo "1. Double-press home (⌘⇧H twice)"
echo "2. Swipe up on the app"
echo "3. Tap the app icon to relaunch"
echo ""
