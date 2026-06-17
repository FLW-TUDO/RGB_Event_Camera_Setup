#!/bin/bash
# Visualize a recorded bag in Docker (no ROS host installation needed).
# Usage: ./visualize_bag.sh <bag_path>
# Example: ./visualize_bag.sh ~/bags/rgb20ms_20260407_173926.bag

BAG_PATH="${1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$BAG_PATH" ]; then
    echo "Usage: $0 <bag_path>"
    exit 1
fi

if [ ! -f "$BAG_PATH" ]; then
    echo "Bag not found: $BAG_PATH"
    exit 1
fi

echo "==> Cleaning up old container..."
docker rm -f ros_viz 2>/dev/null

echo "==> Starting container..."
xhost +local:root
docker run -d --name ros_viz \
    --net=host \
    -e DISPLAY=$DISPLAY \
    -e QT_X11_NO_MITSHM=1 \
    -e ROS_MASTER_URI=http://localhost:11311 \
    --entrypoint bash \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v "${SCRIPT_DIR}/../..":/rgb_event_cam_system:ro \
    camera_driver -c "sleep infinity"

echo "==> Starting roscore..."
docker exec -d ros_viz bash -c "source /catkin_ws/devel/setup.bash && export ROS_MASTER_URI=http://localhost:11311 && roscore"
sleep 4

echo "==> Copying bag into container..."
docker cp "${BAG_PATH}" ros_viz:/tmp/bag.bag
echo " done"

echo "==> Starting dvs_renderer..."
docker exec -d ros_viz bash -c "export ROS_MASTER_URI=http://localhost:11311 && source /catkin_ws/devel/setup.bash && \
    rosrun dvs_renderer dvs_renderer events:=/dvxplorer_left/events dvs_rendering:=/dvs_rendering_left _display_method:=red-blue"
sleep 2

echo "==> Starting rosbag playback..."
docker exec -d ros_viz bash -c "export ROS_MASTER_URI=http://localhost:11311 && source /catkin_ws/devel/setup.bash && rosbag play /tmp/bag.bag --loop"
sleep 3

echo "==> Launching rviz..."
docker exec -d ros_viz bash -c "export ROS_MASTER_URI=http://localhost:11311 && export DISPLAY=$DISPLAY && export QT_X11_NO_MITSHM=1 && source /catkin_ws/devel/setup.bash && rviz -d /rgb_event_cam_system/rviz/wp1.rviz"

echo ""
echo "==> Done! Rviz should open shortly."
echo "    To stop: docker stop ros_viz"
