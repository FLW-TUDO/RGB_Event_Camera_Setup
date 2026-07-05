# RGB + Stereo Event Camera Setup (ROS Noetic)

Launch files, recording scripts, calibration workflow, and setup documentation for a synchronized RGB + stereo event camera system under ROS Noetic.

## Supported Hardware

| Component | Model |
|-----------|-------|
| RGB camera | IDS UI304xCP-C |
| Event cameras | 2 x iniVation DVXplorer (stereo pair) |

## Platform Support

| Platform | Native | Docker |
|----------|--------|--------|
| Ubuntu 20.04 — x86 (`amd64`) | Yes (ROS Noetic) | Yes |
| Ubuntu 22.04 — x86 (`amd64`) | No | Yes |
| Ubuntu 24.04 — x86 (`amd64`) | No | Yes |
| Jetson — Ubuntu 20.04 (`arm64`, JetPack 5) | Yes | Yes |
| Jetson — Ubuntu 22.04 (`arm64`, JetPack 6) | No | Yes |

Docker is the simpler path for any platform. Native installation requires Ubuntu 20.04.

## Quick Start

### Docker (recommended)

```bash
# Clone the camera driver setup repo
git clone git@github.com:FLW-TUDO/event_cam_setup.git
cd event_cam_setup

# Build the Docker image (auto-detects architecture)
./build_camera_driver.sh

# Start the container with camera access
./run_camera_driver.sh
```

### Native (Ubuntu 20.04 only)

See [docs/installation.md](docs/installation.md) for full native installation instructions covering ROS Noetic, DVXplorer drivers, and IDS camera setup.

---

## ROS Package Installation

This repository contains the ROS package `rgb_event_camera_system`. To use it with `roslaunch`:

```bash
# Create or use an existing catkin workspace
mkdir -p ~/catkin_ws/src
cd ~/catkin_ws/src

# Clone and symlink the package
git clone https://github.com/FLW-TUDO/RGB_Event_Camera_Setup.git
ln -s RGB_Event_Camera_Setup/src/rgb_event_camera_system .

# Build
cd ~/catkin_ws
catkin_make

# Source the workspace
source devel/setup.bash

# Verify the package is found
rospack find rgb_event_camera_system
```

To source the workspace automatically, add to `~/.bashrc`:

```bash
echo "source ~/catkin_ws/devel/setup.bash" >> ~/.bashrc
```

---

## Usage

### Launch RGB Camera

```bash
roslaunch rgb_event_camera_system RGB_event_cam_stereo.launch \
    left_dvx:=false right_dvx:=false view:=true
```

### Launch Event Cameras (Left + Right)

```bash
roslaunch rgb_event_camera_system RGB_event_cam_stereo.launch \
    rgb:=false view:=true
```

### Launch Full Rig (RGB + Stereo Events)

```bash
# With live preview windows
roslaunch rgb_event_camera_system RGB_event_cam_stereo.launch view:=true

# Headless (no GUI)
roslaunch rgb_event_camera_system RGB_event_cam_stereo.launch view:=false

# Custom exposure and gain
roslaunch rgb_event_camera_system RGB_event_cam_stereo.launch \
    rgb_exposure_us:=20000 rgb_gain:=1.5 view:=true

# Event-camera bias sensitivity (0=Very_Low … 4=Very_High, default 2)
roslaunch rgb_event_camera_system RGB_event_cam_stereo.launch bias_sensitivity:=3
```

To check exposure/gain/bias interactively without recording (auto-detects which
cameras are plugged in):

```bash
rosrun rgb_event_camera_system preview_exposure.sh [rgb_exposure_ms] [rgb_gain] [--bias 0-4]
```

### Check Topics

```bash
rostopic list
# Expected:
#   /rgb/image_raw              — RGB camera (25 fps)
#   /dvxplorer_left/events      — Left event camera
#   /dvxplorer_left/imu         — Left DVX IMU
#   /dvxplorer_right/events     — Right event camera
#   /dvxplorer_right/imu        — Right DVX IMU

rostopic hz /rgb/image_raw /dvxplorer_left/events
```

### RGB Camera Parameters

| Parameter | Default | Range | Notes |
|-----------|---------|-------|-------|
| `rgb_exposure_us` | 20000 | 26 -- 39840 | Exposure in microseconds (max ~40 ms at 25 fps) |
| `rgb_gain` | 1.0 | 1.0 -- 24.0 | Higher gain = brighter but more noise |
| `rgb_gamma` | 2.2 | 1.0+ | 1.0 = linear/dark, 2.2 = sRGB-like/natural |

---

## Recording

### Native (on Jetson or Ubuntu 20.04 host)

```bash
# Usage: record.sh [exposure_ms] [duration_s] [label]
rosrun rgb_event_camera_system record.sh 20 30 my_recording
rosrun rgb_event_camera_system record.sh 5           # 5 ms, unlimited
```

### Docker (inside container)

```bash
./scripts/record_docker.sh 20 30 my_recording
./scripts/record_docker.sh 25 60 indoor --preview
RGB_GAIN=2.0 ./scripts/record_docker.sh 15 30 fast_pass
```

Bags are saved to `~/bags/` on the host (native) or `/bags/` in the container.

### Recorded Topics

| Topic | Type | Description |
|-------|------|-------------|
| `/rgb/image_raw` | `sensor_msgs/Image` | RGB camera (25 fps) |
| `/dvxplorer_left/events` | `dvs_msgs/EventArray` | Left event camera |
| `/dvxplorer_left/imu` | `sensor_msgs/Imu` | Left DVX IMU |
| `/dvxplorer_right/events` | `dvs_msgs/EventArray` | Right event camera |
| `/dvxplorer_right/imu` | `sensor_msgs/Imu` | Right DVX IMU |

---

## Visualization

Works on any machine with Docker — no ROS host installation needed:

```bash
./scripts/visualize_bag.sh ~/bags/my_recording.bag
# Opens RViz with RGB and event stream panels (red=ON, blue=OFF)
# Stop: docker stop ros_viz
```

### Export Bag to Video

```bash
./scripts/export_bag_video.sh ~/bags/my_recording.bag ./export 1.5
# Exports rgb.mp4 and events_left.mp4 (1.5x brightness)
```

### Preview Jetson Cameras from PC

```bash
./scripts/preview_jetson.sh <jetson_ip> [pc_ip]
# Opens RViz on PC subscribing to Jetson's ROS master
```

---

## Calibration

Multi-camera calibration using e2calib (event-to-frame reconstruction) and Kalibr:

1. Record a calibration bag with a checkerboard visible to all cameras
2. Convert event topics to H5
3. Reconstruct event frames with e2calib
4. Extract RGB frames
5. Run Kalibr multi-camera calibration

See [docs/calibration.md](docs/calibration.md) for the full step-by-step workflow.

---

## Troubleshooting

Common issues and fixes:

- IDS camera not detected (uEye daemon, GenTL path, USB hub LPM resets, half-configured package)
- DVXplorer not detected (libcaer, serial numbers, USB)
- Missing ROS topics (workspace sourcing, ROS_MASTER_URI)
- Rosbag buffer overflow
- RViz shows "No Image"
- Kalibr optimization failures
- e2calib GPU out of memory

See [docs/troubleshooting.md](docs/troubleshooting.md).

---

## Documentation

| Document | Content |
|----------|---------|
| [Installation](docs/installation.md) | Docker and native setup (ROS, DVXplorer, IDS camera) |
| [ROS Workspace & Recording](docs/ros-workspace.md) | Workspace layout, launching, recording |
| [Calibration Workflow](docs/calibration.md) | RGB + stereo event camera calibration with e2calib + Kalibr |
| [Troubleshooting](docs/troubleshooting.md) | Common issues and fixes |

---

## Repository Scope

This repository provides the **generic setup, launch, and recording infrastructure** for an RGB + stereo event camera system.

**Included:** ROS launch files, recording/visualization scripts, Docker workflow, driver installation docs, calibration workflow, troubleshooting.

**Not included:** Experiment protocols, data annotation pipelines, dataset formats, object detection models, research results, recorded data, or analysis scripts. Research-specific tooling is maintained separately.

---

## License

MIT — see [LICENSE](LICENSE).
