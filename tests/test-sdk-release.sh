#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/test-ros2-sdk-release-XXXXXX)"
trap 'rm -rf "${TMP_DIR}"' EXIT

branch_release="${TMP_DIR}/branch-release"
tag_release="${TMP_DIR}/tag-release"

"${ROOT_DIR}/scripts/write-sdk-release.sh" \
  "${branch_release}" \
  "SiMa.ai ROS2 SDK" \
  "" \
  "feature/metadata" \
  "0123456789ab" \
  "20260805T144500Z"

grep -Fxq "Product Name = SiMa.ai ROS2 SDK" "${branch_release}"
grep -Fxq "SDK Type = ros2-sdk" "${branch_release}"
grep -Fxq "SDK Release = feature/metadata" "${branch_release}"
grep -Fxq "SDK Profile = native-arm64" "${branch_release}"
grep -Fxq "Platform Version = 2.1.3" "${branch_release}"
grep -Fxq "Platform Base = 2.1.3" "${branch_release}"
grep -Fxq "Platform Channel = release" "${branch_release}"
grep -Fxq "Platform Repository = https://repo.sima.ai/elxr/deb/release" "${branch_release}"
grep -Fxq "Neat Core = 0.4.0" "${branch_release}"
grep -Fxq "ROS2 SDK Version = feature/metadata:0123456789ab:20260805T144500Z" "${branch_release}"
grep -Fxq "Version = feature/metadata:0123456789ab:20260805T144500Z" "${branch_release}"
if grep -Eq '^SDK Version[[:space:]]*=' "${branch_release}"; then
  echo "ROS2 SDK metadata must not use the Neat cross-SDK version identifier." >&2
  exit 1
fi

SDK_TYPE="ros2-sdk" \
SDK_PROFILE="native-arm64" \
PLATFORM_VERSION="2.1.3~pre4460" \
NEAT_CORE_VERSION="0.4.1~pre12" \
PLATFORM_CHANNEL="pre-release" \
PLATFORM_REPOSITORY="https://debian.neat.sima.ai/pre-release" \
  "${ROOT_DIR}/scripts/write-sdk-release.sh" \
  "${tag_release}" \
  "SiMa.ai ROS2 SDK" \
  "v2.1.3" \
  "ignored-branch" \
  "ignored-hash" \
  "ignored-time"

grep -Fxq "Product Name = SiMa.ai ROS2 SDK" "${tag_release}"
grep -Fxq "SDK Type = ros2-sdk" "${tag_release}"
grep -Fxq "SDK Release = v2.1.3" "${tag_release}"
grep -Fxq "SDK Profile = native-arm64" "${tag_release}"
grep -Fxq "Platform Version = 2.1.3~pre4460" "${tag_release}"
grep -Fxq "Platform Base = 2.1.3" "${tag_release}"
grep -Fxq "Platform Channel = pre-release" "${tag_release}"
grep -Fxq "Platform Repository = https://debian.neat.sima.ai/pre-release" "${tag_release}"
grep -Fxq "Neat Core = 0.4.1~pre12" "${tag_release}"
grep -Fxq "ROS2 SDK Version = v2.1.3" "${tag_release}"
grep -Fxq "Version = v2.1.3" "${tag_release}"
if grep -Eq 'ignored-(branch|hash|time)' "${tag_release}"; then
  echo "Release tag did not override branch build metadata." >&2
  exit 1
fi

echo "SDK release-file tests passed."
