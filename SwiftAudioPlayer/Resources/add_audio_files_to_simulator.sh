#!/bin/bash

# add_audio_files_to_simulator.sh
# Script to download sample audio files and add them to iOS Simulator
# Usage: ./add_audio_files_to_simulator.sh

set -e  # Exit on error

echo "🎵 Audio Files Setup for iOS Simulator"
echo "======================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create temporary directory for downloads
TEMP_DIR="$HOME/Desktop/SimulatorAudioFiles"
mkdir -p "$TEMP_DIR"

echo -e "${BLUE}📁 Created temporary directory: $TEMP_DIR${NC}"
echo ""

# Sample royalty-free audio files from Bensound
# These are short previews (~30 seconds each)
declare -a AUDIO_URLS=(
    "https://www.bensound.com/bensound-music/bensound-ukulele.mp3"
    "https://www.bensound.com/bensound-music/bensound-sunny.mp3"
    "https://www.bensound.com/bensound-music/bensound-creativeminds.mp3"
    "https://www.bensound.com/bensound-music/bensound-acoustic.mp3"
)

declare -a FILE_NAMES=(
    "Ukulele.mp3"
    "Sunny.mp3"
    "Creative Minds.mp3"
    "Acoustic.mp3"
)

# Download audio files
echo -e "${BLUE}⬇️  Downloading sample audio files...${NC}"
echo ""

for i in "${!AUDIO_URLS[@]}"; do
    url="${AUDIO_URLS[$i]}"
    filename="${FILE_NAMES[$i]}"
    output_path="$TEMP_DIR/$filename"
    
    echo "Downloading: $filename"
    curl -L -o "$output_path" "$url" 2>/dev/null || {
        echo -e "${RED}❌ Failed to download $filename${NC}"
        continue
    }
    
    if [ -f "$output_path" ]; then
        file_size=$(ls -lh "$output_path" | awk '{print $5}')
        echo -e "${GREEN}✅ Downloaded $filename ($file_size)${NC}"
    fi
    echo ""
done

echo ""
echo -e "${GREEN}✅ Download complete!${NC}"
echo ""
echo "======================================"
echo "📱 Next Steps:"
echo "======================================"
echo ""
echo "1. Open your iOS Simulator"
echo "2. Drag the files from Desktop/SimulatorAudioFiles"
echo "3. Drop them onto the Simulator window"
echo "4. Files will appear in Files app → Downloads"
echo ""
echo "OR use this automated approach:"
echo ""
echo "   Run: ./install_to_simulator.sh"
echo ""
echo "Files location: $TEMP_DIR"
echo ""

# Ask if user wants to open the folder
read -p "Open the folder now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$TEMP_DIR"
fi

echo ""
echo -e "${GREEN}🎉 Done!${NC}"
