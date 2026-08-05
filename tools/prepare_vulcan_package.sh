#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: tools/prepare_vulcan_package.sh \
  --output-dir <path> \
  --image-resource <ghcr:sima-vertical-solutions/ros2-sdk:tag> \
  [--version <package-version>] \
  [--release <release-id>]

Builds the Vulcan/sima-cli install-stub package for the ROS 2 SDK. The SDK
image remains in GHCR; the generated metadata references that exact image.
USAGE
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR=""
IMAGE_RESOURCE=""
PACKAGE_VERSION=""
PACKAGE_RELEASE=""
PACKAGE_DOWNLOAD_SIZE="${ROS2_SDK_PACKAGE_DOWNLOAD_SIZE:-8GB}"
PACKAGE_INSTALL_SIZE="${ROS2_SDK_PACKAGE_INSTALL_SIZE:-20GB}"
INSTALL_SCRIPT_NAME="install_ros2_sdk_stub.sh"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --image-resource)
      IMAGE_RESOURCE="${2:-}"
      shift 2
      ;;
    --version)
      PACKAGE_VERSION="${2:-}"
      shift 2
      ;;
    --release)
      PACKAGE_RELEASE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${OUTPUT_DIR}" || -z "${IMAGE_RESOURCE}" ]]; then
  echo "Missing required arguments." >&2
  usage >&2
  exit 1
fi

if [[ ! "${IMAGE_RESOURCE}" =~ ^ghcr:sima-vertical-solutions/ros2-sdk:[A-Za-z0-9._-]+$ ]]; then
  echo "--image-resource must identify the canonical ROS 2 SDK package, got: ${IMAGE_RESOURCE}" >&2
  exit 1
fi

if ! command -v sima-cli >/dev/null 2>&1; then
  echo "sima-cli is required to build ROS 2 SDK package metadata." >&2
  exit 1
fi

if [[ -z "${PACKAGE_VERSION}" ]]; then
  if [[ "${GITHUB_REF_TYPE:-}" == "tag" && -n "${GITHUB_REF_NAME:-}" ]]; then
    PACKAGE_VERSION="${GITHUB_REF_NAME#v}"
  elif [[ -n "${GITHUB_HEAD_REF:-}" ]]; then
    PACKAGE_VERSION="${GITHUB_HEAD_REF}"
  elif [[ -n "${GITHUB_REF_NAME:-}" ]]; then
    PACKAGE_VERSION="${GITHUB_REF_NAME}"
  else
    PACKAGE_VERSION="$(git -C "${ROOT_DIR}" rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)"
  fi
fi

if [[ -z "${PACKAGE_RELEASE}" ]]; then
  PACKAGE_RELEASE="${PACKAGE_VERSION}"
fi

tmp_dir="$(mktemp -d /tmp/sima-ros2-sdk-package-XXXXXX)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

artifacts_dir="${tmp_dir}/artifacts"
mkdir -p "${artifacts_dir}"
install -m 0755 "${ROOT_DIR}/tools/${INSTALL_SCRIPT_NAME}" "${artifacts_dir}/${INSTALL_SCRIPT_NAME}"

setup_image="ghcr.io/${IMAGE_RESOURCE#ghcr:}"
sed -i.bak "s|__ROS2_SDK_IMAGE__|${setup_image}|g" "${artifacts_dir}/${INSTALL_SCRIPT_NAME}"
rm -f "${artifacts_dir}/${INSTALL_SCRIPT_NAME}.bak"

SIMA_CLI_CHECK_FOR_UPDATE=0 sima-cli packages build "${artifacts_dir}" \
  --name ros2-sdk \
  --version "${PACKAGE_VERSION}" \
  --description "SiMa.ai ROS 2 SDK install stub" \
  --install-script "${INSTALL_SCRIPT_NAME}" \
  --host-platform "linux,mac" \
  --host-arch arm64

python3 - "${artifacts_dir}/metadata.json" "${IMAGE_RESOURCE}" "${PACKAGE_RELEASE}" "${PACKAGE_DOWNLOAD_SIZE}" "${PACKAGE_INSTALL_SIZE}" <<'PY'
import json
import sys
from pathlib import Path

metadata_path = Path(sys.argv[1])
image_resource = sys.argv[2]
release = sys.argv[3]
download_size = sys.argv[4]
install_size = sys.argv[5]

metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
resources = metadata.setdefault("resources", [])
if image_resource not in resources:
    resources.append(image_resource)
metadata["release"] = release
metadata["size"] = {
    "download": download_size,
    "install": install_size,
}
metadata["installation"]["post-message"] = (
    "[bold green]ROS 2 SDK setup complete.[/bold green]\n"
    "Use [cyan]sima-cli sdk ros2[/cyan] to run commands in the container.\n"
)
metadata_path.write_text(json.dumps(metadata, indent=4) + "\n", encoding="utf-8")
PY

python3 -m json.tool "${artifacts_dir}/metadata.json" >/dev/null

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"
cp -f "${artifacts_dir}/${INSTALL_SCRIPT_NAME}" "${artifacts_dir}/metadata.json" "${OUTPUT_DIR}/"

echo "Prepared ROS 2 SDK install-stub package:"
ls -lh "${OUTPUT_DIR}"
