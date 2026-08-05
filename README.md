# ROS 2 SDK for Modalix

This repository builds the Modalix 2.1.2 SDK container from
[`Dockerfile.modalix`](https://github.com/SiMa-ai/swsoc-simaai-elxr-doc/blob/master/Dockerfile.modalix)
and publishes ARM64-only images to GitHub Container Registry.

## Temporary solution for the 2.1.* release line

This repository is a temporary solution for the 2.1.* SDK release line. The
current SiMa Neat SDK is based on Ubuntu 24.04 and cannot be used to build the
ROS 2-related packages required for this target, so this repository provides a
separate Debian-based SDK container for those builds.

The long-term plan is to move the SiMa Neat SDK to a Debian 13 base and
consolidate ROS 2 and Neat development into a single SDK. Once that transition
is complete, this separate ROS 2 SDK should no longer be necessary.

## Images

The `main` branch publishes the canonical image:

```text
ghcr.io/sima-vertical-solutions/ros2-sdk:latest
ghcr.io/sima-vertical-solutions/ros2-sdk:main
ghcr.io/sima-vertical-solutions/ros2-sdk:sha-<commit>
```

Other branches publish an isolated package named from a lowercase, sanitized
branch name. For example, `feature/add-navigation` publishes:

```text
ghcr.io/sima-vertical-solutions/ros2-sdk-feature-add-navigation:latest
ghcr.io/sima-vertical-solutions/ros2-sdk-feature-add-navigation:sha-<commit>
```

Version tags beginning with `v` publish matching tags on the canonical package.
Pull requests build the image without publishing it.

## ROS 2 packages

Image builds run on GitHub's native `ubuntu-24.04-arm` runner. They do not need
access to the SiMa corporate network or `sw-web.eng.sima.ai`.

The image installs `ros2`, `rtabmap-ros`, `simaai-rtabmap`, and
`vdp-navigation` from the signed SiMa release repository at
`https://repo.sima.ai/elxr/deb/release`. It also installs the Debian `colcon`
components, `vcstool`, and ROS 2 workspace build dependencies described by the
[ROS 2 setup documentation](https://sima-ai.atlassian.net/wiki/spaces/STMS/pages/3902799894/Setup+ROS2+in+eLxr+on+the+Board).

[`scripts/install-ros2.sh`](scripts/install-ros2.sh) contains the installation
and smoke-test procedure invoked by the Docker build. The script verifies that
all four SiMa ROS packages are available from the release repository before it
installs them. The internal `/deb/custom` mirror is intentionally excluded; it
is only required for custom/develop package builds.

## RealSense SDK

The image builds RealSense SDK 2.58.1 from its pinned upstream release archive
and installs the headers, shared libraries, CMake metadata, and command-line
tools into `/usr/local`. The archive checksum is verified before extraction.

[`scripts/install-realsense.sh`](scripts/install-realsense.sh) implements the
[STIGA stack bring-up procedure](https://sima-ai.atlassian.net/wiki/spaces/VP/pages/3987898369/STIGA+STACK+BRINGUP+-+VISTA+V1)
using the RSUSB backend, ARM64 NEON optimizations, and no CUDA, DDS, rosbag2,
Python bindings, examples, or unit tests. Non-graphical tools remain enabled so
`rs-enumerate-devices` is available on a USB-connected DevKit.

CI verifies the installed header and shared library and compiles, links, and
runs a hardware-independent API probe. Actual camera enumeration must be run
on the DevKit:

```bash
rs-enumerate-devices
```

## Buildx cache

CI builds and publishes images directly with Docker Buildx. Branch builds
import both their own GHCR registry cache and the `main` fallback cache, then
update only their branch cache. Same-repository pull requests import their
source branch cache plus `main`, but cannot update either cache. Version tags
reuse a matching `release-X.Y` cache when available and otherwise fall back to
`main`.

Build caches are stored in the internal
`ghcr.io/sima-vertical-solutions/ros2-sdk-buildcache` package and are not
runnable SDK images. Cleanup removes cache versions for deleted branches and
untagged cache versions older than seven days.

All published images target `linux/arm64` only. Pull one explicitly with:

```bash
docker pull --platform linux/arm64 \
  ghcr.io/sima-vertical-solutions/ros2-sdk:latest
```

When a branch is deleted, its branch-specific GHCR package is deleted. A daily
reconciliation run removes an orphaned branch package if the delete event was
missed. Cleanup verifies that a package belongs to this repository before
deleting it.
