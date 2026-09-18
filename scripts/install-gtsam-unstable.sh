#!/usr/bin/env bash

# Installs GTSAM 4.2.2 with gtsam_unstable, which the drone's visual-inertial
# estimator needs and the packaged GTSAM in this image does not provide.
#
# The image already carries GTSAM 4.2.2 at /usr/local, pulled in by the
# rtabmap_ros platform package (see install-ros2.sh). That build has no
# gtsam_unstable: no libgtsam_unstable.so, no headers, no GTSAM_UNSTABLE CMake
# config. BatchFixedLagSmoother lives there, so VisualOdometry's vo_estimator
# capability -- which calls find_package(GTSAM_UNSTABLE 4.2 REQUIRED CONFIG) --
# cannot configure in this image at all, and the drone release therefore cannot
# build or test its VIO code in CI.
#
# This installs to /opt/gtsam rather than over /usr/local on purpose: the copy
# there belongs to a platform package and rtabmap links against it. Consumers
# opt in with CMAKE_PREFIX_PATH=/opt/gtsam (VisualOdometry's build.sh and
# test.sh already take a GTSAM_PREFIX for exactly this).
#
# The options below match the packaged build on every axis that affects ABI, so
# the two are interchangeable for anything that links either one. Taken from the
# installed config of the packaged copy (GTSAM_USE_TBB 1, GTSAM_DEFAULT_ALLOCATOR
# TBB, find_dependency(Eigen3), metis-gtsam-if in its link interface) and from
# the reference build used for the board measurements. The only deliberate
# difference is GTSAM_BUILD_UNSTABLE.

set -euo pipefail

readonly GTSAM_VERSION="4.2.2"
readonly GTSAM_SHA256="d4420b7ee16fc51cd9afc1f5171d6a315383fc5b58a6375466e7585d90d36d80"
readonly GTSAM_URL="https://codeload.github.com/borglab/gtsam/tar.gz/refs/tags/${GTSAM_VERSION}"
readonly GTSAM_PREFIX="/opt/gtsam"

if [[ "${EUID}" -ne 0 ]]; then
    echo "install-gtsam-unstable must run as root" >&2
    exit 1
fi

apt-get update --allow-releaseinfo-change
apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    libboost-chrono-dev \
    libboost-date-time-dev \
    libboost-filesystem-dev \
    libboost-program-options-dev \
    libboost-regex-dev \
    libboost-serialization-dev \
    libboost-system-dev \
    libboost-thread-dev \
    libboost-timer-dev \
    libeigen3-dev \
    libtbb-dev

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

archive="${work_dir}/gtsam.tar.gz"
curl --fail --location --silent --show-error \
    --retry 3 \
    --retry-all-errors \
    --output "${archive}" \
    "${GTSAM_URL}"
echo "${GTSAM_SHA256}  ${archive}" | sha256sum --check --strict

tar --extract --gzip --file "${archive}" --directory "${work_dir}"
source_dir="${work_dir}/gtsam-${GTSAM_VERSION}"
build_dir="${work_dir}/build"

# GTSAM_USE_SYSTEM_EIGEN matters most: the estimator's public headers pass Eigen
# types across the library boundary, so GTSAM and its callers must agree on one
# Eigen. march=native is off so the image stays portable across hosts.
#
# CMAKE_INSTALL_RPATH is not optional at a non-default prefix. With
# SUPPORT_NESTED_DISSECTION the build installs its own libmetis-gtsam.so beside
# libgtsam.so, and GTSAM sets no RUNPATH on its libraries. DT_RUNPATH is not
# inherited by transitive lookups, so a consumer that bakes this prefix into its
# own RUNPATH still would not resolve metis: the binary links, and then fails to
# start with "libmetis-gtsam.so: cannot open shared object file". Verified: that
# is exactly what happens without this line.
cmake -S "${source_dir}" -B "${build_dir}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${GTSAM_PREFIX}" \
    -DCMAKE_INSTALL_RPATH="${GTSAM_PREFIX}/lib" \
    -DBUILD_SHARED_LIBS=ON \
    -DGTSAM_BUILD_UNSTABLE=ON \
    -DGTSAM_USE_SYSTEM_EIGEN=ON \
    -DGTSAM_WITH_TBB=ON \
    -DGTSAM_USE_QUATERNIONS=OFF \
    -DGTSAM_SUPPORT_NESTED_DISSECTION=ON \
    -DGTSAM_USE_SYSTEM_METIS=OFF \
    -DGTSAM_BUILD_WITH_MARCH_NATIVE=OFF \
    -DGTSAM_BUILD_TESTS=OFF \
    -DGTSAM_BUILD_EXAMPLES_ALWAYS=OFF \
    -DGTSAM_BUILD_TIMING_ALWAYS=OFF \
    -DGTSAM_BUILD_PYTHON=OFF \
    -DGTSAM_UNSTABLE_BUILD_PYTHON=OFF \
    -DGTSAM_INSTALL_MATLAB_TOOLBOX=OFF \
    -DGTSAM_UNSTABLE_INSTALL_MATLAB_TOOLBOX=OFF \
    -DGTSAM_INSTALL_CPPUNITLITE=OFF

cmake --build "${build_dir}" --parallel "$(nproc)"
cmake --install "${build_dir}"

# Not added to /etc/ld.so.conf.d: this prefix is opt-in, and consumers bake the
# path into their RUNPATH (CMAKE_INSTALL_RPATH_USE_LINK_PATH). Putting it on the
# default loader path would let it shadow the platform copy for everything.
test -e "${GTSAM_PREFIX}/lib/libgtsam.so"
test -e "${GTSAM_PREFIX}/lib/libgtsam_unstable.so"
test -f "${GTSAM_PREFIX}/include/gtsam_unstable/nonlinear/BatchFixedLagSmoother.h"
test -f "${GTSAM_PREFIX}/lib/cmake/GTSAM/GTSAMConfig.cmake"
test -f "${GTSAM_PREFIX}/lib/cmake/GTSAM_UNSTABLE/GTSAM_UNSTABLEConfig.cmake"

# Compile, link and run the one class this exists for. A successful build of
# GTSAM proves little on its own: the unstable target is separate, and getting
# it linked is the whole point.
#
# -ltbb/-ltbbmalloc are spelled out because this link line is hand-written. A
# consumer using find_package(GTSAM) gets them from the imported target's
# INTERFACE_LINK_LIBRARIES and needs to name neither.
printf '%s\n' \
    '#include <gtsam_unstable/nonlinear/BatchFixedLagSmoother.h>' \
    '#include <cstdio>' \
    'int main() {' \
    '  gtsam::BatchFixedLagSmoother smoother(3.0);' \
    '  std::printf("BatchFixedLagSmoother lag=%.1f\n", smoother.smootherLag());' \
    '}' \
    | c++ -x c++ -std=c++17 - -o "${work_dir}/gtsam-unstable-check" \
        -I"${GTSAM_PREFIX}/include" -I/usr/include/eigen3 \
        -L"${GTSAM_PREFIX}/lib" -Wl,-rpath,"${GTSAM_PREFIX}/lib" \
        -lgtsam -lgtsam_unstable -ltbb -ltbbmalloc
"${work_dir}/gtsam-unstable-check"
