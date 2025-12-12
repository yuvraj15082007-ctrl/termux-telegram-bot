#!/data/data/com.termux/files/usr/bin/bash

# ==============================
#        CONFIGURATION
# ==============================
BOT_TOKEN="paste_YOUR_TOKEN_HERE"
CHAT_ID="PASTE_YOUR_CHAT_ID_HERE"

API="https://api.telegram.org/bot${BOT_TOKEN}"
WORKDIR="/data/data/com.termux/files/home"
OFFSET_FILE="$WORKDIR/offset.txt"
TMP_DIR="$WORKDIR/track_tmp"
LOG_FILE="$WORKDIR/bot.log"
mkdir -p "$TMP_DIR"

# Camera Path
CAM_DIR="$HOME/storage/dcim/Camera"

get_offset() { [ -f "$OFFSET_FILE" ] && cat "$OFFSET_FILE" || echo 0; }
save_offset() { echo "$1" > "$OFFSET_FILE"; }
log_cmd() { echo "$(date '+%F %T') CMD: $1" >> "$LOG_FILE"; }

# ==============================
#     TELEGRAM API SENDERS
# ==============================

send_text() {
  curl -s -X POST "$API/sendMessage" -d chat_id="$CHAT_ID" --data-urlencode text="$1" >/dev/null
}
send_photo() {
  curl -s -X POST "$API/sendPhoto" -F chat_id="$CHAT_ID" -F photo=@"$1" >/dev/null
}
send_audio() {
  curl -s -X POST "$API/sendAudio" -F chat_id="$CHAT_ID" -F audio=@"$1" >/dev/null
}
send_video() {
  curl -s -X POST "$API/sendVideo" -F chat_id="$CHAT_ID" -F video=@"$1" >/dev/null
}
send_document() {
  curl -s -X POST "$API/sendDocument" -F chat_id="$CHAT_ID" -F document=@"$1" >/dev/null
}

# ==============================
#          HELP MENU
# ==============================
do_send_help() {
  local MSG="🤖 *ULTIMATE TERMUX BOT (v5.1)*

📍 *Tracking*
/loc – Current Location (Best Effort)

📸 *Media & Cam*
/photo [back|front] – Take Photo (default = back)
/lastphoto – Get Last Camera Photo
/lastvideo – Get Last Video
/audio – Record 30s Audio
/screen [sec] – Record Screen (best-effort)

📂 *Files & Storage*
/ls [path] – List Files
/sendfile [path] – Download File
/zipphotos [N] – Zip Last N Photos
/storage – Disk Usage

🌐 *Network & Wi-Fi*
/ip – Public/Local IP
/ping [host] – Ping Test
/speed – Speedtest (Needs python)
/wifiscan – Scan Wi-Fi networks

🎵 *Music / Autoplay*
/play [name|path] – Play a song (smart search)
/autoplay [path] – Start infinite autoplay from folder (default: /sdcard/Music)
/stopautoplay – Stop autoplay (only this command stops the loop)

📱 *System & Info*
/status – Battery % 
/apps – Installed Apps List
/info – Device model & uptime
/heat – Battery temp
/clip – Read Clipboard
/active – Notification history

🛠️ *Controls*
/speak [text] – TTS Speak
/torch [on/off] – Flashlight
/vibrate [ms] – Vibrate
/ring [sec] – Find Phone
/vol [max|mute|N] – Volume control
/play [file] – Play audio
/stop – Stop playback
/restart – Restart bot

⚙️ *Notes & Setup*
• Run: termux-setup-storage  
• Install: pkg install termux-api jq ffmpeg zip curl python && pip install speedtest-cli  
• Give Termux Camera/Mic/Storage permissions for media features."

  curl -s -X POST "$API/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d parse_mode="Markdown" \
    --data-urlencode text="$MSG" >/dev/null
}

# ==============================
#      WIFI & NOTIFICATIONS
# ==============================

do_wifi_scan() {
  send_text "📡 Scanning Wi-Fi (GPS must be ON)..."
  local SCAN=$(termux-wifi-scaninfo 2>/dev/null)
  if [ -z "$SCAN" ] || [ "$SCAN" == "[]" ]; then
    send_text "⚠️ No networks found (Check GPS/Permission)."
    return
  fi
  local LIST=$(echo "$SCAN" | jq -r '.[] | "*\(.ssid)* (\(.frequency)MHz) 📶 \(.rssi) dBm"' | head -n 15)
  send_text "📡 *Wi-Fi Networks:*\n\n$LIST"
}

# ==============================
#      SCREEN RECORDING
# ==============================

do_record_screen() {
  local DURATION="${1:-5}"
  if ! echo "$DURATION" | grep -qE '^[0-9]+$'; then DURATION=5; fi
  if [ "$DURATION" -gt 30 ]; then DURATION=30; fi

  send_text "🎥 Recording screen for ${DURATION}s..."
  local FILE="$TMP_DIR/screen_$(date +%s).mp4"
  /system/bin/screenrecord --time-limit "$DURATION" "$FILE" >/dev/null 2>&1

  if [ -f "$FILE" ] && [ -s "$FILE" ]; then
    send_video "$FILE"
    rm "$FILE"
  else
    send_text "⚠️ Recording failed (Root likely required on Android 10+)."
    rm -f "$FILE"
  fi
}

# ==============================
#           LOCATION
# ==============================
do_send_photo() {
  local MODE="$1"
  local CAM=""
  local LABEL=""

  case "$MODE" in
    back|"")
      CAM=0         # usually back camera
      LABEL="Back"
      ;;
    front)
      CAM=1         # usually front camera
      LABEL="Front"
      ;;
    *)
      send_text "⚠️ Usage: /photo back  OR  /photo front"
      return
      ;;
  esac

  local FILE="$TMP_DIR/photo_${LABEL}_$(date +%s).jpg"
  local OUT
  OUT=$(termux-camera-photo -c "$CAM" "$FILE" 2>&1)

  if [ -f "$FILE" ]; then
    send_text "📸 ${LABEL} camera photo..."
    send_photo "$FILE"
    rm -f "$FILE"
  else
    send_text "⚠️ ${LABEL} camera failed:\n$OUT"
  fi
}
do_send_location() {
  local FILE="$TMP_DIR/loc.json"
  termux-location -r once > "$FILE" 2>&1
  if [ ! -f "$FILE" ]; then send_text "⚠️ Location failed."; return; fi
  local RAW=$(cat "$FILE")
  if ! echo "$RAW" | jq empty >/dev/null 2>&1; then send_text "⚠️ Error:\n$RAW"; return; fi
  local LAT=$(echo "$RAW" | jq -r '.latitude // empty')
  local LON=$(echo "$RAW" | jq -r '.longitude // empty')
  if [ -z "$LAT" ]; then send_text "⚠️ Location unavailable."; return; fi

  local MSG="📍 *Location:*
Lat: \`$LAT\`
Lon: \`$LON\`
🔗 [Map](https://maps.google.com/?q=${LAT},${LON})"
  curl -s -X POST "$API/sendMessage" -d chat_id="$CHAT_ID" -d parse_mode="Markdown" --data-urlencode text="$MSG" >/dev/null
}

# ==============================
#         MEDIA FUNCTIONS
# ==============================

do_send_last_photo() {
  [ ! -d "$CAM_DIR" ] && send_text "⚠️ Run termux-setup-storage" && return
  local LAST=$(ls -t "$CAM_DIR"/*.jpg "$CAM_DIR"/*.jpeg 2>/dev/null | head -n1)
  [ -f "$LAST" ] && send_photo "$LAST" || send_text "⚠️ No photos found."
}

do_send_last_video() {
  [ ! -d "$CAM_DIR" ] && send_text "⚠️ Run termux-setup-storage" && return
  local LAST=$(ls -t "$CAM_DIR"/*.mp4 2>/dev/null | head -n1)
  [ -f "$LAST" ] && send_video "$LAST" || send_text "⚠️ No videos found."
}

do_send_audio() {
  local ts=$(date +%s)
  local RAW="$TMP_DIR/audio_${ts}.amr"
  local MP3="$TMP_DIR/audio_${ts}.mp3"
  termux-microphone-record -q >/dev/null 2>&1 || true
  termux-microphone-record -l 30 -f "$RAW" >/dev/null 2>&1
  sleep 32
  if [ ! -f "$RAW" ]; then send_text "⚠️ Rec failed."; return; fi
  if [ $(stat -c%s "$RAW") -lt 2000 ]; then send_text "⚠️ Mic blocked."; rm "$RAW"; return; fi
  ffmpeg -y -i "$RAW" -ar 22050 -ac 1 "$MP3" >/dev/null 2>&1
  [ -f "$MP3" ] && send_audio "$MP3" && rm "$RAW" "$MP3" || send_text "⚠️ Convert failed."
}

# ==============================
#        SYSTEM & APPS
# ==============================

do_send_apps_list() {
  local APPS=$(pm list packages 2>/dev/null | sed 's/package://g' | sort)
  if [ -z "$APPS" ]; then send_text "⚠️ Cannot get apps list."; return; fi
  local HEAD=$(echo "$APPS" | head -n 50)
  local MSG="📦 *Installed Apps*
First 50:
\`\`\`
$HEAD
\`\`\`"
  curl -s -X POST "$API/sendMessage" -d chat_id="$CHAT_ID" -d parse_mode="Markdown" --data-urlencode text="$MSG" >/dev/null
}
do_send_info() {
  # basic device info (use getprop where available)
  local MODEL=$(getprop ro.product.model 2>/dev/null || echo "N/A")
  local MAN=$(getprop ro.product.manufacturer 2>/dev/null || echo "N/A")
  local AND_VER=$(getprop ro.build.version.release 2>/dev/null || echo "N/A")
  local SDK=$(getprop ro.build.version.sdk 2>/dev/null || echo "N/A")
  local UPTIME=$(uptime -p 2>/dev/null || echo "N/A")

  # memory (human friendly) - fallback if 'free' missing
  local MEM_INFO="$(free -h 2>/dev/null | awk '/Mem:/ {print $3" / "$2}')"
  [ -z "$MEM_INFO" ] && MEM_INFO="N/A"

  # storage summary: try /data and the shared storage path if present
  local STO_INFO="$(df -h /data 2>/dev/null | awk 'NR==2 {print $3 " used / " $2 " (" $5 " used)"}')"
  if [ -d "/storage/emulated/0" ]; then
    local SD_INFO="$(df -h /storage/emulated/0 2>/dev/null | awk 'NR==2 {print $3 " used / " $2 " (" $5 " used)"}')"
    [ -n "$SD_INFO" ] && STO_INFO="$STO_INFO\n📁 /storage: $SD_INFO"
  fi
  [ -z "$STO_INFO" ] && STO_INFO="N/A"

  # optional network name / IP local if available
  local LOCAL_IP="$(termux-wifi-connectioninfo 2>/dev/null | jq -r '.ip // empty' 2>/dev/null || echo "")"
  [ -z "$LOCAL_IP" ] && LOCAL_IP="N/A"

  # prepare message (Markdown)
  local MSG="📱 *Device Info*
*Model:* $MAN $MODEL
*Android:* $AND_VER (SDK $SDK)
*Uptime:* $UPTIME

*Memory:* $MEM_INFO
*Storage:*
$STO_INFO

*Local IP:* \`$LOCAL_IP\`"

  # send to telegram (same style as other functions)
  curl -s -X POST "$API/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d parse_mode="Markdown" \
    --data-urlencode text="$MSG" >/dev/null
}
do_send_ip_info() {
  local PUB=$(curl -s --max-time 5 icanhazip.com || echo "N/A")
  local LOC=$(termux-wifi-connectioninfo 2>/dev/null | jq -r '.ip // "N/A"')
  send_text "🌐 Public IP: \`$PUB\`\n🏠 Local IP: \`$LOC\`"
}

do_send_clipboard() {
  local C=$(termux-clipboard-get 2>/dev/null)
  [ -z "$C" ] && send_text "📋 Clipboard empty." || send_text "📋 Clip:\n$C"
}

do_send_status() {
  local B=$(termux-battery-status | jq -r '.percentage // "N/A"')
  send_text "🔋 Battery: ${B}%"
}

do_heat() {
  local T=$(termux-battery-status | jq -r '.temperature // ""')
  send_text "🌡️ Temp: ${T}°C"
}

# ==============================
#        CONTROLS
# ==============================

do_speak() {
  [ -z "$1" ] && send_text "⚠️ Usage: /speak text" && return
  termux-tts-speak "$1"
  send_text "🗣️ Spoken."
}

do_torch() {
  case "$1" in
    on) termux-torch on; send_text "🔦 Torch ON";;
    off) termux-torch off; send_text "🔦 Torch OFF";;
    *) send_text "⚠️ Usage: /torch on/off";;
  esac
}

do_vibrate() { termux-vibrate -d "${1:-1000}"; send_text "📳 Vibrated."; }

do_ring_device() {
  local D="${1:-5}"
  send_text "🔔 Ringing ${D}s..."
  for ((i=0;i<D;i++)); do
    termux-notification --title "FIND ME" --content "Ringing..." --sound >/dev/null
    sleep 1
  done
  send_text "🔔 Stopped."
}

do_volume() {
  if ! command -v termux-volume >/dev/null 2>&1; then send_text "⚠️ missing termux-volume"; return; fi
  local VAL="$1"
  case "$VAL" in
    max) VAL=15 ;;
    mute) VAL=0 ;;
    *) if ! echo "$VAL" | grep -qE '^[0-9]+$'; then send_text "⚠️ Usage: /vol max | mute | [0-15]"; return; fi ;;
  esac
  [ "$VAL" -gt 15 ] && VAL=15
  [ "$VAL" -lt 0 ] && VAL=0
  termux-volume music "$VAL"
  send_text "🔊 Volume set to Level $VAL."
}

# ==============================
#      FILES & NETWORK
# ==============================

do_storage() { send_text "💽 Storage:\n$(df -h /data /storage/emulated/0)"; }

do_ls() {
  local P="${1:-/sdcard}"
  [ ! -d "$P" ] && send_text "⚠️ Bad path/Permission denied." && return
  send_text "📂 Files in $P:\n$(ls -lh "$P" 2>/dev/null | head -n 40)"
}

do_sendfile() {
  [ ! -f "$1" ] && send_text "⚠️ File not found." && return
  send_text "📎 Sending..."
  send_document "$1"
}

do_zipphotos() {
  local N="${1:-30}"
  [ ! -d "$CAM_DIR" ] && send_text "⚠️ Check storage." && return
  local ZIP="$TMP_DIR/photos_$(date +%s).zip"
  (cd "$CAM_DIR" && zip -q "$ZIP" $(ls -t *.jpg *.jpeg 2>/dev/null | head -n "$N")) 2>/dev/null
  [ -f "$ZIP" ] && send_document "$ZIP" && rm "$ZIP" || send_text "⚠️ Zip failed."
}

do_speed() {
  if ! command -v speedtest-cli >/dev/null; then send_text "⚠️ pip install speedtest-cli"; return; fi
  send_text "🚀 Speedtest running..."
  send_text "🚀 Result:\n$(speedtest-cli --simple 2>&1)"
}

do_ping() { send_text "📡 Ping:\n$(ping -c 3 "${1:-google.com}" 2>&1)"; }

# ------------------------------
# Music search / play helpers
# ------------------------------

# file to store last search results (one per line)
LAST_PLAYLIST="$TMP_DIR/last_song_search.txt"

# /songs: list songs in common folders (first 50)
do_songs() {
  local DIRS=("/sdcard/Music" "/sdcard/Download" "/sdcard" "/sdcard/WhatsApp/Media/WhatsApp Audio")
  local OUT=""
  for d in "${DIRS[@]}"; do
    [ -d "$d" ] && OUT="$OUT$(find "$d" -maxdepth 1 -type f \( -iname '*.mp3' -o -iname '*.m4a' -o -iname '*.wav' -o -iname '*.flac' \) -printf '%f\n' 2>/dev/null | head -n 20)$'\n'"
  done
  [ -z "$OUT" ] && send_text "⚠️ No songs found in common folders. Try /songs /sdcard/Music" && return
  send_text "🎶 Songs (sample):\n$OUT"
}

# Play by index from last search (user sends: /play #3)
play_by_index() {
  local IDX="$1"
  if ! echo "$IDX" | grep -qE '^[0-9]+$'; then
    send_text "⚠️ Usage: /play #<number>  (e.g. /play #2)"
    return
  fi
  IDX=$((IDX+0))
  if [ ! -f "$LAST_PLAYLIST" ]; then
    send_text "⚠️ No previous search found. Use /play <name> to search first."
    return
  fi
  local FILE
  FILE=$(sed -n "${IDX}p" "$LAST_PLAYLIST" 2>/dev/null || true)
  if [ -z "$FILE" ]; then
    send_text "⚠️ Invalid index: $IDX"
    return
  fi

  # play the chosen file
  termux-media-player stop >/dev/null 2>&1
  termux-media-player play "$FILE" >/dev/null 2>&1
  send_text "▶️ Playing: $(basename "$FILE")"
}

# Improved do_play: search & play or reply matches
do_play() {
  local INPUT="$1"
  [ -z "$INPUT" ] && send_text "⚠️ Usage: /play [song name or full path] (or /play #<n> after a search)" && return

  # If user passed "#N"
  if echo "$INPUT" | grep -qE '^#?[0-9]+$'; then
    # allow both "#3" and "3"
    IDX=$(echo "$INPUT" | sed 's/^#//')
    play_by_index "$IDX"
    return
  fi

  # sanitize input (strip surrounding quotes)
  INPUT="${INPUT%\"}"; INPUT="${INPUT#\"}"
  INPUT="${INPUT%\'}"; INPUT="${INPUT#\'}"

  # 1) If exact file path provided
  if [ -f "$INPUT" ]; then
    termux-media-player stop >/dev/null 2>&1
    termux-media-player play "$INPUT" >/dev/null 2>&1
    send_text "▶️ Playing: $(basename "$INPUT")"
    return
  fi

  # 2) Try exact name in common folders (case-sensitive)
  local NAME="$INPUT"
  local NAME_EXT=""
  case "$NAME" in
    *.mp3|*.m4a|*.wav|*.flac|*.aac|*.opus) NAME_EXT="$NAME" ;;
    *) NAME_EXT="${NAME}.mp3" ;;
  esac

  local DIRS=( "/sdcard/Music" "/sdcard/Download" "/sdcard" "/sdcard/DCIM" "/sdcard/Ringtones" "/sdcard/WhatsApp/Media/WhatsApp Audio" )
  local CAND=""
  for d in "${DIRS[@]}"; do
    if [ -f "$d/$NAME" ]; then CAND="$d/$NAME"; break; fi
    if [ -f "$d/$NAME_EXT" ]; then CAND="$d/$NAME_EXT"; break; fi
  done

  if [ -n "$CAND" ]; then
    termux-media-player stop >/dev/null 2>&1
    termux-media-player play "$CAND" >/dev/null 2>&1
    send_text "▶️ Playing: $(basename "$CAND")"
    return
  fi

  # 3) Case-insensitive partial search across /sdcard (fast: limit results)
  send_text "🔎 Searching for: \"$INPUT\" (this may take a moment)..."
  # remove any leading/trailing spaces for find pattern
  local PATTERN="$INPUT"
  # find case-insensitive partial matches; limit to 15
  find /sdcard -type f \( -iname "*$PATTERN*.mp3" -o -iname "*$PATTERN*.m4a" -o -iname "*$PATTERN*.wav" -o -iname "*$PATTERN*.flac" -o -iname "*$PATTERN*.aac" -o -iname "*$PATTERN*.opus" \) 2>/dev/null | head -n 15 > "$LAST_PLAYLIST"

  if [ ! -s "$LAST_PLAYLIST" ]; then
    send_text "⚠️ Not found. Try exact filename or run /songs to list available songs."
    rm -f "$LAST_PLAYLIST"
    return
  fi

  # If only one match -> play it
  local COUNT
  COUNT=$(wc -l < "$LAST_PLAYLIST" | tr -d ' ')
  if [ "$COUNT" -eq 1 ]; then
    local FILE
    FILE=$(head -n1 "$LAST_PLAYLIST")
    termux-media-player stop >/dev/null 2>&1
    termux-media-player play "$FILE" >/dev/null 2>&1
    send_text "▶️ Playing: $(basename "$FILE")"
    rm -f "$LAST_PLAYLIST"
    return
  fi

  # Multiple matches -> send enumerated list for user to pick (#)
  local i=0
  local MSG="🔢 Multiple matches found (send /play #N to choose):\n"
  while IFS= read -r f; do
    MSG="$MSG\n#${i} - $(basename "$f")"
    i=$((i+1))
  done < "$LAST_PLAYLIST"

  send_text "$MSG"
  # keep $LAST_PLAYLIST for index selection
}
# ==============================
#     MAIN LOGIC LOOP
# ==============================

process_updates() {
  local OFFSET RESP OK
  OFFSET=$(get_offset)

  # Long-poll getUpdates (timeout 25s)
  RESP=$(curl -s "$API/getUpdates?offset=$((OFFSET+1))&timeout=25")
  OK=$(echo "$RESP" | jq -r '.ok' 2>/dev/null)

  # If Telegram didn't return ok, bail out
  [ "$OK" != "true" ] && return

  # Iterate over each update
  echo "$RESP" | jq -c '.result[]' 2>/dev/null | while read -r upd; do
    local uid chatid text cmd arg1 arg_rest

    uid=$(echo "$upd" | jq -r '.update_id')
    chatid=$(echo "$upd" | jq -r '.message.chat.id // empty')
    # read text (if none, become empty)
    text=$(echo "$upd" | jq -r '.message.text // empty' | tr -d '\r')

    # If update from other chat, just save offset and skip
    if [ "$chatid" != "$CHAT_ID" ]; then
      save_offset "$uid"
      continue
    fi

# --- extract command and args (robust + strip botname/newlines) ---
# cmd: first word lowercased, remove any @botname, strip CR/LF/extra spaces
cmd=$(echo "$text" | awk '{print tolower($1)}' | sed 's/@.*//g' | tr -d '\r\n' | xargs)

# arg1: second token (raw), strip CR/LF
arg1=$(echo "$text" | awk '{print $2}' | tr -d '\r\n')

# arg_rest: everything after first token, remove CR only (keep newlines removed)
arg_rest=$(echo "$text" | cut -d' ' -f2- | sed 's/\r//g')

# (optional) quick sanity: if cmd is empty, set to unknown so case will fallthrough
[ -z "$cmd" ] && cmd="unknown"
    # log for debugging
    log_cmd "$cmd"

    case "$cmd" in
      "/help"|"help") do_send_help ;;
      "/loc"|"loc") do_send_location ;;
      "/photo"|"photo") do_send_photo "$arg1" ;;   # optionally accept 'front' or 'back'
      "/lastphoto") do_send_last_photo ;;
      "/lastvideo") do_send_last_video ;;
      "/audio"|"audio") send_text "🎙 Recording 30s..."; do_send_audio ;;

      "/screen"|"screen") do_record_screen "$arg1" ;;

     "/info"|"info") do_info ;;
     "/status"|"status") do_send_status ;;
      "/ip"|"ip") do_send_ip_info ;;
      "/clip"|"clip") do_send_clipboard ;;
      "/apps"|"apps") send_text "📦 Fetching apps..." ; do_send_apps_list ;;
      "/heat"|"heat") do_heat ;;

      "/wifiscan") do_wifi_scan ;;
      "/active") do_active_apps ;;

      "/speak"|"speak") do_speak "$arg_rest" ;;
      "/torch"|"torch") do_torch "$arg1" ;;
      "/vibrate"|"vibrate") do_vibrate "$arg1" ;;
      "/ring"|"ring") do_ring_device "$arg1" ;;
      "/vol"|"vol") do_volume "$arg1" ;;

      "/storage"|"storage") do_storage ;;
      "/ls"|"ls") do_ls "$arg1" ;;
      "/sendfile"|"sendfile") do_sendfile "$arg_rest" ;;
      "/zipphotos"|"zipphotos") do_zipphotos "$arg1" ;;

      "/ping"|"ping") do_ping "$arg1" ;;
      "/speed"|"speed") do_speed ;;

      "/play"|"play") do_play "$arg_rest" ;;
      "/stop"|"stop") termux-media-player stop >/dev/null 2>&1; send_text "⏹️ Stopped." ;;

      "/restart"|"restart")
         send_text "♻️ Restarting..."
         save_offset "$uid"   # save offset before exec so updates don't repeat
         exec "$0" "$@"       # restart the script
         ;;

      *) 
         send_text "❓ Unknown command: $cmd\nUse /help"
         ;;
    esac

    # mark this update handled
    save_offset "$uid"
  done
}
send_text "🤖 Bot Started (v5.1 - Restart Loop Fixed)!"
while true; do
  process_updates
  sleep 2
done

