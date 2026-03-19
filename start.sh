#!/data/data/com.termux/files/usr/bin/bash
############################################
# CameraLive - Startup Script for Termux
# Uses ffmpeg + python HTTP server + cloudflared
############################################

RTSP_URL="rtsp://ankitgupta780:0j23maqt546@192.168.1.5:554/stream1"
HLS_DIR="$HOME/hls"
HLS_PORT=8888

mkdir -p "$HLS_DIR"

echo "========================================="
echo "  CameraLive - Starting Services"
echo "========================================="

cleanup() {
    echo ""
    echo "Shutting down..."
    kill $(jobs -p) 2>/dev/null
    rm -rf "$HLS_DIR"
    exit 0
}
trap cleanup SIGINT SIGTERM

# Start ffmpeg with auto-restart loop
start_ffmpeg() {
    while true; do
        echo "Starting ffmpeg (RTSP to HLS)..."
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
            -loglevel warning
        echo "ffmpeg stopped. Restarting in 3 seconds..."
        sleep 3
    done
}
start_ffmpeg &
FFMPEG_PID=$!
sleep 5
echo "ffmpeg running! Converting RTSP to HLS..."

# Start Python HTTP server to serve HLS files
echo "Starting HTTP server on port $HLS_PORT..."
cd "$HLS_DIR"
python3 -m http.server $HLS_PORT --bind 127.0.0.1 &
HTTP_PID=$!
cd - > /dev/null
sleep 2

if ! kill -0 $HTTP_PID 2>/dev/null; then
    echo "ERROR: HTTP server failed to start!"
    kill $FFMPEG_PID 2>/dev/null
    exit 1
fi
echo "HTTP server running!"

# Start Cloudflare Tunnel
echo "Starting Cloudflare Tunnel..."
cloudflared tunnel --url http://127.0.0.1:$HLS_PORT &
CF_PID=$!
sleep 5

echo ""
echo "========================================="
echo "  LOOK ABOVE for your tunnel URL!"
echo "  It looks like:"
echo "  https://xxxxx-xxxxx.trycloudflare.com"
echo ""
echo "  To view stream, open:"
echo "  <tunnel-url>/stream.m3u8"
echo "  in VLC or any HLS player"
echo "========================================="
echo ""
echo "Press Ctrl+C to stop."
wait
