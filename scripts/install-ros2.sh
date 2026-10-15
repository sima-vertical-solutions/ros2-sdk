#!/usr/bin/env bash

# Installs the ROS 2 stack and the source-workspace build tools for the
# platform 3.0 (eLxr bianca / Debian trixie) image.

set -euo pipefail

# ros2 is the trixie build of sima-vertical-solutions/ros2 (branch
# sima/jazzy-trixie): one ros2_<version>_arm64.deb installing under
# /usr/local/ros2, with the rosbag2_storage_mcap CMA page-cache fix. It is not
# on Vulcan -- the trixie CI run stops after its smoke test -- so the deb is
# vendored into the build context and copied to ROS2_DEB_DIR.
#
# rtabmap_ros and navigation have no trixie builds yet; this image ships
# neither. The array stays, empty: provision.sh and gen_release.sh read it out
# of this file to learn which Vulcan packages the image carries, scanning from
# the opening line to a line that starts with ")" -- keep the two on separate lines.
# shellcheck disable=SC2034
readonly -a vulcan_packages=(
)

readonly ROS2_DEB_DIR="${ROS2_DEB_DIR:-/tmp/ros2-deb}"

# Debian provides the colcon CLI and its extensions as separate packages
# rather than the Ubuntu-only python3-colcon-common-extensions metapackage
# used by some ROS documentation. vcstool is likewise the Debian package name.
readonly -a workspace_tools=(
    colcon
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
    python3-colcon-bash
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
    libopencv-dev
    libbullet-dev
    pyqt5-dev
    pyqt5-dev-tools
    python3-pytest
    python3-pyqt5
    python3-lark
)

if [[ "${EUID}" -ne 0 ]]; then
    echo "install-ros2 must run as root" >&2
    exit 1
fi

apt-get update --allow-releaseinfo-change

# Everything that still comes from apt: the colcon toolchain and the headers a
# workspace build needs. None of it is SiMa-specific.
apt-get install -y --no-install-recommends \
    "${workspace_tools[@]}" \
    "${build_dependencies[@]}"

# Exactly one vendored deb; apt resolves its runtime dependencies from trixie.
shopt -s nullglob
ros2_debs=("${ROS2_DEB_DIR}"/ros2_*_arm64.deb)
shopt -u nullglob
if (( ${#ros2_debs[@]} != 1 )); then
    echo "expected exactly one ros2_*_arm64.deb in ${ROS2_DEB_DIR}, found ${#ros2_debs[@]}" >&2
    exit 1
fi
apt-get install -y --no-install-recommends "${ros2_debs[0]}"
rm -rf "${ROS2_DEB_DIR}"

# Colcon's generated setup scripts probe COLCON_CURRENT_PREFIX before defining
# it, so temporarily disable nounset while sourcing the vendor environment.
set +u
# shellcheck disable=SC1091
source /usr/local/ros2/local_setup.bash
set -u

command -v ros2
command -v colcon
command -v vcs
ros2 --help >/dev/null
ros2 pkg prefix rclcpp
ros2 pkg prefix rosbag2_storage_mcap

# The trixie build stamps 2.1.3+<n>.g<sha>; a bare 2.1.3 would be the old
# repo.sima.ai package resolving from apt instead.
dpkg-query -W -f='${Version}\n' ros2 | grep -qE '^2\.1\.3\+' \
    || { echo "ros2 is not the trixie build" >&2; exit 1; }

# The rosbag2 fix is the reason ros2 comes from Vulcan at all. FadviseWriter is
# a class with virtual methods, so its name lands in the typeinfo strings.
mcap_plugin="$(find /usr/local/ros2 -name 'librosbag2_storage_mcap.so' -print -quit)"
grep -aq FadviseWriter "${mcap_plugin}" \
    || { echo "rosbag2 lacks the CMA page-cache fix" >&2; exit 1; }

rm -rf /var/lib/apt/lists/*
