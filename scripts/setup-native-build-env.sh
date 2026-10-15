#!/usr/bin/env bash

# Configure native ARM64 application builds while exposing the prebuilt Neat
# SDK as a dependency prefix. This intentionally does not set CROSS_COMPILE or
# pass --sysroot: the container and Modalix DevKit are both Debian 12 ARM64.

if [[ "$(dpkg --print-architecture)" != "arm64" ]]; then
    echo "The ROS 2 SDK supports native ARM64 builds only" >&2
    return 1
fi

export NEAT_SDK_ROOT="${NEAT_SDK_ROOT:-/opt/toolchain/aarch64/modalix}"

unset CROSS_COMPILE SYSROOT CPPFLAGS LD STRIP OBJDUMP OBJCOPY AR

export CC=/usr/bin/gcc
export CXX=/usr/bin/g++

# Search the host headers first. Neat headers are deliberately added with
# -idirafter so the dependency prefix's libc headers cannot shadow Debian's
# native host headers.
export CFLAGS="-idirafter ${NEAT_SDK_ROOT}/usr/include -idirafter ${NEAT_SDK_ROOT}/usr/include/simaai"
export CXXFLAGS="${CFLAGS}"

export LDFLAGS="-L/usr/lib/aarch64-linux-gnu -L${NEAT_SDK_ROOT}/usr/lib/aarch64-linux-gnu"
export PKG_CONFIG_PATH="${NEAT_SDK_ROOT}/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig"
export CMAKE_LIBRARY_PATH="${NEAT_SDK_ROOT}/usr/lib:${NEAT_SDK_ROOT}/usr/lib/aarch64-linux-gnu:${NEAT_SDK_ROOT}/usr/lib/aarch64-linux-gnu/blas:${NEAT_SDK_ROOT}/usr/lib/aarch64-linux-gnu/lapack"
export OpenCV_DIR="${NEAT_SDK_ROOT}/usr/lib/aarch64-linux-gnu/cmake/opencv4"
export CODEC_INCLUDE_DIRS="${NEAT_SDK_ROOT}/usr/include/simaai/codec"
