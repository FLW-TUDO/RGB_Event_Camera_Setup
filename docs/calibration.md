⬅️ Back to [Home](index.md)

# Calibration Workflow (RGB + Stereo Event Cameras)

Camera mapping:
- **cam0**: RGB camera
- **cam1**: left event camera (reconstructed frames)
- **cam2**: right event camera (reconstructed frames)

Tools:
- **e2calib** ([uzh-rpg/e2calib](https://github.com/uzh-rpg/e2calib)) — converts event streams to intensity-like frames
- **Kalibr** — multi-camera calibration

---

## Prerequisites

- ROS Noetic sourced (native or Docker)
- `e2calib` cloned at `~/event_camera/e2calib` (`git clone https://github.com/uzh-rpg/e2calib.git ~/event_camera/e2calib`)
- Kalibr Docker image built (`kalibr:latest`) or Kalibr workspace sourced
- Checkerboard target YAML (e.g., `checkerboard_8x6_5cm.yaml`)

---

## Set up a working directory

All steps below use `$CALIB_DIR`. Set this once:

```bash
export CALIB_DIR=~/event_camera/calibration_data/RGB_stereo_event
mkdir -p $CALIB_DIR/reconstructed_event_images
```

---

## Step 1 — Record a Calibration Bag

Keep cameras stationary. Move the checkerboard slowly to cover the full field of view — corners, near/far, different orientations.

```bash
rosbag record \
  /dvxplorer_left/events \
  /dvxplorer_right/events \
  /rgb/image_raw \
  --output-name $CALIB_DIR/events_only.bag
```

---

## Step 2 — Convert Event Topics to H5

> If you have a ROS2 workspace sourced (e.g. ROS2 Humble + colcon workspaces), its packages get prepended to `PYTHONPATH` and shadow the pip-installed ROS1 `rospy`/`rosbag` that `convert.py` needs (specifically `rosgraph_msgs`, causing `ImportError: cannot import name 'Log'`). Clear `PYTHONPATH` for this command to avoid the conflict. `convert.py` also needs `tqdm` (`pip3 install --user tqdm`) even though it's not in `requirements.txt`.

```bash
cd ~/event_camera/e2calib

PYTHONPATH= python3 python/convert.py \
  --topic /dvxplorer_left/events \
  $CALIB_DIR/events_only.bag \
  --output_file $CALIB_DIR/events_left.h5

PYTHONPATH= python3 python/convert.py \
  --topic /dvxplorer_right/events \
  $CALIB_DIR/events_only.bag \
  --output_file $CALIB_DIR/events_right.h5
```

---

## Step 3 — Reconstruct Event Frames

```bash
# Right camera → cam2
python python/offline_reconstruction.py \
  --h5file $CALIB_DIR/events_right.h5 \
  --freq_hz 5 \
  --output_folder $CALIB_DIR/reconstructed_event_images \
  --use_gpu
mv $CALIB_DIR/reconstructed_event_images/e2calib $CALIB_DIR/reconstructed_event_images/cam2

# Left camera → cam1
python python/offline_reconstruction.py \
  --h5file $CALIB_DIR/events_left.h5 \
  --freq_hz 5 \
  --output_folder $CALIB_DIR/reconstructed_event_images \
  --use_gpu
mv $CALIB_DIR/reconstructed_event_images/e2calib $CALIB_DIR/reconstructed_event_images/cam1
```

> Remove `--use_gpu` if no GPU is available. Adjust `--freq_hz` based on checkerboard motion speed — 5 Hz works well for slow movements.

---

## Step 4 — Extract RGB Frames

```bash
PYTHONPATH= python3 scripts/extract_rgb_img_from_bag.py \
  --topic /rgb/image_raw \
  --bag $CALIB_DIR/events_only.bag \
  --output_file $CALIB_DIR/reconstructed_event_images/cam0
```

> Same `PYTHONPATH=` rule as event conversion (see [e2calib docs](https://github.com/uzh-rpg/e2calib)): needed if a ROS2 workspace is sourced, so pip's ROS1 `rosbag` loads instead of colliding with ROS2 packages. Run outside any conda env — this needs the system `rosbag`/`cv2`, not conda packages.

---

## Step 5 — Create Image Bag for Kalibr

Best done inside the Kalibr Docker container rather than a native Kalibr workspace — avoids ROS distro/dependency conflicts entirely.

```bash
docker run -it --rm -v $CALIB_DIR/reconstructed_event_images:/data kalibr:latest

# Inside the container:
rosrun kalibr kalibr_bagcreater --folder /data/ --output-bag /data/images.bag
```

The folder must contain subfolders named `cam0/`, `cam1/`, `cam2/` with images inside.

---

## Step 6 — Run Kalibr Calibration

Same container, with the checkerboard YAML also mounted in (or copied into `$CALIB_DIR` beforehand so it's under `/data`):

```bash
rosrun kalibr kalibr_calibrate_cameras \
  --target /data/checkerboard_8x6_5cm.yaml \
  --models pinhole-radtan pinhole-radtan pinhole-radtan \
  --topics /cam0/image_raw /cam1/image_raw /cam2/image_raw \
  --bag /data/images.bag \
  --bag-freq 5.0 \
  --verbose
```

### Distortion model note

Depending on the DVXplorer lens, try `omni-radtan` instead of `pinhole-radtan` if residuals are high or calibration fails consistently.

---

## Troubleshooting

### Kalibr "Optimization failed"

Increase `timeOffsetPadding` in `kalibr_calibrate_imu_camera.py`. Higher value = more robust but slower. Too low causes the optimizer to cross knot boundaries.

### High reprojection error on event cameras

- Ensure `--freq_hz` is low enough that checkerboard corners are sharp in reconstructed frames
- Check that cam1/cam2 folders contain enough images with visible corners
