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
platform_version="${PLATFORM_VERSION:-2.1.3}"
platform_base="${platform_version%%~pre*}"
platform_channel="${PLATFORM_CHANNEL:-release}"
platform_repository="${PLATFORM_REPOSITORY:-https://repo.sima.ai/elxr/deb/release}"
neat_core_version="${NEAT_CORE_VERSION:-0.4.0}"
# The REF that was installed, as opposed to the version it resolved to. Both are needed and
# neither can be derived from the other: the version's branch slug is lossy (a "/" becomes "-",
# so feature-yolox-seg-pose could have been feature/yolox-seg-pose or feature-yolox/seg-pose),
# and the ref says nothing about what version landed. A rover has to install the same REF the
# image did, so it has to be recorded here.
neat_core_spec="${NEAT_CORE_SPEC:-v${neat_core_version}}"

# RESOLVE a bare branch spec to <branch>:<sha> before recording it.
#
# provision.sh installs this exact string on the rover, reading it from the release's
# deploy.env. A bare branch would be resolved AGAIN, on the board, at provision time -- so a
# rover provisioned after the branch moved would get different neat from the one the overlay
# was compiled against. Pinning it here makes image and board the same bytes by construction.
#
# The sha is recoverable from what was installed: sima-neat's version carries the artifact REF
# sha as its last dot-separated field (0.4.0+feature-yolox-seg-pose.1c623216b45e). Note the
# payload packages carry the BUILD sha instead, which is why this reads sima-neat specifically.
# A plain vX.Y.Z release install has no sha to append and is left alone.
if [[ "${neat_core_spec}" != *:* ]] \
   && [[ ! "${neat_core_spec}" =~ ^v[0-9] ]] \
   && [[ "${neat_core_version}" =~ \.([0-9a-f]{7,40})$ ]]; then
  neat_core_spec="${neat_core_spec}:${BASH_REMATCH[1]}"
fi

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
Neat Core = ${neat_core_version}
Neat Core Spec = ${neat_core_spec}
ROS2 SDK Version = ${version}
Version = ${version}
EOF
