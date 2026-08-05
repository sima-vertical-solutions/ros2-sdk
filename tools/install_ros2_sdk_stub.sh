#!/usr/bin/env bash
set -euo pipefail

readonly MINIMUM_SIMA_CLI_VERSION="2.1.16"
readonly ROS2_SDK_IMAGE="__ROS2_SDK_IMAGE__"

resolve_sima_cli() {
  local candidate

  if [[ -n "${SIMA_CLI:-}" ]]; then
    [[ -x "${SIMA_CLI}" ]] || {
      echo "SIMA_CLI is set but is not executable: ${SIMA_CLI}" >&2
      return 1
    }
    printf '%s\n' "${SIMA_CLI}"
    return 0
  fi

  if command -v sima-cli >/dev/null 2>&1; then
    command -v sima-cli
    return 0
  fi

  for candidate in \
    "${HOME}/.sima-cli/.venv/bin/sima-cli" \
    "${HOME}/.local/bin/sima-cli" \
    "/data/sima-cli/.venv/bin/sima-cli" \
    "/opt/sima-cli/venv/bin/sima-cli" \
    "/usr/local/bin/sima-cli"; do
    if [[ -x "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

version_at_least() {
  local actual="$1"
  local minimum="$2"
  local actual_major actual_minor actual_patch
  local minimum_major minimum_minor minimum_patch

  IFS=. read -r actual_major actual_minor actual_patch <<< "${actual}"
  IFS=. read -r minimum_major minimum_minor minimum_patch <<< "${minimum}"

  actual_patch="${actual_patch%%[^0-9]*}"
  minimum_patch="${minimum_patch%%[^0-9]*}"

  (( 10#${actual_major} > 10#${minimum_major} )) && return 0
  (( 10#${actual_major} < 10#${minimum_major} )) && return 1
  (( 10#${actual_minor} > 10#${minimum_minor} )) && return 0
  (( 10#${actual_minor} < 10#${minimum_minor} )) && return 1
  (( 10#${actual_patch} >= 10#${minimum_patch} ))
}

main() {
  local sima_cli version_output installed_version

  if ! sima_cli="$(resolve_sima_cli)"; then
    echo "Required command not found: sima-cli" >&2
    echo "Install sima-cli ${MINIMUM_SIMA_CLI_VERSION} or newer and retry." >&2
    exit 1
  fi

  version_output="$("${sima_cli}" --version 2>&1)"
  installed_version="$(printf '%s\n' "${version_output}" | sed -nE 's/.*([0-9]+[.][0-9]+[.][0-9]+).*/\1/p' | head -n 1)"
  if [[ -z "${installed_version}" ]] || ! version_at_least "${installed_version}" "${MINIMUM_SIMA_CLI_VERSION}"; then
    echo "ROS 2 SDK setup requires sima-cli ${MINIMUM_SIMA_CLI_VERSION} or newer." >&2
    echo "Detected version: ${installed_version:-unknown}" >&2
    exit 1
  fi

  echo "ROS 2 SDK image installed: ${ROS2_SDK_IMAGE}"
  echo "Starting guided SDK setup."
  "${sima_cli}" sdk setup --image "${ROS2_SDK_IMAGE}"
}

main "$@"
