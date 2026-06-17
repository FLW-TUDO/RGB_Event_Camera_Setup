#!/usr/bin/env bash
# Live preview of Jetson camera streams on the PC.
# Runs rviz + dvs_renderer in Docker, subscribing to the Jetson's ROS master.
#
# Usage: ./preview_jetson.sh <jetson_ip> [docker_image]
# Example: ./preview_jetson.sh 192.168.2.228

JETSON_IP="${1:-192.168.2.228}"
PC_IP="${2:-192.168.2.97}"
DOCKER_IMAGE="${3:-camera_driver}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER=ros_preview

if [ -z "$JETSON_IP" ]; then
    echo "Usage: $0 <jetson_ip> [pc_ip] [docker_image]"
    exit 1
fi

docker rm -f $CONTAINER 2>/dev/null || true
xhost +local:root

docker run -d --name $CONTAINER \
    --network=host \
    --gpus all \
    -e DISPLAY="$DISPLAY" \
    -e QT_X11_NO_MITSHM=1 \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -e ROS_MASTER_URI="http://${JETSON_IP}:11311" \
    -e ROS_IP="$PC_IP" \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    --entrypoint bash \
    "$DOCKER_IMAGE" -c "sleep infinity"

docker cp "$SCRIPT_DIR/wp1.rviz" $CONTAINER:/tmp/wp1.rviz

# dvs_renderer: subscribes to Jetson's /dvxplorer_left/events over the network
docker exec -d $CONTAINER bash -c "
    export ROS_MASTER_URI=http://${JETSON_IP}:11311
    export ROS_IP=$PC_IP
    source /catkin_ws/devel/setup.bash
    rosrun dvs_renderer dvs_renderer \
        _display_method:=red-blue \
        /events:=/dvxplorer_left/events \
        /dvs_rendering:=/dvs_rendering_left
"
sleep 2

# rviz
docker exec -d $CONTAINER bash -c "
    export ROS_MASTER_URI=http://${JETSON_IP}:11311
    export ROS_IP=$PC_IP
    export DISPLAY=$DISPLAY
    export QT_X11_NO_MITSHM=1
    source /catkin_ws/devel/setup.bash
    rviz -d /tmp/wp1.rviz
"

echo ""
echo "Preview running. RViz should open shortly."
echo "To stop: docker stop $CONTAINER"
