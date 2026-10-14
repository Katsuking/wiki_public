#!/usr/bin/env bash
set -e

VIDEO_NR=20
DEVICE="/dev/video${VIDEO_NR}"

# 1. v4l2loopback モジュールのロード確認と自動ロード
if [ ! -c "$DEVICE" ]; then
    echo "[INFO] Loading v4l2loopback module..."
    sudo modprobe v4l2loopback video_nr="$VIDEO_NR" card_label="scrcpy-webcam" exclusive_caps=1
fi

# 2. ADB デバイス接続チェック
echo "[INFO] Checking ADB connection..."
DEVICE_STATE=$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')

if [ -z "$DEVICE_STATE" ]; then
    echo "[ERROR] No authorized ADB device found."
    echo "Please check USB debugging and accept the authorization prompt on your phone."
    exit 1
fi

echo "[INFO] Connected device: $DEVICE_STATE"

# 3. scrcpy の起動
echo "[INFO] Starting scrcpy webcam stream on $DEVICE..."
scrcpy --video-source=camera \
  --v4l2-sink="$DEVICE" \
  --no-playback \
  --no-control \
  --no-audio \
  --camera-size=1024x576 \
  --camera-fps=15 \
  --video-bit-rate=2M \
  --video-codec=h264
