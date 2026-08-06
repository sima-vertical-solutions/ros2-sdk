#!/usr/bin/env bash
set -euo pipefail

output_path="${1:-/etc/sdk-release}"
product_name="${2:-SiMa.ai ROS2 SDK}"
release_tag="${3:-}"
git_branch="${4:-unknown}"
git_hash="${5:-nogit}"
build_time="${6:-unknown-time}"
sdk_type="${SDK_TYPE:-ros2-sdk}"
sdk_profile="${SDK_PROFILE:-native-arm64}"
platform_version="${PLATFORM_VERSION:-2.1.2}"
platform_base="${platform_version%%~pre*}"
platform_channel="${PLATFORM_CHANNEL:-release}"
platform_repository="${PLATFORM_REPOSITORY:-https://repo.sima.ai/elxr/deb/release}"

if [[ -n "${release_tag}" ]]; then
  version="${release_tag}"
  sdk_release="${release_tag}"
else
  version="${git_branch}:${git_hash}:${build_time}"
  sdk_release="${git_branch}"
fi

cat > "${output_path}" <<EOF
Product Name = ${product_name}
SDK Type = ${sdk_type}
SDK Release = ${sdk_release}
SDK Profile = ${sdk_profile}
Platform Version = ${platform_version}
Platform Base = ${platform_base}
Platform Channel = ${platform_channel}
Platform Repository = ${platform_repository}
Neat Core = not bundled
ROS2 SDK Version = ${version}
Version = ${version}
EOF
