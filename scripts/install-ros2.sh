#!/usr/bin/env bash

# Installs the released ROS 2 stack and the source-workspace build tools from:
# https://sima-ai.atlassian.net/wiki/spaces/STMS/pages/3902799894/
# Setup+ROS2+in+eLxr+on+the+Board
#
# The ROS 2 packages come from Vulcan via sima-cli. repo.sima.ai stays
# configured in the image for the platform packages -- simaai-sdk-tools, the
# kernel headers and so on -- but no longer serves the ROS 2 stack.

set -euo pipefail

# The ROS 2 stack comes from Vulcan, not repo.sima.ai. Those are different
# packages built from different sources: repo.sima.ai serves the Jenkins builds
# from Bitbucket, while these are built from the sima-vertical-solutions GitHub
# repositories on GitHub ARM64 runners.
#
# What that changes, beyond provenance:
#
#   ros2         carries the CMA page-cache eviction fix in
#                rosbag2_storage_mcap, without which a long MCAP recording
#                starves the SoC's contiguous memory allocator. The
#                repo.sima.ai build does not have it; the patched plugin used
#                to be copied over the installed one by hand.
#   rtabmap_ros  supersedes simaai-rtabmap AND rtabmap-ros -- one package now
#                ships gtsam, rtabmap and rtabmap-ros together, at the
#                0.22.1 / 0.22.0 pairing the board expects.
#   navigation   replaces vdp-navigation, and installs under
#                /usr/local/navigation rather than /usr/local/rosbot_navigation.
#
# ros2 is pinned to a tag. rtabmap_ros and navigation track their branches
# because neither has a release tag yet -- tag them and pin these too, so an
# SDK image is reproducible rather than dependent on when it was built.
readonly -a vulcan_packages=(
    "ros2@v2.1.3"
    "rtabmap_ros@develop"
    "navigation@jazzy"
)

readonly SIMA_CLI_INSTALLER="https://artifacts.neat.sima.ai/sima-cli/linux-mac.sh"

# Debian bookworm provides the colcon CLI and its extensions as separate
# packages rather than the Ubuntu-only python3-colcon-common-extensions
# metapackage used by some ROS documentation. vcstool is likewise the Debian
# package name.
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

# Everything that still comes from apt: the colcon toolchain and the headers a
# workspace build needs. None of it is SiMa-specific.
apt-get install -y --no-install-recommends \
    "${workspace_tools[@]}" \
    "${build_dependencies[@]}"

# sima-cli needs no credentials -- the artifact store is plain HTTPS. Its
# installer shells out to sudo, which this image does not have because it runs
# as root, so give it a shim and remove it again rather than leaving a fake
# sudo behind.
apt-get install -y --no-install-recommends python3-venv python3-pip
printf '#!/bin/sh\nexec "$@"\n' > /usr/local/bin/sudo
chmod 755 /usr/local/bin/sudo
curl -fsSL "${SIMA_CLI_INSTALLER}" | bash
export PATH="${HOME}/.sima-cli/.venv/bin:${HOME}/.local/bin:${PATH}"

# Each package is downloaded into its own directory. sima-cli installs by
# globbing the debs it finds, so a shared directory would let one package's
# leftovers be picked up by the next.
for spec in "${vulcan_packages[@]}"; do
    echo "== ${spec}"
    workdir="$(mktemp -d)"
    SIMA_CLI_CHECK_FOR_UPDATE=0 sima-cli neat install --prod -d "${workdir}" "${spec}"
    rm -rf "${workdir}"
done

rm -f /usr/local/bin/sudo

# Use local_setup.bash for the prebuilt overlays. The full RTAB-Map setup file
# contains paths from its original build environment in the current release.
# Colcon's generated setup scripts probe COLCON_CURRENT_PREFIX before defining
# it, so temporarily disable nounset while sourcing the vendor environment.
set +u
# shellcheck disable=SC1091
source /usr/local/ros2/local_setup.bash
# shellcheck disable=SC1091
source /usr/local/navigation/local_setup.bash
# shellcheck disable=SC1091
source /usr/local/rtabmap-ros/local_setup.bash
set -u

command -v ros2
command -v colcon
command -v vcs
ros2 --help >/dev/null
ros2 pkg prefix nav2_bringup
ros2 pkg prefix rtabmap_slam

# Assert the packages are the Vulcan builds, not repo.sima.ai's. Presence alone
# would not notice a fallback: the old names still resolve from apt.
dpkg-query -W -f='${Version}\n' ros2 | grep -qx '2.1.3' \
    || { echo "ros2 is not the pinned 2.1.3 build" >&2; exit 1; }
for package in rtabmap rtabmap-ros navigation; do
    dpkg-query -W -f='${Version}\n' "${package}" | grep -q '+' \
        || { echo "${package} lacks a commit suffix -- not a Vulcan build" >&2; exit 1; }
done

# The rosbag2 fix is the reason ros2 comes from Vulcan at all. FadviseWriter is
# a class with virtual methods, so its name lands in the typeinfo strings.
mcap_plugin="$(find /usr/local/ros2 -name 'librosbag2_storage_mcap.so' -print -quit)"
grep -aq FadviseWriter "${mcap_plugin}" \
    || { echo "rosbag2 lacks the CMA page-cache fix" >&2; exit 1; }

rm -rf /var/lib/apt/lists/*
