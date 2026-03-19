#!/data/data/com.termux/files/usr/bin/bash
############################################
# CameraLive - Startup Script for Termux
# Launches services inside proot Ubuntu
############################################

proot-distro login ubuntu -- bash -c '
echo "========================================="
echo "  CameraLive - Starting Services"
echo "========================================="

cleanup() {
    echo "Shutting down..."
    kill $MTX_PID $CF_PID 2>/dev/null
    exit 0
}
trap cleanup SIGINT SIGTERM

echo "Starting MediaMTX..."
./mediamtx ./mediamtx.yml &
MTX_PID=$!
sleep 3

if ! kill -0 $MTX_PID 2>/dev/null; then
    echo "ERROR: MediaMTX failed to start!"
    exit 1
fi
echo "MediaMTX running!"

echo "Starting Cloudflare Tunnel..."
./cloudflared tunnel --url http://127.0.0.1:8888 &
CF_PID=$!
sleep 5

echo ""
echo "========================================="
echo "  LOOK ABOVE for your tunnel URL!"
echo "  It looks like:"
echo "  https://xxxxx-xxxxx.trycloudflare.com"
echo "========================================="
echo ""
echo "Press Ctrl+C to stop."
wait
'
