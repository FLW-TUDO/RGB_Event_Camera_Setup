⬅️ Back to [Home](index.md)

# Calibration Workflow (RGB + Stereo Event Cameras)

Camera mapping:
- **cam0**: RGB camera
- **cam1**: left event camera (reconstructed frames)
- **cam2**: right event camera (reconstructed frames)

Tools:
- **e2calib** — converts event streams to intensity-like frames
- **Kalibr** — multi-camera calibration

---

## Prerequisites

- ROS Noetic sourced (native or Docker)
- `e2calib` cloned at `~/event_camera/e2calib`
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

```bash
cd ~/event_camera/e2calib

python python/convert.py \
  --input_file $CALIB_DIR/events_only.bag \
  --topic /dvxplorer_left/events \
  --output_file $CALIB_DIR/events_left.h5

python python/convert.py \
  --input_file $CALIB_DIR/events_only.bag \
  --topic /dvxplorer_right/events \
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
python Annotation/calibration_rgb_event_cameras_extrinsics/extract_rgb_img_from_bag.py \
  --bag $CALIB_DIR/events_only.bag \
  --output $CALIB_DIR/reconstructed_event_images/cam0
```

---

## Step 5 — Create Image Bag for Kalibr

```bash
source ~/kalibr_workspace/devel/setup.bash

rosrun kalibr kalibr_bagcreater \
  --folder $CALIB_DIR/reconstructed_event_images/ \
  --output-bag $CALIB_DIR/images.bag
```

The folder must contain subfolders named `cam0/`, `cam1/`, `cam2/` with images inside.

---

## Step 6 — Run Kalibr Calibration

```bash
rosrun kalibr kalibr_calibrate_cameras \
  --target $CALIB_DIR/../checkerboard_8x6_5cm.yaml \
  --models pinhole-radtan pinhole-radtan pinhole-radtan \
  --topics /cam0/image_raw /cam1/image_raw /cam2/image_raw \
  --bag $CALIB_DIR/images.bag \
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
