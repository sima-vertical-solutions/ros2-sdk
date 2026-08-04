#!/usr/bin/env bash

# Installs the released ROS 2 stack and the source-workspace build tools from:
# https://sima-ai.atlassian.net/wiki/spaces/STMS/pages/3902799894/
# Setup+ROS2+in+eLxr+on+the+Board
#
# The internal /deb/custom mirror is intentionally not configured here. It is
# reserved for custom/develop builds; released packages must come from the
# signed https://repo.sima.ai/elxr/deb/release repository.

set -euo pipefail

readonly SIMAAI_RELEASE_REPOSITORY="https://repo.sima.ai/elxr/deb/release"

readonly -a ros_packages=(
    ros2
    simaai-rtabmap
    vdp-navigation
    rtabmap-ros
)

# Debian bookworm provides colcon as separate component packages rather than
# the Ubuntu-only python3-colcon-common-extensions metapackage used by some ROS
# documentation. vcstool is likewise the Debian package name.
readonly -a workspace_tools=(
    python3-colcon-argcomplete
    python3-colcon-cmake
    python3-colcon-core
    python3-colcon-output
    python3-colcon-package-selection
    python3-colcon-parallel-executor
    python3-colcon-python-setup-py
    python3-colcon-recursive-crawl
    python3-colcon-ros
    python3-colcon-test-result
    vcstool
)

readonly -a build_dependencies=(
    build-essential
    libasio-dev
    libacl1-dev
    libtinyxml2-dev
    libssl-dev
    xorg
    libx11-dev
    libxt-dev
    libxaw7-dev
    libogre-1.12-dev
    liblttng-ctl-dev
    liblttng-ust-dev
    pkg-config
    libeigen3-dev
    libfreetype-dev
    libgl-dev
    qtbase5-dev
    libxrandr-dev
    sip-dev
    libopencv-dev
    libbullet-dev
    pyqt5-dev
    pyqt5-dev-tools
    python3-pytest
    python3-pyqt5
    python3-lark
    python3-sip
    python3-sip-dev
)

if [[ "${EUID}" -ne 0 ]]; then
    echo "install-ros2 must run as root" >&2
    exit 1
fi

apt-get update --allow-releaseinfo-change

for package in "${ros_packages[@]}"; do
    policy="$(apt-cache policy "${package}")"
    printf '%s\n' "${policy}"

    if grep -Fq 'Candidate: (none)' <<< "${policy}"; then
        echo "No installation candidate found for ${package}" >&2
        exit 1
    fi

    if ! grep -Fq "${SIMAAI_RELEASE_REPOSITORY}" <<< "${policy}"; then
        echo "${package} is not available from ${SIMAAI_RELEASE_REPOSITORY}" >&2
        exit 1
    fi
done

apt-get install -y --no-install-recommends \
    "${ros_packages[@]}" \
    "${workspace_tools[@]}" \
    "${build_dependencies[@]}"

# Use local_setup.bash for the prebuilt overlays. The full RTAB-Map setup file
# contains paths from its original build environment in the current release.
# shellcheck disable=SC1091
source /usr/local/ros2/local_setup.bash
# shellcheck disable=SC1091
source /usr/local/rosbot_navigation/local_setup.bash
# shellcheck disable=SC1091
source /usr/local/rtabmap-ros/local_setup.bash

command -v ros2
command -v colcon
command -v vcs
ros2 --help >/dev/null
ros2 pkg prefix nav2_bringup
ros2 pkg prefix rtabmap_slam

rm -rf /var/lib/apt/lists/*
