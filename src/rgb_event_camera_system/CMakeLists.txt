cmake_minimum_required(VERSION 3.0.2)
project(rgb_event_camera_system)

find_package(catkin REQUIRED)

catkin_package()

install(DIRECTORY launch/
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/launch
)

install(DIRECTORY rviz/
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/rviz
)

catkin_install_python(PROGRAMS
  scripts/export_bag_videos.py
  scripts/extract_bag.py
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

install(PROGRAMS
  scripts/record.sh
  scripts/record_docker.sh
  scripts/visualize_bag.sh
  scripts/export_bag_video.sh
  scripts/preview_jetson.sh
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)
