#!/usr/bin/env bash

# Installs GTSAM 4.2.2 with gtsam_unstable at /opt/gtsam.
#
# The GTSAM at /usr/local comes with the rtabmap_ros platform package, built without
# gtsam_unstable -- where BatchFixedLagSmoother lives. VisualOdometry's vo_estimator
# calls find_package(GTSAM_UNSTABLE 4.2 REQUIRED CONFIG) and cannot configure without it.
#
# Same version, separate prefix: /usr/local belongs to a platform package rtabmap links
# against. Every ABI-affecting option matches that build; only GTSAM_BUILD_UNSTABLE
# differs. 14 MB.
#
# The install is unconditional; what is opt-in is USING it. /opt/gtsam is on neither the
# loader path nor CMAKE_PREFIX_PATH, so a build sees it only by naming it -- e.g. the
# GTSAM_PREFIX that VisualOdometry's build.sh and test.sh take. The checks at the end
# assert rtabmap still resolves the platform copy.

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

# USE_SYSTEM_EIGEN: the estimator's headers pass Eigen types across the library
# boundary, so GTSAM and its callers must agree on one Eigen.
#
# CMAKE_INSTALL_RPATH is required at a non-default prefix: NESTED_DISSECTION installs
# libmetis-gtsam.so beside libgtsam.so with no RUNPATH, and DT_RUNPATH is not inherited
# by transitive lookups -- without this the consumer links, then dies at startup with
# "libmetis-gtsam.so: cannot open shared object file".
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

# Deliberately NOT added to /etc/ld.so.conf.d: on the default loader path this copy
# would shadow the platform one for every process in the image.
test -e "${GTSAM_PREFIX}/lib/libgtsam.so"
test -e "${GTSAM_PREFIX}/lib/libgtsam_unstable.so"
test -f "${GTSAM_PREFIX}/include/gtsam_unstable/nonlinear/BatchFixedLagSmoother.h"
test -f "${GTSAM_PREFIX}/lib/cmake/GTSAM/GTSAMConfig.cmake"
test -f "${GTSAM_PREFIX}/lib/cmake/GTSAM_UNSTABLE/GTSAM_UNSTABLEConfig.cmake"

# Compile, link and RUN the one class this exists for -- building GTSAM proves little,
# the unstable target is separate. -ltbb/-ltbbmalloc only because this link line is
# hand-written; find_package(GTSAM) supplies them.
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

# --- rtabmap must be untouched by the above -------------------------------------------
# install-ros2 runs long before this script, so this asserts on the real thing. Any
# failure fails the image build, so every future build re-proves it.
ldconfig

# 1. This prefix must not be in the loader cache: there it would shadow the platform
#    copy for every process in the image.
if ldconfig -p | grep -F "${GTSAM_PREFIX}"; then
    echo "install-gtsam-unstable: ${GTSAM_PREFIX} reached the loader cache -- it would shadow the platform GTSAM" >&2
    exit 1
fi

# 2. rtabmap's libraries must still resolve libgtsam from /usr/local -- the loader's
#    answer, not ours.
rtabmap_prefix=$(ls -d /usr/local/rtabmap* 2>/dev/null | head -1 || true)
if [[ -z "${rtabmap_prefix}" ]]; then
    echo "install-gtsam-unstable: no /usr/local/rtabmap* -- install-ros2 changed, update this check" >&2
    exit 1
fi
checked=0
while read -r lib; do
    objdump -p "${lib}" 2>/dev/null | grep -q 'NEEDED.*libgtsam' || continue
    # Matched on the whole ldd line, not a field index: an unresolved entry reads
    # "libgtsam.so.4.2 => not found", whose third field is the word "not" -- which an
    # emptiness test silently accepts.
    line=$(ldd "${lib}" 2>/dev/null | grep -m1 libgtsam || true)
    case "${line}" in
        *"not found"*)
            echo "install-gtsam-unstable: ${lib} cannot resolve libgtsam" >&2; exit 1 ;;
    esac
    resolved=${line##*=> }; resolved=${resolved%% *}
    echo "  ${lib##*/} -> ${resolved:-<none>}"
    case "${resolved}" in
        "${GTSAM_PREFIX}"/*)
            echo "install-gtsam-unstable: ${lib} resolved GTSAM from ${GTSAM_PREFIX}" >&2
            exit 1 ;;
        "") echo "install-gtsam-unstable: ${lib}: ldd named no libgtsam path" >&2; exit 1 ;;
    esac
    checked=$((checked + 1))
done < <(find "${rtabmap_prefix}" -name '*.so*' -type f 2>/dev/null)
echo "  rtabmap libraries linking GTSAM, checked: ${checked}"

# 3. rtabmap's packages still come up under ros2. `set +u`: the ROS setup scripts read
#    unset variables.
set +u
# shellcheck source=/dev/null
source /usr/local/ros2/setup.bash
# shellcheck source=/dev/null
source "${rtabmap_prefix}/local_setup.bash"
set -u
pkgs=$(ros2 pkg list | grep -c '^rtabmap' || true)
echo "  ros2 pkg list: ${pkgs} rtabmap packages"
[[ "${pkgs}" -gt 0 ]] || { echo "install-gtsam-unstable: ros2 pkg list shows no rtabmap packages" >&2; exit 1; }
ros2 pkg prefix rtabmap_slam
