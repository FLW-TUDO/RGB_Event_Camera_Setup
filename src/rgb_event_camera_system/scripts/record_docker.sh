#!/usr/bin/env bash
# Recording script for use INSIDE the camera_driver Docker container.
# Auto-detects which cameras are plugged in; skips missing ones.
#
# Usage (inside container):
#   /path/to/record_docker.sh [rgb_exposure_ms] [duration_s] [label] [--preview]
#
# Examples:
#   ./record_docker.sh 20 30 bright_hall
#   ./record_docker.sh 25 60 dim_indoor --preview
#   RGB_GAIN=2.0 ./record_docker.sh 15 30 fast_pass
#
# RGB_EXPOSURE_MS env var overrides the positional arg if set.
# RGB_GAIN env var sets camera gain (1.0-24.0, default 1.0).
# VICON_IP env var enables Vicon tracking (set in run_camera_driver.sh).

set -e

RGB_EXPOSURE_MS="${RGB_EXPOSURE_MS:-${1:-20}}"
DURATION_S="${2:-0}"
LABEL="${3:-}"
RGB_GAIN="${RGB_GAIN:-1.0}"
PREVIEW=false
for arg in "$@"; do [ "$arg" = "--preview" ] && PREVIEW=true; done

RGB_EXPOSURE_US=$(( RGB_EXPOSURE_MS * 1000 ))
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BAG_DIR="${BAG_DIR:-/bags}"
BAG_NAME="rgb${RGB_EXPOSURE_MS}ms_${TIMESTAMP}"
[ -n "$LABEL" ] && BAG_NAME="rgb${RGB_EXPOSURE_MS}ms_${LABEL}_${TIMESTAMP}"

mkdir -p "$BAG_DIR"

# ── Detect connected cameras ───────────────────────────────────────────────
# DVXplorer: Thesycon USB VID 152a
DVX_COUNT=$(lsusb 2>/dev/null | grep -c "152a" || true)
DVX_COUNT=${DVX_COUNT:-0}

# IDS RGB camera: VID 1409
RGB_CONNECTED=false
lsusb 2>/dev/null | grep -q "1409" && RGB_CONNECTED=true

LEFT_DVX=false
RIGHT_DVX=false
[ "$DVX_COUNT" -ge 1 ] && LEFT_DVX=true
[ "$DVX_COUNT" -ge 2 ] && RIGHT_DVX=true

echo "============================================"
echo " Recording (Docker)"
echo "  RGB Exposure: ${RGB_EXPOSURE_MS} ms  Gain: ${RGB_GAIN}"
[ "$DURATION_S" -eq 0 ] \
    && echo "  Duration  : unlimited (Ctrl-C to stop)" \
    || echo "  Duration  : ${DURATION_S}s"
echo "  Bag file  : ${BAG_DIR}/${BAG_NAME}.bag"
echo "  RGB camera: ${RGB_CONNECTED}"
echo "  Left DVX  : ${LEFT_DVX}  (DXA00420)"
echo "  Right DVX : ${RIGHT_DVX} (DXA00247)"
[ -n "$VICON_IP" ] \
    && echo "  Vicon     : ${VICON_IP} (VRPN port 3883)" \
    || echo "  Vicon     : disabled (set VICON_IP to enable)"
echo "============================================"

if [ "$LEFT_DVX" = false ] && [ "$RGB_CONNECTED" = false ]; then
    echo "ERROR: No cameras detected. Check USB connections."
    exit 1
fi

pkill -f "roscore" 2>/dev/null || true
sleep 1

echo "Starting roscore..."
roscore &
ROSCORE_PID=$!
sleep 2

if [ -n "$VICON_IP" ]; then
    echo "Starting Vicon bridge (VRPN -> ${VICON_IP}:3883)..."
    roslaunch rgb_event_camera_system vicon.launch server:="$VICON_IP" &
    VICON_PID=$!
    sleep 3
fi

echo "Starting cameras..."
roslaunch rgb_event_camera_system RGB_event_cam_stereo.launch \
    rgb_exposure_us:="$RGB_EXPOSURE_US" \
    rgb_gain:="$RGB_GAIN" \
    view:="$PREVIEW" \
    rgb:="$RGB_CONNECTED" \
    left_dvx:="$LEFT_DVX" \
    right_dvx:="$RIGHT_DVX" &
LAUNCH_PID=$!

cleanup() {
    echo ""
    echo "Stopping..."
    kill $BAG_PID 2>/dev/null || true
    kill $LAUNCH_PID 2>/dev/null || true
    [ -n "${VICON_PID:-}" ] && kill $VICON_PID 2>/dev/null || true
    sleep 2
    kill $ROSCORE_PID 2>/dev/null || true
    wait 2>/dev/null || true
    if [ -n "${HOST_UID:-}" ] && [ -n "${HOST_GID:-}" ]; then
        chown "${HOST_UID}:${HOST_GID}" "${BAG_DIR}/${BAG_NAME}.bag" 2>/dev/null || true
    fi
    echo "Bag saved to: ${BAG_DIR}/${BAG_NAME}.bag"
    exit 0
}
trap cleanup INT TERM

sleep 5

echo ""
echo "============================================"
echo " Cameras ready. Press ENTER to start recording."
echo "============================================"
read -r

if [ -n "$VICON_IP" ]; then
    echo "Checking Vicon topics..."
    VICON_TOPIC=$(rostopic list 2>/dev/null | grep "^/vicon/" | head -5)
    if [ -z "$VICON_TOPIC" ]; then
        echo "WARNING: No /vicon/* topics found."
        echo "         Check that Vicon objects are defined in Vicon Tracker"
        echo "         and that the VRPN connection on port 3883 succeeded."
        echo ""
        echo "Press ENTER to record anyway (mocap will be missing), or Ctrl-C to abort."
        read -r
    else
        echo "Vicon topics active: ${VICON_TOPIC}"
    fi
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BAG_NAME="rgb${RGB_EXPOSURE_MS}ms_${TIMESTAMP}"
[ -n "$LABEL" ] && BAG_NAME="rgb${RGB_EXPOSURE_MS}ms_${LABEL}_${TIMESTAMP}"
echo "Recording to: ${BAG_DIR}/${BAG_NAME}.bag"

TOPICS="/rosout"
[ "$RGB_CONNECTED" = true ]  && TOPICS="$TOPICS /rgb/image_raw"
[ "$LEFT_DVX" = true ]       && TOPICS="$TOPICS /dvxplorer_left/events /dvxplorer_left/imu"
[ "$RIGHT_DVX" = true ]      && TOPICS="$TOPICS /dvxplorer_right/events /dvxplorer_right/imu"
[ -n "$VICON_IP" ]           && TOPICS="$TOPICS /vicon/eventrecrc/pose /vicon/muroKopf/pose /vicon/eventrig/pose"

ROSBAG_ARGS="--output-name=${BAG_DIR}/${BAG_NAME} --buffsize=1024 --lz4 ${TOPICS}"
[ "$DURATION_S" -gt 0 ] && ROSBAG_ARGS="$ROSBAG_ARGS --duration=$DURATION_S"
rosbag record $ROSBAG_ARGS &
BAG_PID=$!

wait $BAG_PID
echo "Recording complete."
kill $LAUNCH_PID 2>/dev/null || true
kill $ROSCORE_PID 2>/dev/null || true
wait 2>/dev/null || true

if [ -n "${HOST_UID:-}" ] && [ -n "${HOST_GID:-}" ]; then
    chown "${HOST_UID}:${HOST_GID}" "${BAG_DIR}/${BAG_NAME}.bag" 2>/dev/null || true
fi
