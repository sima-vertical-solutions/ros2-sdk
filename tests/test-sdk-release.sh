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
grep -Fxq "Version = feature/metadata:0123456789ab:20260805T144500Z" "${branch_release}"

"${ROOT_DIR}/scripts/write-sdk-release.sh" \
  "${tag_release}" \
  "SiMa.ai ROS2 SDK" \
  "v2.1.2" \
  "ignored-branch" \
  "ignored-hash" \
  "ignored-time"

grep -Fxq "Product Name = SiMa.ai ROS2 SDK" "${tag_release}"
grep -Fxq "Version = v2.1.2" "${tag_release}"
if grep -Eq 'ignored-(branch|hash|time)' "${tag_release}"; then
  echo "Release tag did not override branch build metadata." >&2
  exit 1
fi

echo "SDK release-file tests passed."
