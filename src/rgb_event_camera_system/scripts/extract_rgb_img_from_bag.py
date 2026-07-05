#!/usr/bin/env python3
"""
Extract RGB frames from a ROS bag to PNGs, one per message, named by timestamp.

Usage:
    python extract_rgb_img_from_bag.py --bag events_only.bag --output_file cam0/
    python extract_rgb_img_from_bag.py --bag events_only.bag --topic /rgb/image_raw --output_file cam0/
"""

import argparse
import os

import cv2
import numpy as np
import rosbag


def decode_image_msg(msg) -> np.ndarray:
    """Decode sensor_msgs/Image to a BGR numpy array without cv_bridge."""
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
    raise ValueError(f"Unsupported image encoding: {enc!r}")


if __name__ == '__main__':
    parser = argparse.ArgumentParser('Extract RGB frames from a rosbag to PNGs.')
    parser.add_argument('--bag', required=True, help='Path to input .bag file')
    parser.add_argument('--output_file', required=True, help='Output directory for PNG frames')
    parser.add_argument('--topic', default='/rgb/image_raw', help='Image topic to extract')
    args = parser.parse_args()

    os.makedirs(args.output_file, exist_ok=True)

    with rosbag.Bag(args.bag, 'r') as bag:
        count = 0
        for _, msg, t in bag.read_messages(topics=[args.topic]):
            img = decode_image_msg(msg)
            cv2.imwrite(os.path.join(args.output_file, f'{t.to_nsec()}.png'), img)
            count += 1
            print('saved:', count)

    print(f'PROCESS COMPLETE — {count} frames written to {args.output_file}')
