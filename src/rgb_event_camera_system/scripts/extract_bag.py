#!/usr/bin/env python3
"""
Extract RGB frames, event camera data, and Vicon pose from a ROS bag.

Requires: rosbag, numpy, cv2 (opencv-python)
Run inside a ROS environment: source /opt/ros/noetic/setup.bash

Usage:
    python extract_bag.py --bag foo.bag --out ./extracted/
    python extract_bag.py --bag foo.bag --out ./extracted/ --no-srgb --event-side left
"""

import argparse
import json
import time
from pathlib import Path

import cv2
import numpy as np
import rosbag


def parse_args():
    p = argparse.ArgumentParser(
        description="Extract bag to RGB frames, event NPYs, and Vicon pose JSON"
    )
    p.add_argument("--bag", required=True, help="Path to .bag file")
    p.add_argument("--out", required=True, help="Output directory")
    p.add_argument("--rgb-topic",   default="/rgb/image_raw")
    p.add_argument("--left-topic",  default="/dvxplorer_left/events")
    p.add_argument("--right-topic", default="/dvxplorer_right/events")
    p.add_argument("--vicon-topic", default="/vicon/eventrecrc/pose")
    p.add_argument("--no-srgb",    action="store_true", help="Skip linear->sRGB gamma correction")
    p.add_argument("--event-side", choices=["both", "left", "right"], default="both")
    return p.parse_args()


def linear_to_srgb(img: np.ndarray) -> np.ndarray:
    lin = img.astype(np.float32) / 255.0
    out = np.where(lin <= 0.0031308, 12.92 * lin, 1.055 * np.power(lin, 1.0 / 2.4) - 0.055)
    return np.clip(out * 255.0, 0, 255).astype(np.uint8)


def decode_image_msg(msg) -> np.ndarray:
    """Decode sensor_msgs/Image to numpy BGR array without cv_bridge."""
    enc = msg.encoding
    if enc == "rgb8":
        arr = np.frombuffer(msg.data, dtype=np.uint8).reshape(msg.height, msg.width, 3)
        return cv2.cvtColor(arr, cv2.COLOR_RGB2BGR)
    elif enc == "bgr8":
        return np.frombuffer(msg.data, dtype=np.uint8).reshape(msg.height, msg.width, 3).copy()
    elif enc == "rgba8":
        arr = np.frombuffer(msg.data, dtype=np.uint8).reshape(msg.height, msg.width, 4)
        return cv2.cvtColor(arr, cv2.COLOR_RGBA2BGR)
    elif enc == "bgra8":
        arr = np.frombuffer(msg.data, dtype=np.uint8).reshape(msg.height, msg.width, 4)
        return cv2.cvtColor(arr, cv2.COLOR_BGRA2BGR)
    elif enc == "mono8":
        arr = np.frombuffer(msg.data, dtype=np.uint8).reshape(msg.height, msg.width)
        return cv2.cvtColor(arr, cv2.COLOR_GRAY2BGR)
    else:
        try:
            from cv_bridge import CvBridge
            return CvBridge().imgmsg_to_cv2(msg, "bgr8")
        except Exception:
            raise ValueError(f"Unsupported image encoding: {enc!r}")


def extract_rgb(bag: rosbag.Bag, topic: str, out_dir: Path, srgb: bool) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    count = 0
    for _, msg, t in bag.read_messages(topics=[topic]):
        img = decode_image_msg(msg)
        if srgb:
            img = linear_to_srgb(img)
        cv2.imwrite(str(out_dir / f"{t.to_nsec()}.jpg"), img)
        count += 1
    return count


def extract_events(bag: rosbag.Bag, topic: str, out_dir: Path) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    dtype = [('t', 'float64'), ('x', 'int32'), ('y', 'int32'), ('p', 'int8')]
    count = 0
    for _, msg, t in bag.read_messages(topics=[topic]):
        n = len(msg.events)
        if n == 0:
            continue
        arr = np.zeros(n, dtype=dtype)
        for i, ev in enumerate(msg.events):
            arr[i] = (float(ev.ts.to_nsec()), ev.x, ev.y, int(ev.polarity))
        np.save(str(out_dir / f"{t.to_nsec()}.npy"), arr)
        count += 1
    return count


def extract_vicon(bag: rosbag.Bag, topic: str, out_path: Path) -> int:
    """
    Save pose as JSON keyed by nanosecond timestamp string.

    Handles two message types:
      - geometry_msgs/PoseStamped    (vrpn_client_ros)
      - geometry_msgs/TransformStamped (vicon_bridge)
    """
    vicon_data = {}
    for _, msg, t in bag.read_messages(topics=[topic]):
        ts = str(t.to_nsec())
        if hasattr(msg, 'pose'):
            translation = [msg.pose.position.x, msg.pose.position.y, msg.pose.position.z]
            rotation = [msg.pose.orientation.x, msg.pose.orientation.y,
                        msg.pose.orientation.z, msg.pose.orientation.w]
        else:
            translation = [msg.transform.translation.x,
                           msg.transform.translation.y,
                           msg.transform.translation.z]
            rotation = [msg.transform.rotation.x, msg.transform.rotation.y,
                        msg.transform.rotation.z, msg.transform.rotation.w]
        vicon_data[ts] = {'translation': translation, 'rotation': rotation, 'timestamp': ts}
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, 'w') as f:
        json.dump(vicon_data, f, indent=2)
    return len(vicon_data)


def main():
    args = parse_args()
    out = Path(args.out)

    print(f"Opening: {args.bag}")
    bag = rosbag.Bag(args.bag, 'r')

    t0 = time.time()
    n_rgb = extract_rgb(bag, args.rgb_topic, out / "rgb", srgb=not args.no_srgb)
    print(f"  RGB:          {n_rgb:6d} frames   ({time.time() - t0:.1f}s)")

    if args.event_side in ("both", "left"):
        t0 = time.time()
        n_left = extract_events(bag, args.left_topic, out / "events_left")
        print(f"  Events left:  {n_left:6d} msgs     ({time.time() - t0:.1f}s)")

    if args.event_side in ("both", "right"):
        t0 = time.time()
        n_right = extract_events(bag, args.right_topic, out / "events_right")
        print(f"  Events right: {n_right:6d} msgs     ({time.time() - t0:.1f}s)")

    t0 = time.time()
    n_vicon = extract_vicon(bag, args.vicon_topic, out / "vicon_pose.json")
    print(f"  Vicon poses:  {n_vicon:6d}          ({time.time() - t0:.1f}s)")

    bag.close()
    print(f"\nDone. Output: {out.resolve()}")


if __name__ == "__main__":
    main()
