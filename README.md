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

## Private ARM64 runner and ROS 2 packages

Image builds run on an organization-managed, native ARM64 macOS runner with
the standard `self-hosted`, `macOS`, and `ARM64` labels. The runner must have
Docker available and an active corporate-network connection that can reach
`sw-web.eng.sima.ai`. CI checks both conditions before checking out or building
repository code.

For security, pull requests from forks are not allowed to execute on the
corporate-network runner. Pushes, manually dispatched builds, and pull requests
whose source branch is in this repository remain supported.

The image installs `ros2`, `rtabmap-ros`, `simaai-rtabmap`, and
`vdp-navigation`, together with the Debian `colcon` and `vcstool` packages
needed for source workspaces. The ROS 2 and RTAB-Map ROS bundles are pinned to
the private custom mirror; supporting SiMa packages continue to prefer the
regular SiMa release repository.

The custom mirror signing key is not currently distributed with the base SDK.
Until it is available, trust is scoped to this one APT source with
`[trusted=yes]`. Replace that setting with a dedicated `signed-by` keyring as
soon as the repository public key is published.

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
