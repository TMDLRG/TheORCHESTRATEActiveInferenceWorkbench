#!/usr/bin/env bash
# Render each slide .html to a 1080x1920 PNG via Chrome headless.
set -e
CHROME="/c/Program Files/Google/Chrome/Application/chrome.exe"
DIR="$(cd "$(dirname "$0")" && pwd)"
DIR_WIN="C:/Users/mpolz/Documents/WorldModels/blog-assets/shorts/01/slides"
for html in "$DIR"/slide-*.html; do
  name=$(basename "$html" .html)
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --window-size=1080,1920 \
    --screenshot="$DIR_WIN/$name.png" \
    "file:///$DIR_WIN/$name.html" 2>&1 | tail -1
done
ls "$DIR"/*.png
