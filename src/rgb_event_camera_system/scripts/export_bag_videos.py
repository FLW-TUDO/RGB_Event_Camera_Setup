#!/usr/bin/env python3
"""
Offline export of a ROS bag to mp4 video files.

Reads the bag directly (no ROS node or rosbag play needed).
Outputs exactly FRAME_RATE fps — no gaps, no skipped frames.

  /rgb/image_raw           -> rgb.mp4
  /dvxplorer_left/events   -> events_left.mp4  (red=ON blue=OFF, 33ms window)

Usage:
  python3 export_bag_videos.py --bag /bags/my.bag --out /tmp/export
"""

import argparse
import os
import subprocess
from collections import deque

import numpy as np
import rosbag
from cv_bridge import CvBridge

FRAME_RATE   = 25.0
EVENT_WINDOW = 0.033   # seconds of events visible per frame (33 ms)
TOPICS       = ["/rgb/image_raw", "/dvxplorer_left/events"]
EVENT_BG     = 0       # background colour: 0=black (matches rviz dvs_renderer)


# ── ffmpeg writer ─────────────────────────────────────────────────────────────

class FfmpegWriter:
    def __init__(self, path: str, w: int, h: int, fps: float = FRAME_RATE):
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        self.proc = subprocess.Popen(
            [
                "ffmpeg", "-y",
                "-f", "rawvideo", "-vcodec", "rawvideo",
                "-pix_fmt", "bgr24", "-s", f"{w}x{h}", "-r", str(fps),
                "-i", "pipe:",
                "-vcodec", "libx264", "-preset", "fast",
                "-crf", "18", "-pix_fmt", "yuv420p",
                path,
            ],
            stdin=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )

    def write(self, frame: np.ndarray):
        self.proc.stdin.write(frame.tobytes())

    def close(self):
        self.proc.stdin.close()
        self.proc.wait()


# ── event renderer ────────────────────────────────────────────────────────────

def render_events(window: deque, h: int, w: int) -> np.ndarray:
    """Render all events in the sliding window to a BGR frame."""
    frame = np.full((h, w, 3), EVENT_BG, dtype=np.uint8)
    if not window:
        return frame
    all_xs   = np.concatenate([b[1] for b in window])
    all_ys   = np.concatenate([b[2] for b in window])
    all_pols = np.concatenate([b[3] for b in window])
    valid = (all_xs >= 0) & (all_xs < w) & (all_ys >= 0) & (all_ys < h)
    on_  = valid &  all_pols
    off_ = valid & ~all_pols
    frame[all_ys[on_],  all_xs[on_]]  = (0, 0, 255)   # ON  → red
    frame[all_ys[off_], all_xs[off_]] = (255, 0, 0)   # OFF → blue
    return frame


def apply_brightness(frame: np.ndarray, brightness: float) -> np.ndarray:
    if brightness == 1.0:
        return frame
    return np.clip(frame.astype(np.float32) * brightness, 0, 255).astype(np.uint8)


# ── main export ───────────────────────────────────────────────────────────────

def export(bag_path: str, output_dir: str, brightness: float = 1.0):
    os.makedirs(output_dir, exist_ok=True)
    bridge = CvBridge()

    bag      = rosbag.Bag(bag_path)
    t_start  = bag.get_start_time()
    t_end    = bag.get_end_time()
    duration = t_end - t_start
    print(f"Bag: {duration:.1f}s  ({bag.get_message_count()} msgs total)")

    # ── detect dimensions from first messages ─────────────────────────────────
    rgb_w = rgb_h = evt_w = evt_h = None
    for topic, msg, _ in bag.read_messages(topics=TOPICS):
        if topic == "/rgb/image_raw" and rgb_w is None:
            rgb_h, rgb_w = msg.height, msg.width
        elif topic == "/dvxplorer_left/events" and evt_w is None and msg.events:
            max_x = max(e.x for e in msg.events)
            max_y = max(e.y for e in msg.events)
            evt_w = (int(max_x) + 2) & ~1
            evt_h = (int(max_y) + 2) & ~1
        if rgb_w and evt_w:
            break

    print(f"RGB    : {rgb_w}x{rgb_h}")
    print(f"Events : {evt_w}x{evt_h}")

    rgb_writer = FfmpegWriter(os.path.join(output_dir, "rgb.mp4"),          rgb_w, rgb_h)
    evt_writer = FfmpegWriter(os.path.join(output_dir, "events_left.mp4"),  evt_w, evt_h)

    # ── stream through bag, emit one frame per 1/FRAME_RATE ──────────────────
    frame_dur  = 1.0 / FRAME_RATE
    frame_t    = t_start                                   # wall time of next frame
    latest_rgb = np.zeros((rgb_h, rgb_w, 3), dtype=np.uint8)
    evt_window: deque = deque()   # entries: (ts_max_sec, xs, ys, pols)
    n_frames   = 0

    for topic, msg, t in bag.read_messages(topics=TOPICS):
        msg_t = t.to_sec()

        # Emit all video frames that fall before this message's timestamp
        while frame_t + frame_dur <= msg_t:
            frame_t += frame_dur

            rgb_writer.write(latest_rgb)

            # Trim event window to the last EVENT_WINDOW seconds
            cutoff = frame_t - EVENT_WINDOW
            while evt_window and evt_window[0][0] < cutoff:
                evt_window.popleft()
            evt_writer.write(render_events(evt_window, evt_h, evt_w))

            n_frames += 1
            if n_frames % 25 == 0:
                pct = 100.0 * (frame_t - t_start) / duration
                print(f"\r  {frame_t - t_start:.1f}/{duration:.1f}s  ({pct:.0f}%)", end="", flush=True)

        # Update state with this message
        if topic == "/rgb/image_raw":
            latest_rgb = apply_brightness(bridge.imgmsg_to_cv2(msg, "bgr8"), brightness)

        elif topic == "/dvxplorer_left/events" and msg.events:
            n = len(msg.events)
            ts_max = msg.events[-1].ts.to_sec()
            xs   = np.fromiter((e.x        for e in msg.events), dtype=np.uint16, count=n)
            ys   = np.fromiter((e.y        for e in msg.events), dtype=np.uint16, count=n)
            pols = np.fromiter((e.polarity for e in msg.events), dtype=bool,      count=n)
            evt_window.append((ts_max, xs, ys, pols))

    print(f"\nClosing writers ({n_frames} frames) ...")
    rgb_writer.close()
    evt_writer.close()
    bag.close()
    print("Done.")


# ── entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--bag",        required=True,  help="Path to .bag file")
    parser.add_argument("--out",        default="/tmp/export", help="Output directory")
    parser.add_argument("--brightness", type=float, default=1.0,
                        help="RGB brightness multiplier (e.g. 1.5 = 50%% brighter, default 1.0)")
    args = parser.parse_args()
    export(args.bag, args.out, args.brightness)
