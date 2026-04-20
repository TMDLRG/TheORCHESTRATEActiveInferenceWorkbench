#!/usr/bin/env bash
# build.sh — reusable builder for one short.
# Usage: ./shorts/build.sh NN
#   where NN is the 2-digit short number (04, 05, ...)
# Assumes blog-assets/shorts/NN/{narration.mp3, slides/slide-*.html, concat.txt}
# exist, and that slides/_base.css is copied from blog-assets/shorts/01.
# Produces blog-assets/shorts/NN/short-NN.mp4 and copies to the media mount.
set -e
NN="$1"
if [[ -z "$NN" ]]; then echo "usage: $0 NN"; exit 1; fi

REPO="/c/Users/mpolz/Documents/WorldModels"
DIR="$REPO/blog-assets/shorts/$NN"
SLIDES="$DIR/slides"
CHROME="/c/Program Files/Google/Chrome/Application/chrome.exe"
FF="/c/Users/mpolz/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-8.0-full_build/bin/ffmpeg.exe"
MEDIA="/c/Users/mpolz/Documents/ORCHESTRATE Publish/linkedin-orchestrate-campaign/content/media/shorts/$NN"

# Render all slide HTML -> PNG
for html in "$SLIDES"/slide-*.html; do
  name=$(basename "$html" .html)
  SLIDES_WIN="C:/Users/mpolz/Documents/WorldModels/blog-assets/shorts/$NN/slides"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --window-size=1080,1920 --default-background-color=1B1D3Aff \
    "--screenshot=$SLIDES_WIN/$name.png" \
    "file:///$SLIDES_WIN/$name.html" >/dev/null 2>&1
  echo "  rendered $name"
done

cd "$DIR"
echo "  concat -> video.mp4"
MSYS_NO_PATHCONV=1 "$FF" -y -f concat -safe 0 -i concat.txt \
  -vf "scale=1080:1920,format=yuv420p,fps=30" \
  -c:v libx264 -preset medium -crf 20 video.mp4 >/dev/null 2>&1
echo "  mux -> short-$NN.mp4"
MSYS_NO_PATHCONV=1 "$FF" -y -i video.mp4 -i narration.mp3 \
  -c:v copy -c:a aac -b:a 192k -shortest "short-$NN.mp4" >/dev/null 2>&1

DUR=$(MSYS_NO_PATHCONV=1 "$FF" -i "short-$NN.mp4" -hide_banner 2>&1 | grep -i duration | head -1)
SIZE=$(stat -c%s "short-$NN.mp4")
echo "  duration: $DUR"
echo "  size: $SIZE bytes"

mkdir -p "$MEDIA"
cp "short-$NN.mp4" "$MEDIA/short-$NN.mp4"
echo "  copied to media mount: /app/content/media/shorts/$NN/short-$NN.mp4"
