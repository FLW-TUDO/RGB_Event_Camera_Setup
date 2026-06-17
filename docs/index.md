# RGB + Stereo Event Camera System — Documentation

## Choose your installation path

### Docker (recommended for most users)
No ROS host installation required. Works on any Linux with Docker — Ubuntu 20/22/24, x86 and ARM64/Jetson.
→ [Docker Installation](installation.md#docker-installation)

### Native (Ubuntu 20.04 + ROS Noetic only)
Direct host installation. Supported on Ubuntu 20.04 x86 and Jetson JetPack 5 (Ubuntu 20.04 arm64).
Not available for Ubuntu 22.04 / 24.04 or Jetson JetPack 6 — use Docker instead.
→ [Native Installation](installation.md#native-installation-ubuntu-2004--ros-noetic)

---

## Documentation

1. [Installation](installation.md)
2. [ROS Workspace & Recording](ros-workspace.md)
3. [Calibration Workflow](calibration.md)
4. [Troubleshooting](troubleshooting.md)

---

## Tested Hardware

- 1 × IDS UI304xCP-C RGB camera
- 2 × DVXplorer event cameras (stereo pair)
- x86 workstation: Ubuntu 20.04 (native) / Ubuntu 22.04 and 24.04 (Docker)
- Jetson (arm64): JetPack 5 / Ubuntu 20.04 (native or Docker) — JetPack 6 / Ubuntu 22.04 (Docker)
