⬅️ Back to [Home](index.md)

# ROS Workspace & Recording

## Workspace Layout

```
~/catkin_ws/
├── src/
│   ├── catkin_simple/
│   ├── rpg_dvs_ros/                ← DVXplorer + dvs_renderer
│   ├── ids_camera_driver/          ← IDS RGB camera ROS node
│   └── rgb_event_camera_system/    ← This package (launch files, scripts)
└── devel/
```

Source before running anything:

```bash
source ~/catkin_ws/devel/setup.bash
```

---

## Live Streaming (both cameras)

Starts the RGB camera, both DVXplorer event cameras, and live image_view windows:

```bash
roslaunch rgb_event_camera_system RGB_event_cam_stereo.launch view:=true
```

---

## Recording

Use `record.sh` to record a bag from the cameras:

```bash
# Native
rosrun rgb_event_camera_system record.sh [exposure_ms] [duration_s] [label]

# Docker
./scripts/record_docker.sh [exposure_ms] [duration_s] [label] [--preview]
```

| Argument | Default | Description |
|---|---|---|
| `exposure_ms` | 5 (native) / 20 (Docker) | RGB exposure in milliseconds |
| `duration_s` | 0 | Recording duration (0 = unlimited, Ctrl-C to stop) |
| `label` | — | Label appended to the bag filename |

**Examples:**

```bash
# Native
rosrun rgb_event_camera_system record.sh 5 30 indoor

# Docker
./scripts/record_docker.sh 20 30 bright_hall
RGB_GAIN=2.0 ./scripts/record_docker.sh 15 30 fast_pass
```

Bags are saved to `$HOME/bags/` (native) or `/bags/` (Docker).

**Topics recorded:**

| Topic | Description |
|---|---|
| `/rgb/image_raw` | RGB camera frames |
| `/dvxplorer_left/events` | Raw event stream |
| `/dvxplorer_left/imu` | IMU data |
| `/dvxplorer_right/events` | Right event stream (Docker script, if connected) |
| `/dvxplorer_right/imu` | Right IMU (Docker script, if connected) |

> `dvs_rendering_left` is not recorded — it is re-rendered on playback by `visualize_bag.sh`.

---

## Visualizing a Bag

Works on any machine with Docker (no ROS host installation needed):

```bash
./scripts/visualize_bag.sh /path/to/bag.bag
```

Opens rviz with two panels: RGB feed and event stream (red=positive, blue=negative).

To stop: `docker stop ros_viz`
