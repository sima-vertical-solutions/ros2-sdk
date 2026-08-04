# ROS 2 SDK for Modalix

This repository builds the Modalix 2.1.2 SDK container from
[`Dockerfile.modalix`](https://github.com/SiMa-ai/swsoc-simaai-elxr-doc/blob/master/Dockerfile.modalix)
and publishes ARM64-only images to GitHub Container Registry.

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
