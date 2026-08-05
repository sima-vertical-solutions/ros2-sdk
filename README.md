# ROS 2 SDK for Modalix

This repository builds the Modalix 2.1.2 SDK container from
[`Dockerfile.modalix`](https://github.com/SiMa-ai/swsoc-simaai-elxr-doc/blob/master/Dockerfile.modalix)
and publishes ARM64-only images to GitHub Container Registry.

## Install the SDK

ROS 2 SDK installation requires `sima-cli` 2.1.16 or newer.

```bash
sima-cli neat install ros2-sdk
```

The command downloads the matching GHCR image and guides you through
`sima-cli sdk setup`. If the package requires authentication, authorize GitHub
CLI with an account that has access:

```bash
gh auth login --hostname github.com --git-protocol https --web
```

Every image records its identity in `/etc/sdk-release`. Tagged builds use the
tag as the version. Branch builds use `branch:githash:buildtime`:

```text
Product Name = SiMa.ai ROS2 SDK
Version = main:0123456789ab:20260805T144500Z
```

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

Image builds run on GitHub's native `ubuntu-24.04-arm` runner.

The image installs `ros2`, `rtabmap-ros`, `simaai-rtabmap`, and
`vdp-navigation` from the signed SiMa release repository at
`https://repo.sima.ai/elxr/deb/release`. It also installs the Debian `colcon`
components, `vcstool`, and ROS 2 workspace build dependencies.

[`scripts/install-ros2.sh`](scripts/install-ros2.sh) contains the installation
and smoke-test procedure invoked by the Docker build. The script verifies that
all four SiMa ROS packages are available from the release repository before it
installs them.

## Native ARM64 builds

The ROS 2 SDK compiles applications natively with the container's ARM64 GCC and
G++. It does not activate the Neat SDK's cross-compilation environment and does
not pass `--sysroot`. The container and Modalix DevKit both use Debian 12 on
ARM64, so native compilation also allows ROS 2 to resolve its host-installed
development dependencies normally.

[`scripts/setup-native-build-env.sh`](scripts/setup-native-build-env.sh) makes
the prebuilt Neat headers and libraries available as an additional dependency
prefix without replacing the host compiler or system headers.
[`scripts/setup-shell-env.sh`](scripts/setup-shell-env.sh) also sources the ROS
2 overlays system-wide for every interactive user, including users dynamically
created by an SDK launcher. After switching an existing workspace from a
cross-built image, remove its cached CMake configuration with a clean build:

```bash
./build.sh <package-name> --clean
```

## RealSense SDK

The image builds RealSense SDK 2.58.1 from its pinned upstream release archive
and installs the headers, shared libraries, CMake metadata, and command-line
tools into `/usr/local`. The archive checksum is verified before extraction.

[`scripts/install-realsense.sh`](scripts/install-realsense.sh) builds the SDK
using the RSUSB backend, ARM64 NEON optimizations, and no CUDA, DDS, rosbag2,
Python bindings, examples, or unit tests. Non-graphical tools remain enabled so
`rs-enumerate-devices` is available on a USB-connected DevKit.

CI verifies the installed header and shared library and compiles, links, and
runs a hardware-independent API probe. Actual camera enumeration must be run
on the DevKit:

```bash
rs-enumerate-devices
```

## SiMa CLI

The image includes SiMa CLI 2.1.15 as `/usr/local/bin/sima-cli` for both
interactive shells and non-interactive automation. The platform-independent
wheel is pinned and checksum-verified, then installed into an isolated virtual
environment under `/opt/sima-cli`.

[`scripts/install-sima-cli.sh`](scripts/install-sima-cli.sh) is the
container-oriented equivalent of the published
[`linux-mac.sh`](https://artifacts.neat.sima.ai/sima-cli/linux-mac.sh)
installer. It deliberately avoids mutable latest-version resolution and shell
aliases, and verifies the installed CLI version during the image build.

## GitHub access

Git, OpenSSH client, and GitHub CLI (`gh`) are preinstalled. SSH-form GitHub
repository URLs such as `git@github.com:owner/repository.git` are rewritten to
HTTPS, and Git is preconfigured to use the GitHub CLI credential helper. No
GitHub token or SSH private key is included in the image.

Authenticate once inside a new container before cloning private repositories
or initializing private submodules:

```bash
gh auth login --hostname github.com --git-protocol https --web
```

Private SSH-form submodules can then be initialized without modifying their
committed `.gitmodules` URLs:

```bash
git submodule sync --recursive
git submodule update --init --remote --merge --recursive
```

Authentication is container-local unless `$HOME/.config/gh` is persisted or
mounted separately.

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

When a branch is deleted, its branch-specific GHCR package is deleted. The
scheduled cleanup handles stale build-cache versions. Cleanup verifies that a
package belongs to this repository before deleting it.
