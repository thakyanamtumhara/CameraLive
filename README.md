# CameraLive

Stream a Tapo C320WS camera live on a website using an Android phone as a relay.

## Architecture

```
Tapo Camera (RTSP)
       ↓
Android Phone on same WiFi
  (Termux: MediaMTX + cloudflared)
       ↓
Cloudflare Tunnel (free, public URL)
       ↓
Website (HLS stream via HLS.js)
```

## Requirements

- **Tapo C320WS camera** on local WiFi
- **Android phone** on same WiFi, plugged into charger 24/7
- **Termux** app installed on the phone ([F-Droid](https://f-droid.org/en/packages/com.termux/))
- No router admin access or port forwarding needed

## Setup Instructions

### Step 1: Install Termux on Android

1. Install [Termux from F-Droid](https://f-droid.org/en/packages/com.termux/) (NOT from Play Store — that version is outdated)
2. Open Termux and allow storage access:
   ```
   termux-setup-storage
   ```

### Step 2: Clone This Repo

```bash
pkg install git -y
git clone https://github.com/thakyanamtumhara/CameraLive.git ~/CameraLive
```

### Step 3: Run the Installer

```bash
cd ~/CameraLive
bash install.sh
```

This downloads MediaMTX and cloudflared to `~/cameralive/`.

### Step 4: Start the Stream

```bash
cd ~/cameralive
bash start.sh
```

You'll see output like:
```
Starting MediaMTX...
Starting Cloudflare Tunnel...

Your tunnel URL: https://abc-def-ghi.trycloudflare.com
```

**Copy that tunnel URL** — you need it for the next step.

### Step 5: Configure the Website

1. Open `camera.html`
2. Find this line near the top of the `<script>` section:
   ```js
   const STREAM_URL = "TUNNEL_URL_HERE/cam/";
   ```
3. Replace `TUNNEL_URL_HERE` with your tunnel URL:
   ```js
   const STREAM_URL = "https://abc-def-ghi.trycloudflare.com/cam/";
   ```
4. Host `camera.html` on your website or open it directly in a browser

### Step 6: View the Stream

1. Open `camera.html` in a browser
2. Click the **Live Camera** button
3. Click the video to go fullscreen

## Files

| File | Description |
|------|-------------|
| `mediamtx.yml` | MediaMTX config — pulls RTSP from camera, serves HLS |
| `install.sh` | One-command installer for Termux |
| `start.sh` | Startup script — runs MediaMTX + Cloudflare Tunnel |
| `camera.html` | Website page — HLS player with live badge + fullscreen |

## Updating Camera Credentials

If your camera IP or password changes, edit `mediamtx.yml`:

```yaml
paths:
  cam:
    source: rtsp://USERNAME:PASSWORD@CAMERA_IP:554/stream1
```

## Troubleshooting

**Stream won't connect?**
- Make sure phone is on the same WiFi as the camera
- Check that `start.sh` is running in Termux
- Verify the tunnel URL in `camera.html` is correct

**Cloudflare URL changes on restart?**
- Free tunnels get a new random URL each time. Update `camera.html` after restarting.
- For a permanent URL, set up a [Cloudflare named tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) (free with Cloudflare account).

**Phone goes to sleep?**
- In Termux, run `termux-wake-lock` before starting to prevent sleep
- Keep the phone plugged in and disable battery optimization for Termux

**Video has delay?**
- Some HLS latency (5-15 seconds) is normal
- Lower segment duration in `mediamtx.yml` can reduce it slightly
