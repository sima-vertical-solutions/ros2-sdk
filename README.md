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

All published images target `linux/arm64` only. Pull one explicitly with:

```bash
docker pull --platform linux/arm64 \
  ghcr.io/sima-vertical-solutions/ros2-sdk:latest
```

When a branch is deleted, its branch-specific GHCR package is deleted. A daily
reconciliation run removes an orphaned branch package if the delete event was
missed. Cleanup verifies that a package belongs to this repository before
deleting it.
