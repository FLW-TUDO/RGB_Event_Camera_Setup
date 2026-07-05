#!/usr/bin/env bash
# Recording Script (native, on Jetson or Ubuntu 20.04 host)
# Usage: ./record.sh [exposure_ms] [duration_s] [label]
# Example: ./record.sh 5 30 fast_pass
# Example: ./record.sh 1             (1 ms, unlimited)

set -e

EXPOSURE_MS="${1:-5}"
DURATION_S="${2:-0}"
LABEL="${3:-}"

EXPOSURE_US=$(( EXPOSURE_MS * 1000 ))
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BAG_DIR="${BAG_DIR:-$HOME/bags}"
BAG_NAME="rgb${EXPOSURE_MS}ms_${TIMESTAMP}"
[ -n "$LABEL" ] && [ "$LABEL" != "--rviz" ] && BAG_NAME="rgb${EXPOSURE_MS}ms_${LABEL}_${TIMESTAMP}"

mkdir -p "$BAG_DIR"

echo "============================================"
echo " Recording"
echo "  Exposure  : ${EXPOSURE_MS} ms (${EXPOSURE_US} us)"
if [ "$DURATION_S" -eq 0 ]; then
  echo "  Duration  : unlimited (Ctrl-C to stop)"
else
  echo "  Duration  : ${DURATION_S}s"
fi
echo "  Bag file  : ${BAG_DIR}/${BAG_NAME}.bag"
echo "============================================"

# Source ROS — adjust these paths if your workspaces differ
source /opt/ros/noetic/setup.bash
# Source your catkin workspace(s) that contain the camera drivers:
# source ~/catkin_ws/devel/setup.bash

export GENICAM_GENTL64_PATH=/usr/lib/ids/cti

pkill -f "roscore" 2>/dev/null || true
sleep 1

echo "Starting roscore..."
roscore &
ROSCORE_PID=$!
sleep 2

echo "Starting cameras (stream only, not recording yet)..."
roslaunch rgb_event_camera_system record.launch \
    exposure_us:="$EXPOSURE_US" \
    bag_name:="$BAG_NAME" \
    bag_dir:="$BAG_DIR" \
    duration:="$DURATION_S" \
    rviz:=false \
    record:=false &
LAUNCH_PID=$!

cleanup() {
  echo ""
  echo "Stopping..."
  kill $BAG_PID 2>/dev/null || true
  kill $LAUNCH_PID 2>/dev/null || true
  sleep 2
  kill $ROSCORE_PID 2>/dev/null || true
  wait 2>/dev/null || true
  echo "Bag saved to: ${BAG_DIR}/${BAG_NAME}.bag"
  exit 0
}
trap cleanup INT TERM

sleep 5

JETSON_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "============================================"
echo " Cameras ready. Open preview on your PC:"
echo "   ./preview_jetson.sh ${JETSON_IP}"
echo " Adjust your scene, then press ENTER here"
echo " to start recording."
echo "============================================"
read -r

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BAG_NAME="rgb${EXPOSURE_MS}ms_${TIMESTAMP}"
[ -n "$LABEL" ] && [ "$LABEL" != "--rviz" ] && BAG_NAME="rgb${EXPOSURE_MS}ms_${LABEL}_${TIMESTAMP}"
echo "Recording to: ${BAG_DIR}/${BAG_NAME}.bag"

ROSBAG_ARGS="--output-name=${BAG_DIR}/${BAG_NAME} --buffsize=1024 --lz4 /rgb/image_raw /dvxplorer_left/events /dvxplorer_left/imu /rosout"
if [ "$DURATION_S" -gt 0 ]; then
  ROSBAG_ARGS="$ROSBAG_ARGS --duration=$DURATION_S"
fi
rosbag record $ROSBAG_ARGS &
BAG_PID=$!

wait $BAG_PID
echo "Recording complete."
echo "Bag saved to: ${BAG_DIR}/${BAG_NAME}.bag"
kill $LAUNCH_PID 2>/dev/null || true
kill $ROSCORE_PID 2>/dev/null || true
wait 2>/dev/null || true
