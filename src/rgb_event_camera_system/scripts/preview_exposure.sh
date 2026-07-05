#!/usr/bin/env bash
# Start cameras only — no recording, no prompts.
# Use this to check exposure and gain settings before a recording session.
#
# Usage:
#   rosrun rgb_event_camera_system preview_exposure.sh [rgb_exposure_ms] [rgb_gain] [--bias 0-4]
#
# Examples:
#   rosrun rgb_event_camera_system preview_exposure.sh 5
#   rosrun rgb_event_camera_system preview_exposure.sh 10 1.5
#   rosrun rgb_event_camera_system preview_exposure.sh 10 1.0 --bias 3
#   RGB_EXPOSURE_MS=20 rosrun rgb_event_camera_system preview_exposure.sh
#
# If running headless on a Jetson, preview from your PC with:
#   rosrun rgb_event_camera_system preview_jetson.sh <jetson_ip>
#
# Press Ctrl-C here to stop.

set -e

RGB_EXPOSURE_MS="${RGB_EXPOSURE_MS:-${1:-20}}"
RGB_GAIN="${RGB_GAIN:-${2:-1.0}}"
BIAS_SENSITIVITY="${BIAS_SENSITIVITY:-2}"
i=1
for arg in "$@"; do
    if [ "$arg" = "--bias" ]; then
        eval "BIAS_SENSITIVITY=\${$((i+1))}"
    fi
    i=$(( i + 1 ))
done

# IDS UI304xCP-C max exposure at 25 fps = 39840 µs = 39 ms
RGB_EXPOSURE_MS_MAX=39
if [ "$RGB_EXPOSURE_MS" -gt "$RGB_EXPOSURE_MS_MAX" ]; then
    echo "ERROR: ${RGB_EXPOSURE_MS} ms exceeds the camera max at 25 fps (${RGB_EXPOSURE_MS_MAX} ms = 39840 µs)."
    echo "       Use a value <= ${RGB_EXPOSURE_MS_MAX} ms."
    exit 1
fi

RGB_EXPOSURE_US=$(( RGB_EXPOSURE_MS * 1000 ))

DVX_COUNT=$(lsusb 2>/dev/null | grep -c "152a" || true)
RGB_CONNECTED=false
lsusb 2>/dev/null | grep -q "1409" && RGB_CONNECTED=true
LEFT_DVX=false; RIGHT_DVX=false
[ "${DVX_COUNT:-0}" -ge 1 ] && LEFT_DVX=true
[ "${DVX_COUNT:-0}" -ge 2 ] && RIGHT_DVX=true

echo "============================================"
echo " Camera Preview (no recording)"
echo "  RGB Exposure : ${RGB_EXPOSURE_MS} ms   Gain: ${RGB_GAIN}  Bias: ${BIAS_SENSITIVITY}"
echo "  RGB camera   : ${RGB_CONNECTED}"
echo "  Left DVX     : ${LEFT_DVX}"
echo "  Right DVX    : ${RIGHT_DVX}"
echo "  Preview from PC : rosrun rgb_event_camera_system preview_jetson.sh <jetson_ip>"
echo "  Stop         : Ctrl-C"
echo "============================================"

pkill -f "roscore" 2>/dev/null || true
sleep 1

roscore &
ROSCORE_PID=$!
sleep 2

roslaunch rgb_event_camera_system RGB_event_cam_stereo.launch \
    rgb_exposure_us:="$RGB_EXPOSURE_US" \
    rgb_gain:="$RGB_GAIN" \
    bias_sensitivity:="$BIAS_SENSITIVITY" \
    view:=true \
    rgb:="$RGB_CONNECTED" \
    left_dvx:="$LEFT_DVX" \
    right_dvx:="$RIGHT_DVX" &
LAUNCH_PID=$!

cleanup() {
    echo ""
    echo "Stopping preview..."
    kill $LAUNCH_PID 2>/dev/null || true
    sleep 1
    kill $ROSCORE_PID 2>/dev/null || true
    wait 2>/dev/null || true
}
trap cleanup INT TERM

echo "Cameras streaming. Press Ctrl-C to stop."
wait $LAUNCH_PID
