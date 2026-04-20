#!/usr/bin/env bash
# upload.sh NN [--publish-at ISO8601]  — direct YouTube Data API resumable upload fallback.
# Requires: blog-assets/shorts/NN/short-NN.mp4 and shorts/meta/NN.json (snippet+status).
#
# SECRETS: credentials MUST be provided via environment variables. Never hard-code.
#   Required env:
#     YOUTUBE_CLIENT_ID
#     YOUTUBE_CLIENT_SECRET
#     YOUTUBE_REFRESH_TOKEN
#
# The orchestrate-api container already has these set. Load into this shell via:
#   set -a; source <(docker exec orchestrate-api env | grep ^YOUTUBE_); set +a
#
set -e
NN="$1"

REPO="/c/Users/mpolz/Documents/WorldModels"
cd "$REPO"
FILE="blog-assets/shorts/$NN/short-$NN.mp4"
META="shorts/meta/$NN.json"

: "${YOUTUBE_CLIENT_ID:?env YOUTUBE_CLIENT_ID required}"
: "${YOUTUBE_CLIENT_SECRET:?env YOUTUBE_CLIENT_SECRET required}"
: "${YOUTUBE_REFRESH_TOKEN:?env YOUTUBE_REFRESH_TOKEN required}"

TOKEN=$(curl -sS -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=$YOUTUBE_CLIENT_ID" \
  -d "client_secret=$YOUTUBE_CLIENT_SECRET" \
  -d "refresh_token=$YOUTUBE_REFRESH_TOKEN" \
  -d "grant_type=refresh_token" \
  | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>console.log(JSON.parse(d).access_token))")

SIZE=$(stat -c%s "$FILE")

INIT=$(curl -sS -i -X POST \
  "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json; charset=UTF-8" \
  -H "X-Upload-Content-Type: video/mp4" \
  -H "X-Upload-Content-Length: $SIZE" \
  --data-binary @"$META")

URL=$(echo "$INIT" | grep -i "^location:" | sed 's/^[Ll]ocation: //' | tr -d '\r\n')
if [[ -z "$URL" ]]; then
  echo "INIT failed:"; echo "$INIT"; exit 1
fi

RESP=$(curl -sS -X PUT "$URL" -H "Content-Type: video/mp4" --data-binary @"$FILE")
ID=$(echo "$RESP" | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{console.log(JSON.parse(d).id||'NO_ID')}catch(e){console.log('PARSE_FAIL: '+d.slice(0,200))}}")
echo "#$NN id=$ID url=https://www.youtube.com/shorts/$ID"
