#!/data/data/com.termux/files/usr/bin/bash
############################################
# CameraLive - Startup Script
# Runs MediaMTX + Cloudflare Tunnel together
############################################

INSTALL_DIR="$HOME/cameralive"
cd "$INSTALL_DIR"

# Check files exist
if [ ! -f "./mediamtx" ]; then
    echo "ERROR: mediamtx not found. Run install.sh first."
    exit 1
fi

if [ ! -f "./cloudflared" ]; then
    echo "ERROR: cloudflared not found. Run install.sh first."
    exit 1
fi

if [ ! -f "./mediamtx.yml" ]; then
    echo "ERROR: mediamtx.yml not found. Copy it to $INSTALL_DIR/"
    exit 1
fi

# Cleanup function to kill both processes on exit
cleanup() {
    echo ""
    echo "Shutting down..."
    kill "$MEDIAMTX_PID" 2>/dev/null
    kill "$CLOUDFLARED_PID" 2>/dev/null
    wait "$MEDIAMTX_PID" 2>/dev/null
    wait "$CLOUDFLARED_PID" 2>/dev/null
    echo "Stopped."
    exit 0
}
trap cleanup SIGINT SIGTERM

echo "========================================="
echo "  CameraLive - Starting Services"
echo "========================================="
echo ""

# Start MediaMTX
echo "[1/2] Starting MediaMTX (RTSP to HLS converter)..."
./mediamtx ./mediamtx.yml &
MEDIAMTX_PID=$!
sleep 3

# Verify MediaMTX is running
if ! kill -0 "$MEDIAMTX_PID" 2>/dev/null; then
    echo "ERROR: MediaMTX failed to start. Check mediamtx.yml config."
    exit 1
fi
echo "MediaMTX running (PID: $MEDIAMTX_PID)"
echo "Local HLS URL: http://127.0.0.1:8888/cam/"
echo ""

# Start Cloudflare Tunnel
echo "[2/2] Starting Cloudflare Tunnel..."
echo "Waiting for tunnel URL..."
echo ""
./cloudflared tunnel --url http://127.0.0.1:8888 &
CLOUDFLARED_PID=$!
sleep 5

echo ""
echo "========================================="
echo "  Both services are running!"
echo "========================================="
echo ""
echo "Look above for your Cloudflare tunnel URL."
echo "It looks like: https://xxxxx-xxxxx-xxxxx.trycloudflare.com"
echo ""
echo "Your HLS stream URL will be:"
echo "  <tunnel-url>/cam/"
echo ""
echo "Paste that URL into camera.html where it says TUNNEL_URL_HERE"
echo ""
echo "Press Ctrl+C to stop both services."
echo ""

# Wait for either process to exit
wait -n "$MEDIAMTX_PID" "$CLOUDFLARED_PID" 2>/dev/null
echo "A service has stopped. Shutting down..."
cleanup
