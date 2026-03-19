#!/data/data/com.termux/files/usr/bin/bash
############################################
# CameraLive - One Command Install Script
# Run in Termux on Android phone
# Uses proot-distro (Ubuntu) for compatibility
############################################

set -e

echo "========================================="
echo "  CameraLive Installer for Termux"
echo "========================================="
echo ""

# Update packages
echo "[1/4] Updating Termux packages..."
pkg update -y && pkg upgrade -y

# Install proot-distro
echo "[2/4] Installing proot-distro..."
pkg install -y proot-distro

# Install Ubuntu inside Termux
echo "[3/4] Installing Ubuntu (this takes a few minutes)..."
proot-distro install ubuntu 2>/dev/null || echo "Ubuntu already installed, continuing..."

# Setup everything inside Ubuntu
echo "[4/4] Setting up MediaMTX + cloudflared inside Ubuntu..."
proot-distro login ubuntu -- bash -c '
set -e
apt update -y && apt install -y wget ca-certificates

# Detect architecture
ARCH=$(uname -m)
echo "Detected architecture: $ARCH"

if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    MTX_ARCH="arm64v8"
    CF_ARCH="arm64"
elif [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "armv8l" ]; then
    MTX_ARCH="armv7"
    CF_ARCH="arm"
else
    echo "ERROR: Unsupported architecture: $ARCH"
    exit 1
fi

echo "Downloading MediaMTX ($MTX_ARCH)..."
wget -q --show-progress -O mediamtx.tar.gz "https://github.com/bluenviron/mediamtx/releases/download/v1.11.3/mediamtx_v1.11.3_linux_${MTX_ARCH}.tar.gz"
tar -xzf mediamtx.tar.gz mediamtx
rm mediamtx.tar.gz
chmod +x mediamtx

echo "Downloading cloudflared ($CF_ARCH)..."
wget -q --show-progress -O cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}"
chmod +x cloudflared

# Create mediamtx config
cat > mediamtx.yml << "CONF"
logLevel: info
hlsAddress: :8888
hls: yes
hlsAlwaysRemux: yes
hlsSegmentCount: 3
hlsSegmentDuration: 1s
hlsAllowOrigin: '"'"'*'"'"'
rtspAddress: :8554
api: no
apiAddress: :9997
webrtc: no
paths:
  cam:
    source: rtsp://admin:0j23maqt546@192.168.1.95:554/stream1
    sourceOnDemand: no
CONF

# Create start script
cat > start.sh << "SCRIPT"
#!/bin/bash
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
SCRIPT
chmod +x start.sh

echo ""
echo "========================================="
echo "  Installation Complete!"
echo "========================================="
'

echo ""
echo "========================================="
echo "  ALL DONE! Now run this to start:"
echo ""
echo "  proot-distro login ubuntu -- bash -c ./start.sh"
echo ""
echo "========================================="
