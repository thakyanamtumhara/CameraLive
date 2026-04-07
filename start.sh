#!/data/data/com.termux/files/usr/bin/bash
############################################
# CameraLive - Startup Script for Termux
# Uses ffmpeg + python HTTP server + cloudflared
############################################

RTSP_URL="rtsp://ankitgupta780:0j23maqt546@192.168.1.10:554/stream1"
HLS_DIR="$HOME/hls"
HLS_PORT=8888

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

# Extract camera IP from RTSP URL
CAMERA_IP=$(echo "$RTSP_URL" | sed 's/.*@//;s/:.*//')
CAMERA_PORT=$(echo "$RTSP_URL" | sed 's/.*@[^:]*://;s/\/.*//')

# Start ffmpeg with auto-restart loop
start_ffmpeg() {
    trap 'exit 0' TERM INT
    ATTEMPT=0
    while true; do
        ATTEMPT=$((ATTEMPT + 1))
        echo ""
        echo "-----------------------------------------"
        echo "[attempt #$ATTEMPT] $(date '+%Y-%m-%d %H:%M:%S')"
        echo "-----------------------------------------"

        # Step 1: Check if camera IP is reachable
        echo "[diag] Pinging camera at $CAMERA_IP..."
        if ping -c 1 -W 3 "$CAMERA_IP" > /dev/null 2>&1; then
            echo "[diag] PING OK - Camera IP $CAMERA_IP is reachable"
        else
            echo "[diag] PING FAILED - Camera IP $CAMERA_IP is NOT reachable"
            echo "[diag] Camera may have a new IP. Check your router/Tapo app."
            echo "[diag] Retrying in 5s..."
            sleep 5 &
            wait $!
            continue
        fi

        # Step 2: Check if RTSP port is open
        echo "[diag] Checking RTSP port $CAMERA_PORT..."
        if (echo > /dev/tcp/"$CAMERA_IP"/"$CAMERA_PORT") 2>/dev/null; then
            echo "[diag] PORT OK - RTSP port $CAMERA_PORT is open"
        else
            echo "[diag] PORT FAILED - RTSP port $CAMERA_PORT is closed"
            echo "[diag] Camera RTSP service may not be running."
            echo "[diag] Retrying in 5s..."
            sleep 5 &
            wait $!
            continue
        fi

        # Step 3: Run ffmpeg with visible error output
        echo "[ffmpeg] Connecting to $RTSP_URL"
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
        echo "[ffmpeg] Process exited with code: $EXIT_CODE"
        echo "[ffmpeg] Reconnecting in 5s..."
        sleep 5 &
        wait $!
    done
}
start_ffmpeg &
FFMPEG_LOOP_PID=$!

# Wait for first HLS segment to appear
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
TUNNEL_TOKEN="eyJhIjoiNzQ5NmQ3ZDIzNWVhMDg1NzFiOGEwNDgyOTljMWEyODIiLCJ0IjoiYjk2MTRlMGUtMjczNC00Y2Q5LWEzNDItMWE5YjI1YzIyNDRkIiwicyI6IlpqUmtaVGcwTVRBdE1EazNPUzAwWVdWaExXRXdZalF0WXpGa01HSmpOV1prTURRMiJ9"
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
