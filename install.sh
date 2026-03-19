#!/data/data/com.termux/files/usr/bin/bash
############################################
# CameraLive - One Command Install Script
# Run in Termux on Android phone
############################################

set -e

echo "========================================="
echo "  CameraLive Installer for Termux"
echo "========================================="
echo ""

# Update packages
echo "[1/5] Updating Termux packages..."
pkg update -y && pkg upgrade -y

# Install required packages
echo "[2/5] Installing dependencies..."
pkg install -y wget tar

# Create working directory
echo "[3/5] Setting up directory..."
INSTALL_DIR="$HOME/cameralive"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Download MediaMTX (ARM64 Linux build for Termux)
echo "[4/5] Downloading MediaMTX..."
MEDIAMTX_VERSION="v1.11.3"
MEDIAMTX_URL="https://github.com/bluenviron/mediamtx/releases/download/${MEDIAMTX_VERSION}/mediamtx_${MEDIAMTX_VERSION}_linux_arm64v8.tar.gz"
wget -q --show-progress -O mediamtx.tar.gz "$MEDIAMTX_URL"
tar -xzf mediamtx.tar.gz mediamtx
rm mediamtx.tar.gz
chmod +x mediamtx

# Download cloudflared (ARM64 Linux build)
echo "[5/5] Downloading cloudflared..."
CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
wget -q --show-progress -O cloudflared "$CLOUDFLARED_URL"
chmod +x cloudflared

# Copy config files from repo (if cloned) or prompt user
if [ -f "$HOME/CameraLive/mediamtx.yml" ]; then
    cp "$HOME/CameraLive/mediamtx.yml" "$INSTALL_DIR/mediamtx.yml"
    echo "Copied mediamtx.yml from repo."
elif [ -f "$(dirname "$0")/mediamtx.yml" ]; then
    cp "$(dirname "$0")/mediamtx.yml" "$INSTALL_DIR/mediamtx.yml"
    echo "Copied mediamtx.yml from script directory."
else
    echo ""
    echo "WARNING: mediamtx.yml not found."
    echo "Please copy mediamtx.yml to $INSTALL_DIR/"
fi

# Copy start script
if [ -f "$HOME/CameraLive/start.sh" ]; then
    cp "$HOME/CameraLive/start.sh" "$INSTALL_DIR/start.sh"
    chmod +x "$INSTALL_DIR/start.sh"
    echo "Copied start.sh from repo."
elif [ -f "$(dirname "$0")/start.sh" ]; then
    cp "$(dirname "$0")/start.sh" "$INSTALL_DIR/start.sh"
    chmod +x "$INSTALL_DIR/start.sh"
    echo "Copied start.sh from script directory."
fi

echo ""
echo "========================================="
echo "  Installation Complete!"
echo "========================================="
echo ""
echo "Files installed to: $INSTALL_DIR"
echo ""
echo "Next steps:"
echo "  1. Make sure your phone is on the same WiFi as the camera"
echo "  2. Run: cd $INSTALL_DIR && bash start.sh"
echo "  3. Copy the Cloudflare tunnel URL from the output"
echo "  4. Update camera.html with that URL"
echo ""
