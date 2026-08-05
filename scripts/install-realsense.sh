#!/usr/bin/env bash

# Installs the RealSense SDK required by the STIGA stack:
# https://sima-ai.atlassian.net/wiki/spaces/VP/pages/3987898369/
# STIGA+STACK+BRINGUP+-+VISTA+V1

set -euo pipefail

readonly LIBREALSENSE_VERSION="2.58.1"
readonly LIBREALSENSE_SHA256="14409c3b810bf1508b87f46d47608a89018743b8a73d5855ab5d1ad18763fd8c"
readonly LIBREALSENSE_URL="https://codeload.github.com/realsenseai/librealsense/tar.gz/refs/tags/v${LIBREALSENSE_VERSION}"

if [[ "${EUID}" -ne 0 ]]; then
    echo "install-realsense must run as root" >&2
    exit 1
fi

apt-get update --allow-releaseinfo-change
apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    libssl-dev \
    libudev-dev \
    libusb-1.0-0-dev \
    pkg-config

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

archive="${work_dir}/librealsense.tar.gz"
curl --fail --location --silent --show-error \
    --retry 3 \
    --retry-all-errors \
    --output "${archive}" \
    "${LIBREALSENSE_URL}"
echo "${LIBREALSENSE_SHA256}  ${archive}" | sha256sum --check --strict

tar --extract --gzip --file "${archive}" --directory "${work_dir}"
source_dir="${work_dir}/librealsense-${LIBREALSENSE_VERSION}"
build_dir="${work_dir}/build"

# The STIGA page recommends RSUSB when the kernel backend crashes. Use it in
# the portable SDK build so applications do not depend on patched V4L2 kernel
# modules. DDS and rosbag2 are not needed by the USB camera integration.
cmake -S "${source_dir}" -B "${build_dir}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DFORCE_RSUSB_BACKEND=ON \
    -DFORCE_LIBUVC=OFF \
    -DBUILD_WITH_DDS=OFF \
    -DBUILD_ROSBAG2=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_GRAPHICAL_EXAMPLES=OFF \
    -DBUILD_TOOLS=ON \
    -DBUILD_PYTHON_BINDINGS=OFF \
    -DBUILD_UNIT_TESTS=OFF \
    -DBUILD_WITH_OPENMP=OFF \
    -DBUILD_WITH_CUDA=OFF \
    -DBUILD_WITH_NEON=ON \
    -DIMPORT_DEPTH_CAM_FW=OFF \
    -DCHECK_FOR_UPDATES=OFF

cmake --build "${build_dir}" --parallel "$(nproc)"
cmake --install "${build_dir}"
ldconfig

command -v rs-enumerate-devices
test -f /usr/local/include/librealsense2/rs.h
test -e /usr/local/lib/librealsense2.so

# Compile, link, and execute an API-only probe. Camera enumeration belongs on
# a USB-connected DevKit and cannot be exercised in GitHub-hosted CI.
printf '%s\n' \
    '#include <librealsense2/rs.h>' \
    '#include <iostream>' \
    'int main() { std::cout << rs2_get_api_version(nullptr) << "\\n"; }' \
    | c++ -x c++ - -o "${work_dir}/realsense-api-check" -lrealsense2
"${work_dir}/realsense-api-check"

rm -rf /var/lib/apt/lists/*
