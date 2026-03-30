#!/data/data/com.termux/files/usr/bin/bash
############################################
# CameraLive - Startup Script for Termux
# Uses ffmpeg + python HTTP server + cloudflared
############################################

RTSP_USER="ankitgupta780"
RTSP_PASS="0j23maqt546"
RTSP_PATH="/stream1"
RTSP_PORT=554
CAMERA_MAC="34:60:f9:1b:dc:70"
CAMERA_IP="192.168.1.10"
HLS_DIR="$HOME/hls"
HLS_PORT=8888
LAST_KNOWN_IP_FILE="$HOME/.cameralive_last_ip"

# Load last known working IP if available
if [ -f "$LAST_KNOWN_IP_FILE" ]; then
    SAVED_IP=$(cat "$LAST_KNOWN_IP_FILE")
    if [ -n "$SAVED_IP" ]; then
        CAMERA_IP="$SAVED_IP"
    fi
fi

# Pre-flight checks
echo "========================================="
echo "  CameraLive - Pre-flight Checks"
echo "========================================="

command -v ffmpeg >/dev/null 2>&1 || { echo "ERROR: ffmpeg not found. Run: pkg install ffmpeg"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found. Run: pkg install python"; exit 1; }
command -v cloudflared >/dev/null 2>&1 || { echo "ERROR: cloudflared not found."; exit 1; }

echo "All tools found."

# Kill any leftover processes from previous runs
pkill -f "ffmpeg.*rtsp" 2>/dev/null
pkill -f "http.server $HLS_PORT" 2>/dev/null
pkill -f "cloudflared" 2>/dev/null
sleep 1

# Clean and create HLS directory
rm -rf "$HLS_DIR"
mkdir -p "$HLS_DIR"

# Copy web pages into HLS directory so they're served by the tunnel
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR"/warehouse-live.html "$HLS_DIR/" 2>/dev/null
cp "$SCRIPT_DIR"/camera.html "$HLS_DIR/" 2>/dev/null

echo ""
echo "========================================="
echo "  CameraLive - Starting Services"
echo "========================================="

SHUTTING_DOWN=0

cleanup() {
    [ "$SHUTTING_DOWN" -eq 1 ] && return
    SHUTTING_DOWN=1
    echo ""
    echo "Shutting down..."
    # Kill the ffmpeg loop subshell and all its children
    [ -n "$FFMPEG_LOOP_PID" ] && kill "$FFMPEG_LOOP_PID" 2>/dev/null
    # Kill any remaining ffmpeg processes
    pkill -f "ffmpeg.*rtsp" 2>/dev/null
    pkill -f "http.server $HLS_PORT" 2>/dev/null
    pkill -f "cloudflared" 2>/dev/null
    # Kill all child processes of this script
    kill $(jobs -p) 2>/dev/null
    wait 2>/dev/null
    rm -rf "$HLS_DIR"
    echo "Stopped."
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# Build RTSP URL from current camera IP
build_rtsp_url() {
    echo "rtsp://${RTSP_USER}:${RTSP_PASS}@${CAMERA_IP}:${RTSP_PORT}${RTSP_PATH}"
}

# Auto-discover camera IP by scanning network for its MAC address
discover_camera() {
    echo "[scan] Camera not at $CAMERA_IP. Scanning network for MAC $CAMERA_MAC..."

    # Get the phone's subnet (e.g., 192.168.1)
    SUBNET=$(ip route | grep "dev wlan0" | grep -oP '\d+\.\d+\.\d+\.' | head -1)
    if [ -z "$SUBNET" ]; then
        SUBNET="192.168.1."
    fi
    echo "[scan] Scanning subnet ${SUBNET}0/24..."

    # Ping sweep to populate ARP table (send pings in parallel)
    for i in $(seq 1 254); do
        ping -c 1 -W 1 "${SUBNET}${i}" > /dev/null 2>&1 &
    done
    # Wait for ping sweep to finish (max 10s)
    sleep 6

    # Search ARP table for camera MAC
    FOUND_IP=""
    # Try 'ip neigh' first (most common on Termux)
    if command -v ip > /dev/null 2>&1; then
        FOUND_IP=$(ip neigh 2>/dev/null | grep -i "${CAMERA_MAC}" | awk '{print $1}' | head -1)
    fi
    # Fallback to 'arp' command
    if [ -z "$FOUND_IP" ] && command -v arp > /dev/null 2>&1; then
        FOUND_IP=$(arp -a 2>/dev/null | grep -i "${CAMERA_MAC}" | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1)
    fi
    # Fallback to /proc/net/arp
    if [ -z "$FOUND_IP" ]; then
        FOUND_IP=$(grep -i "${CAMERA_MAC}" /proc/net/arp 2>/dev/null | awk '{print $1}' | head -1)
    fi

    if [ -n "$FOUND_IP" ]; then
        echo "[scan] FOUND camera at $FOUND_IP (MAC: $CAMERA_MAC)"
        CAMERA_IP="$FOUND_IP"
        echo "$CAMERA_IP" > "$LAST_KNOWN_IP_FILE"
        return 0
    else
        echo "[scan] Camera MAC $CAMERA_MAC not found on network."
        echo "[scan] Make sure camera is powered on and connected to WiFi."
        return 1
    fi
}

# Start ffmpeg with auto-restart loop
start_ffmpeg() {
    trap 'exit 0' TERM INT
    ATTEMPT=0
    SCAN_DONE=0
    while true; do
        ATTEMPT=$((ATTEMPT + 1))
        echo ""
        echo "-----------------------------------------"
        echo "[attempt #$ATTEMPT] $(date '+%Y-%m-%d %H:%M:%S')"
        echo "-----------------------------------------"

        # Step 1: Check if camera IP is reachable
        echo "[diag] Pinging camera at $CAMERA_IP..."
        if ping -c 1 -W 3 "$CAMERA_IP" > /dev/null 2>&1; then
            echo "[diag] PING OK - $CAMERA_IP is reachable"
            SCAN_DONE=0
        else
            echo "[diag] PING FAILED - $CAMERA_IP is NOT reachable"
            # Auto-scan network to find camera's new IP
            if discover_camera; then
                echo "[diag] Retrying with new IP $CAMERA_IP..."
                continue
            else
                if [ "$SCAN_DONE" -lt 3 ]; then
                    SCAN_DONE=$((SCAN_DONE + 1))
                    echo "[diag] Will scan again in 10s... (scan $SCAN_DONE/3)"
                    sleep 10 &
                    wait $!
                else
                    echo "[diag] Camera not found after 3 scans. Waiting 30s..."
                    SCAN_DONE=0
                    sleep 30 &
                    wait $!
                fi
                continue
            fi
        fi

        # Step 2: Check if RTSP port is open
        echo "[diag] Checking RTSP port $RTSP_PORT..."
        if (echo > /dev/tcp/"$CAMERA_IP"/"$RTSP_PORT") 2>/dev/null; then
            echo "[diag] PORT OK - RTSP port $RTSP_PORT is open"
        else
            echo "[diag] PORT FAILED - RTSP port $RTSP_PORT is closed"
            echo "[diag] Retrying in 5s..."
            sleep 5 &
            wait $!
            continue
        fi

        # Step 3: Run ffmpeg
        RTSP_URL=$(build_rtsp_url)
        echo "[ffmpeg] Connecting to camera at $CAMERA_IP..."
        rm -f "$HLS_DIR"/*.ts "$HLS_DIR"/*.m3u8 2>/dev/null
        ffmpeg -rtsp_transport tcp \
            -fflags +genpts+discardcorrupt \
            -i "$RTSP_URL" \
            -c:v copy -c:a aac \
            -f hls \
            -hls_time 2 \
            -hls_list_size 5 \
            -hls_flags delete_segments+append_list \
            -hls_segment_filename "$HLS_DIR/seg_%03d.ts" \
            "$HLS_DIR/stream.m3u8" \
            -loglevel error 2>&1
        EXIT_CODE=$?
        echo "[ffmpeg] Exited with code $EXIT_CODE. Reconnecting in 5s..."
        sleep 5 &
        wait $!
    done
}
start_ffmpeg &
FFMPEG_LOOP_PID=$!

# Wait for first HLS segment to appear
echo ""
echo "Camera MAC: $CAMERA_MAC"
echo "Starting IP: $CAMERA_IP (auto-updates if IP changes)"
echo ""
echo "Waiting for camera stream..."
for i in $(seq 1 30); do
    if [ -f "$HLS_DIR/stream.m3u8" ]; then
        echo "Stream is live!"
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "WARNING: No stream after 30s. Will keep trying in background."
    fi
    sleep 1
done

# Start Python HTTP server to serve HLS files
echo "Starting HTTP server on port $HLS_PORT..."
cd "$HLS_DIR" || { echo "ERROR: Cannot cd to $HLS_DIR"; exit 1; }
python3 -m http.server "$HLS_PORT" --bind 0.0.0.0 > /dev/null 2>&1 &
HTTP_PID=$!
cd - > /dev/null
sleep 2

if ! kill -0 $HTTP_PID 2>/dev/null; then
    echo "ERROR: HTTP server failed to start!"
    exit 1
fi
echo "HTTP server running on port $HLS_PORT"

# Start Cloudflare Named Tunnel
echo "Starting Cloudflare Tunnel (live.sale91.com)..."
CF_LOG="$HOME/.cf_tunnel.log"
TUNNEL_TOKEN="eyJhIjoiMjUzZjYzYjRhNTJhM2ViOTYxOGI3M2JjYjU4MmNjNGUiLCJ0IjoiNzFjNWYyMTgtMzc3Yi00MjA3LWFjNDQtZmZiMjhjNTA2NzlmIiwicyI6Ik5USTJOemhoWkdFdE5EWTJNeTAwWmpFMExUbGlNVGd0WWpRek16a3lORGhqTkRrMSJ9"
cloudflared tunnel run --token "$TUNNEL_TOKEN" > "$CF_LOG" 2>&1 &
CF_PID=$!

# Wait for tunnel to connect
sleep 5

echo ""
echo "========================================="
echo "  STREAM IS LIVE!"
echo ""
echo "  Warehouse Trust Page (share this with buyers):"
echo "  https://live.sale91.com/warehouse-live.html"
echo ""
echo "  Raw stream (for VLC):"
echo "  https://live.sale91.com/stream.m3u8"
echo "========================================="
echo ""
echo "Press Ctrl+C to stop."
echo ""

# Keep running quietly
while [ "$SHUTTING_DOWN" -eq 0 ]; do
    if ! kill -0 $FFMPEG_LOOP_PID 2>/dev/null && [ "$SHUTTING_DOWN" -eq 0 ]; then
        start_ffmpeg &
        FFMPEG_LOOP_PID=$!
    fi
    sleep 10 &
    wait $!
done
