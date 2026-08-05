#!/usr/bin/env bash
set -euo pipefail

output_path="${1:-/etc/sdk-release}"
product_name="${2:-SiMa.ai ROS2 SDK}"
release_tag="${3:-}"
git_branch="${4:-unknown}"
git_hash="${5:-nogit}"
build_time="${6:-unknown-time}"

if [[ -n "${release_tag}" ]]; then
  version="${release_tag}"
else
  version="${git_branch}:${git_hash}:${build_time}"
fi

printf 'Product Name = %s\nVersion = %s\n' \
  "${product_name}" \
  "${version}" > "${output_path}"
