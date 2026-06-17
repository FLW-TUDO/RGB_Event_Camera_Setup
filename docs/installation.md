⬅️ Back to [Home](index.md)

# Installation

## Platform support matrix

| Platform | Native | Docker |
|---|---|---|
| Ubuntu 20.04 — x86 (`amd64`) | ✓ ROS Noetic | ✓ |
| Ubuntu 22.04 — x86 (`amd64`) | ✗ (no Noetic packages for Jammy) | ✓ |
| Ubuntu 24.04 — x86 (`amd64`) | ✗ | ✓ |
| Jetson — Ubuntu 20.04 (`arm64`, JetPack 5) | ✓ ROS Noetic | ✓ |
| Jetson — Ubuntu 22.04 (`arm64`, JetPack 6) | ✗ (use Docker) | ✓ |

Docker is always the simpler path. Native is only required if you cannot run Docker on the target machine.

---

## Docker Installation

The Docker image bundles ROS Noetic, DVXplorer drivers, IDS camera drivers, and all Python bindings. The image is built on Ubuntu 20.04 regardless of the host OS, so it works on Ubuntu 20, 22, and 24 hosts (x86 and ARM64).

### Prerequisites

- Docker Engine: https://docs.docker.com/engine/install/
- NVIDIA Container Toolkit (for GPU support in rviz, optional): https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html

### Step 1 — Download IDS packages

The Docker image requires proprietary IDS packages that cannot be redistributed. Download the correct variant for your target architecture from the IDS website:

https://en.ids-imaging.com/download-details/AB02491.html

**For x86 / amd64 (workstation, Ubuntu 20/22/24):**

| File | Download name on IDS site |
|---|---|
| `ids-software-suite-linux-64-4.96.1-debian.tgz` | IDS Software Suite 4.96.1 — Linux 64-bit, Debian |
| `ids-peak-with-ueyetl-linux-x86-2.4.0.0-64.deb` | IDS Peak 2.4.0.0 with uEye Transport Layer — Linux x86 64-bit |

**For arm64 (Jetson, Ubuntu 20.04 or 22.04):**

| File | Download name on IDS site |
|---|---|
| `ids-software-suite-linux-arm64-4.96.1-debian.tgz` | IDS Software Suite 4.96.1 — Linux ARM64, Debian |
| `ids-peak-with-ueyetl-linux-aarch64-2.4.0.0-64.deb` | IDS Peak 2.4.0.0 with uEye Transport Layer — Linux aarch64 |

Place the downloaded files in `event_cam_setup/docker_context/`. The build script extracts the `.deb` files from the `.tgz` automatically.

### Step 2 — Build the image

```bash
git clone git@github.com:FLW-TUDO/event_cam_setup.git
cd event_cam_setup

# Native build (auto-detects amd64 or arm64 from host)
./build_camera_driver.sh

# Or specify architecture explicitly
./build_camera_driver.sh --arch amd64   # x86 workstation
./build_camera_driver.sh --arch arm64   # Jetson (run this on the Jetson itself)
```

**Cross-compiling arm64 on an amd64 host** (alternative to building on the Jetson):

```bash
sudo apt-get install qemu-user-static binfmt-support
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker buildx create --use
./build_camera_driver.sh --arch arm64
```

This produces a local image tagged `camera_driver:latest`.

### Option B — Pull pre-built image (To be updated)

```bash
# If a registry image is available:
docker pull <registry>/camera_driver:latest
docker tag <registry>/camera_driver:latest camera_driver:latest
```

### Running the cameras (live)

```bash
./run_camera_driver.sh
```

This script handles USB device access, the IDS uEye daemon socket, and IPC namespace.

### Visualizing a recorded bag

```bash
./visualize_bag.sh /path/to/bag.bag
```

Works on any machine with Docker and an X display. No ROS host installation needed.

---

## Native Installation (Ubuntu 20.04 + ROS Noetic)

> Native installation is only supported on **Ubuntu 20.04** (x86 or arm64/Jetson JetPack 5).
> For Ubuntu 22.04 or 24.04 — including Jetson JetPack 6 — use Docker.

### 1) ROS Noetic

```bash
sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu focal main" > /etc/apt/sources.list.d/ros-latest.list'
curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add -
sudo apt update
sudo apt install ros-noetic-desktop-full python3-catkin-tools python3-pip
echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc
source ~/.bashrc
```

### 2) DVXplorer ROS Driver

The DVXplorer driver requires `libcaer` from the iniVation PPA.

```bash
sudo add-apt-repository ppa:inivation-ppa/inivation
sudo apt update
sudo apt install libcaer-dev
```

Build the DVXplorer driver in your catkin workspace:

```bash
mkdir -p ~/catkin_ws/src
cd ~/catkin_ws/src
git clone https://github.com/catkin/catkin_simple.git
git clone https://github.com/uzh-rpg/rpg_dvs_ros.git
cd ~/catkin_ws
catkin_make -DCMAKE_BUILD_TYPE=Release
source devel/setup.bash
```

### 3) IDS Camera Driver

Download the correct variant for your machine's architecture:

**amd64 (x86 workstation):** https://en.ids-imaging.com/download-details/AB02491.html

- **IDS Software Suite 4.96.1 (Linux 64-bit, Debian)** — `ids-software-suite-linux-64-4.96.1-debian.tgz`
- **IDS Peak 2.4.0.0 with uEye Transport Layer (Linux x86 64-bit)** — `ids-peak-with-ueyetl-linux-x86-2.4.0.0-64.deb`

**arm64 (Jetson, Ubuntu 20.04 / JetPack 5):** same IDS page, select the ARM64 variants:

- **IDS Software Suite 4.96.1 (Linux ARM64, Debian)** — `ids-software-suite-linux-arm64-4.96.1-debian.tgz`
- **IDS Peak 2.4.0.0 with uEye Transport Layer (Linux aarch64)** — `ids-peak-with-ueyetl-linux-aarch64-2.4.0.0-64.deb`

#### 3.1) Install system dependencies

```bash
sudo apt install \
    libqt5core5a libqt5gui5 libqt5widgets5 libqt5multimedia5 libqt5quick5 \
    qml-module-qtquick-window2 qml-module-qtquick2 \
    qml-module-qtquick-dialogs qml-module-qtquick-controls qml-module-qtquick-layouts \
    qml-module-qt-labs-settings qml-module-qt-labs-folderlistmodel \
    libusb-1.0-0 libatomic1 libcap2 libudev1 libomp5
```

#### 3.2) Install uEye packages

Extract the archive and install the `.deb` packages in this order:

```bash
# Substitute arm64 for amd64 on Jetson
ARCH=$(dpkg --print-architecture)
tar -xvzf ids-software-suite-linux-*-4.96.1-debian.tgz
sudo dpkg -i ueye-api_*_${ARCH}.deb
sudo dpkg -i ueye-common_*_${ARCH}.deb
sudo dpkg -i ueye-driver-usb_*_${ARCH}.deb
sudo dpkg -i ueye-driver-eth_*_${ARCH}.deb
sudo dpkg -i ueye-drivers_*_${ARCH}.deb
sudo apt -f install
```

#### 3.3) Install IDS Peak SDK

```bash
# amd64
sudo dpkg -i ids-peak-with-ueyetl-linux-x86-2.4.0.0-64.deb || sudo apt -f install -y

# arm64 (Jetson)
sudo dpkg -i ids-peak-with-ueyetl-linux-aarch64-2.4.0.0-64.deb || sudo apt -f install -y
```

Set the GenTL path permanently:

```bash
echo "export GENICAM_GENTL64_PATH=/usr/lib/ids/cti" >> ~/.bashrc
source ~/.bashrc
```

#### 3.4) Install Python bindings

The Python wheels are installed at `/usr/local/share/ids/bindings/python/wheel/` by the IDS Peak package. Install the wheel matching your Python version:

```bash
PYVER=$(python3 -c "import sys; print('cp%d%d' % sys.version_info[:2])")
WHEEL_DIR=/usr/local/share/ids/bindings/python/wheel

pip3 install $(ls ${WHEEL_DIR}/ids_peak-*-${PYVER}-*.whl)
pip3 install $(ls ${WHEEL_DIR}/ids_peak_ipl-*-${PYVER}-*.whl)
pip3 install $(ls ${WHEEL_DIR}/ids_peak_afl-*-${PYVER}-*.whl)
```

> Python 3.8 → `cp38`, Python 3.10 → `cp310`, etc.

#### 3.5) Install the IDS ROS camera node

```bash
cd ~/catkin_ws/src
cp -r /path/to/event_cam_setup/docker_context/ids_camera_driver .
cd ~/catkin_ws && catkin_make
```

#### 3.6) Reload udev rules and start the daemon

```bash
sudo udevadm control --reload-rules && sudo udevadm trigger
sudo /opt/ids/ueye/bin/ueyeusbd
```

> **Plug the camera directly into a motherboard USB3 port — not through a hub.** Through a hub, the camera can fail USB3 link-power-management negotiation and repeatedly disconnect/reconnect (`dmesg` shows `Disable of device-initiated U1/U2 failed` followed by `device firmware changed` and a new device number, looping). If that happens, the daemon must be (re)started *after* the camera has finished re-enumerating, not before — see [Troubleshooting](troubleshooting.md#ids-camera-not-detected).

### 4) Verify

```bash
source ~/catkin_ws/devel/setup.bash
roslaunch rgb_event_camera_system RGB_event_cam_stereo.launch
```

In a second terminal:

```bash
rostopic list
# Expected:
# /rgb/image_raw
# /dvxplorer_left/events
# /dvxplorer_right/events
```
