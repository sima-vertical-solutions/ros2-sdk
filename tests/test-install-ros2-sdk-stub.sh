#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/test-ros2-sdk-stub-XXXXXX)"
trap 'rm -rf "${TMP_DIR}"' EXIT

FAKE_CLI="${TMP_DIR}/sima-cli"
LOG_FILE="${TMP_DIR}/sima-cli.log"
INSTALLER="${TMP_DIR}/install_ros2_sdk_stub.sh"
IMAGE="ghcr.io/sima-vertical-solutions/ros2-sdk:sha-0123456789abcdef"

cp "${ROOT_DIR}/tools/install_ros2_sdk_stub.sh" "${INSTALLER}"
sed -i.bak "s|__ROS2_SDK_IMAGE__|${IMAGE}|g" "${INSTALLER}"
rm -f "${INSTALLER}.bak"
chmod +x "${INSTALLER}"

cat > "${FAKE_CLI}" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--version" ]]; then
  echo "SiMa CLI version: ${FAKE_SIMA_CLI_VERSION}"
  exit 0
fi
printf '%s\n' "$*" >> "${FAKE_SIMA_CLI_LOG}"
SH
chmod +x "${FAKE_CLI}"

SIMA_CLI="${FAKE_CLI}" \
FAKE_SIMA_CLI_VERSION="2.1.16" \
FAKE_SIMA_CLI_LOG="${LOG_FILE}" \
"${INSTALLER}"

grep -Fxq "sdk setup --image ${IMAGE}" "${LOG_FILE}"

rm -f "${LOG_FILE}"
if SIMA_CLI="${FAKE_CLI}" \
  FAKE_SIMA_CLI_VERSION="2.1.15" \
  FAKE_SIMA_CLI_LOG="${LOG_FILE}" \
  "${INSTALLER}"; then
  echo "Installer accepted unsupported sima-cli 2.1.15." >&2
  exit 1
fi

[[ ! -e "${LOG_FILE}" ]]
echo "ROS 2 SDK install-stub tests passed."
