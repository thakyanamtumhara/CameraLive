#!/data/data/com.termux/files/usr/bin/bash
############################################
# CameraLive - Startup Script for Termux
# Uses ffmpeg + python HTTP server + cloudflared
############################################

RTSP_URL="rtsp://ankitgupta780:0j23maqt546@192.168.1.8:554/stream1"
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
pkill -f "ffmpeg.*stream1" 2>/dev/null
pkill -f "http.server $HLS_PORT" 2>/dev/null
pkill -f "cloudflared" 2>/dev/null
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
    pkill -f "ffmpeg.*stream1" 2>/dev/null
    pkill -f "http.server $HLS_PORT" 2>/dev/null
    pkill -f "cloudflared" 2>/dev/null
    kill $(jobs -p) 2>/dev/null
    wait 2>/dev/null
    rm -rf "$HLS_DIR"
    echo "Stopped."
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# Start ffmpeg with auto-restart loop (all output silenced)
start_ffmpeg() {
    while true; do
        echo "[ffmpeg] Connecting to camera..."
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
            -loglevel fatal 2>/dev/null
        echo "[ffmpeg] Disconnected. Reconnecting in 3s..."
        sleep 3
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

# Start Cloudflare Tunnel and capture the URL
echo "Starting Cloudflare Tunnel..."
CF_LOG="$HOME/.cf_tunnel.log"
cloudflared tunnel --url http://127.0.0.1:$HLS_PORT > "$CF_LOG" 2>&1 &
CF_PID=$!

# Wait and extract the tunnel URL
TUNNEL_URL=""
for i in $(seq 1 15); do
    TUNNEL_URL=$(grep -o 'https://[a-zA-Z0-9-]*\.trycloudflare\.com' "$CF_LOG" 2>/dev/null | head -1)
    if [ -n "$TUNNEL_URL" ]; then
        break
    fi
    sleep 1
done

echo ""
echo "========================================="
if [ -n "$TUNNEL_URL" ]; then
    echo "  STREAM IS LIVE!"
    echo ""
    echo "  Your URL:"
    echo "  $TUNNEL_URL/stream.m3u8"
    echo ""
    echo "  Open this in VLC or any browser."
    echo "  Or update camera.html with this URL."
else
    echo "  Services running but tunnel URL not found."
    echo "  Check $CF_LOG for the URL."
fi
echo "========================================="
echo ""
echo "Press Ctrl+C to stop."
echo ""

# Keep running quietly
while true; do
    if ! kill -0 $FFMPEG_LOOP_PID 2>/dev/null; then
        start_ffmpeg &
        FFMPEG_LOOP_PID=$!
    fi
    sleep 10
done
