#!/data/data/com.termux/files/usr/bin/bash
############################################
# CameraLive - Startup Script for Termux
# Uses ffmpeg + python HTTP server + cloudflared
############################################

RTSP_URL="rtsp://ankitgupta780:0j23maqt546@192.168.1.5:554/stream1"
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
pkill -f "ffmpeg.*$RTSP_URL" 2>/dev/null
pkill -f "http.server $HLS_PORT" 2>/dev/null
sleep 1

# Clean and create HLS directory
rm -rf "$HLS_DIR"
mkdir -p "$HLS_DIR"

echo ""
echo "========================================="
echo "  CameraLive - Starting Services"
echo "========================================="

cleanup() {
    echo ""
    echo "Shutting down..."
    kill $(jobs -p) 2>/dev/null
    wait 2>/dev/null
    rm -rf "$HLS_DIR"
    echo "Stopped."
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# Test RTSP connection first
echo ""
echo "Testing camera connection..."
if ffmpeg -rtsp_transport tcp -stimeout 5000000 -i "$RTSP_URL" -t 1 -f null - -loglevel error 2>&1; then
    echo "Camera is reachable!"
else
    echo "WARNING: Could not reach camera at $RTSP_URL"
    echo "Check: Is the camera on? Is your phone on the same WiFi?"
    echo "Continuing anyway (will retry)..."
fi

# Start ffmpeg with auto-restart loop
start_ffmpeg() {
    while true; do
        echo "[ffmpeg] Starting RTSP to HLS conversion..."
        rm -f "$HLS_DIR"/*.ts "$HLS_DIR"/*.m3u8 2>/dev/null
        ffmpeg -rtsp_transport tcp \
            -stimeout 5000000 \
            -i "$RTSP_URL" \
            -c:v copy -c:a aac \
            -f hls \
            -hls_time 2 \
            -hls_list_size 5 \
            -hls_flags delete_segments+append_list \
            -hls_segment_filename "$HLS_DIR/seg_%03d.ts" \
            "$HLS_DIR/stream.m3u8" \
            -loglevel warning 2>&1
        echo "[ffmpeg] Stopped (exit code: $?). Restarting in 3s..."
        sleep 3
    done
}
start_ffmpeg &
FFMPEG_LOOP_PID=$!
echo "ffmpeg loop started (PID: $FFMPEG_LOOP_PID)"

# Wait for first HLS segment to appear
echo "Waiting for first HLS segment..."
for i in $(seq 1 30); do
    if [ -f "$HLS_DIR/stream.m3u8" ]; then
        echo "HLS stream ready!"
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "WARNING: No HLS segments after 30s. ffmpeg may be struggling."
        echo "Stream will start when camera connects."
    fi
    sleep 1
done

# Start Python HTTP server to serve HLS files
echo ""
echo "Starting HTTP server on port $HLS_PORT..."
cd "$HLS_DIR" || { echo "ERROR: Cannot cd to $HLS_DIR"; exit 1; }
python3 -m http.server "$HLS_PORT" --bind 0.0.0.0 &
HTTP_PID=$!
cd - > /dev/null
sleep 2

if ! kill -0 $HTTP_PID 2>/dev/null; then
    echo "ERROR: HTTP server failed to start!"
    echo "Port $HLS_PORT may be in use. Run: pkill -f 'http.server $HLS_PORT'"
    exit 1
fi
echo "HTTP server running on port $HLS_PORT (PID: $HTTP_PID)"

# Start Cloudflare Tunnel
echo ""
echo "Starting Cloudflare Tunnel..."
cloudflared tunnel --url http://127.0.0.1:$HLS_PORT 2>&1 &
CF_PID=$!
sleep 8

echo ""
echo "========================================="
echo "  ALL SERVICES RUNNING!"
echo ""
echo "  Look above for your Cloudflare URL:"
echo "  https://xxxxx-xxxxx.trycloudflare.com"
echo ""
echo "  Open in browser or VLC:"
echo "  <tunnel-url>/stream.m3u8"
echo ""
echo "  Or use camera.html with the URL."
echo "========================================="
echo ""
echo "Press Ctrl+C to stop all services."
echo ""

# Keep running and monitor
while true; do
    if ! kill -0 $FFMPEG_LOOP_PID 2>/dev/null; then
        echo "ERROR: ffmpeg loop died! Restarting..."
        start_ffmpeg &
        FFMPEG_LOOP_PID=$!
    fi
    sleep 10
done
