⬅️ Back to [Home](index.md)

# Troubleshooting

## IDS Camera Not Detected

**Symptom:** `ids_peak` raises `DeviceNotFound` or no `/rgb/image_raw` topic.

- Check the uEye daemon is running: `ps aux | grep ueyeusbd`
- If not running: `sudo /opt/ids/ueye/bin/ueyeusbd`
- Verify `GENICAM_GENTL64_PATH=/usr/lib/ids/cti` is set
- Reload udev rules: `sudo udevadm control --reload-rules && sudo udevadm trigger`
- The IDS camera uses USB vendor class — make sure `ids_ueyegentl.cti` is used, not `ids_u3vgentl.cti`

**Docker-specific:** The container requires both `/run/ueyed` socket mount and `--ipc=host`. Both are handled by `run_camera_driver.sh`.

**Native-specific — `devices: 0` even though `ueyeusbd` is running and recognizes the camera in its own log (`Model: UI304xCP-C ... FW`):**

Check whether `ueye-api` actually finished installing:

```bash
dpkg -l | grep ueye-api
```

If the status column shows `iF` (half-configured) instead of `ii`, the package's postinst never completed — usually because a previous install/upgrade left a stale symlink and a plain `ln` in the postinst failed (`ln: failed to create symbolic link '.../libueye_api.so.4.96': File exists`), silently leaving `ueye-api` broken. The daemon still talks to the camera over its own protocol (hence the daemon log looking fine), but `ids_peek`'s GenTL producer depends on the fully-configured library, so it reports 0 devices no matter what the USB/permissions/daemon state is. Fix:

```bash
sudo rm -f /opt/ids/ueye/lib/x86_64-linux-gnu/libueye_api.so.4.96
sudo dpkg --configure -a
sudo ldconfig
```

Then confirm `dpkg -l | grep ueye-api` shows `ii`, restart `ueyeusbd`, and re-check device detection.

**Native-specific — camera keeps resetting itself / `devices: 0` even though the daemon is running and permissions look correct:**

Check `dmesg | grep -i "usb.*1409\|device firmware changed"`. If you see the camera repeatedly disconnect/reconnect on its own (`device firmware changed` → `USB disconnect` → `new SuperSpeed USB device number N+1`, looping every few seconds/minutes) preceded by `Disable of device-initiated U1 failed` / `U2 failed`, this is a USB3 link-power-management negotiation failure — usually caused by the camera being connected through a **USB hub** rather than directly into a motherboard USB3 port.

- Plug the camera directly into a USB3 port on the motherboard, not through a hub.
- Use a short, good-quality USB3 cable.
- After fixing the connection (or as a workaround if you can't), restart `ueyeusbd` *after* the camera has finished re-enumerating — if the daemon started before the camera settled on its final USB device number, it never picks up the device:
  ```bash
  sudo pkill -9 ueyeusbd
  sudo rm -f /run/ueyed/ueyeusbd.pid
  sudo /opt/ids/ueye/bin/ueyeusbd -c /etc/ids/ueye/ueyeusbd.conf -P /run/ueyed/ueyeusbd.pid
  ```
- Don't start `ueyeusbd` at boot before the camera is plugged in — there's currently no udev-triggered restart, so the daemon must be (re)started after the camera is connected and has stopped re-enumerating.

---

## DVXplorer Not Detected

**Symptom:** No `/dvxplorer_left/events` topic, driver exits immediately.

- Check USB connection: `lsusb | grep -i inivation`
- Verify `libcaer` is installed: `dpkg -l | grep libcaer`
- Check serial numbers in the launch file match your devices: `DXA00420` (left), `DXA00247` (right)

---

## Missing ROS Topics

- Source the correct workspace: `source ~/catkin_ws/devel/setup.bash`
- Check all nodes started: `rosnode list`
- Verify `ROS_MASTER_URI` is set correctly (especially in multi-machine setups)

---

## Rosbag Buffer Overflow

**Symptom:** `rosbag record buffer exceeded. Dropping oldest queued message.`

- Already handled in `record.launch` with `--buffsize=1024 --lz4`
- If it persists, check disk write speed: `dd if=/dev/zero of=/tmp/test bs=1M count=512 oflag=dsync`

---

## Rviz Shows "No Image"

- Verify topics are publishing: `rostopic hz /rgb/image_raw /dvs_rendering_left`
- Check `ROS_MASTER_URI` matches between rosbag and rviz processes
- If using `visualize_bag.sh`, wait ~10s for all nodes to start before expecting data

---

## Kalibr Optimization Failed

Increase `timeOffsetPadding` in `kalibr_calibrate_imu_camera.py`. Higher value is more robust but slower.

---

## e2calib GPU Out of Memory

Reduce `--freq_hz` or process shorter bag segments.
