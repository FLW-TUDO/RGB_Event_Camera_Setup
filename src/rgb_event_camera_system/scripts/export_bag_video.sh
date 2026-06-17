#!/bin/bash
# Export RGB and event streams from a bag to mp4 files.
# Reads the bag directly (no ROS playback needed — no frame skipping).
# Usage: ./export_bag_video.sh <bag_path> [output_dir] [brightness]
#   brightness: RGB multiplier, e.g. 1.5 for 50% brighter (default: 1.0)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BAG_PATH="${1}"
OUTPUT_DIR="${2:-./export}"
BRIGHTNESS="${3:-1.0}"

if [ -z "$BAG_PATH" ]; then
    echo "Usage: $0 <bag_path> [output_dir] [brightness]"
    exit 1
fi

[ -f "$BAG_PATH" ] || { echo "Bag not found: $BAG_PATH"; exit 1; }

mkdir -p "$OUTPUT_DIR"

echo "==> Cleaning up old container..."
docker rm -f ros_export 2>/dev/null

echo "==> Starting container..."
docker run -d --name ros_export \
    --entrypoint bash \
    -v "$(dirname "$BAG_PATH")":/bags:ro \
    -v "${SCRIPT_DIR}":/rgb_event_cam_scripts:ro \
    camera_driver -c "sleep infinity"

BAG_BASENAME=$(basename "$BAG_PATH")

echo "==> Exporting (offline read — no rosbag play)..."
docker exec ros_export bash -c \
    "source /catkin_ws/devel/setup.bash && \
     python3 /rgb_event_cam_scripts/export_bag_videos.py \
       --bag /bags/${BAG_BASENAME} \
       --out /tmp/export \
       --brightness ${BRIGHTNESS}"

echo "==> Copying videos to host..."
docker cp ros_export:/tmp/export/rgb.mp4 "${OUTPUT_DIR}/rgb.mp4" \
    && echo "  Saved: ${OUTPUT_DIR}/rgb.mp4"
docker cp ros_export:/tmp/export/events_left.mp4 "${OUTPUT_DIR}/events_left.mp4" \
    && echo "  Saved: ${OUTPUT_DIR}/events_left.mp4"

echo "==> Cleaning up..."
docker rm -f ros_export 2>/dev/null

echo ""
echo "Done. Videos: ${OUTPUT_DIR}/"
ls -lh "${OUTPUT_DIR}/"
