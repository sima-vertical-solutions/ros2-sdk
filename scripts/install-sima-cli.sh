#!/usr/bin/env bash

# Container-oriented equivalent of:
# https://artifacts.neat.sima.ai/sima-cli/linux-mac.sh
#
# The public installer intentionally tracks the latest PyPI release and edits
# interactive shell profiles. SDK images instead pin the wheel, verify it, and
# expose a real command that works in both interactive and non-interactive use.

set -euo pipefail

readonly SIMA_CLI_VERSION="2.1.16"
readonly SIMA_CLI_SHA256="f8db78218599430f132f64ea5ccf9464123e40add58468817a4824e3cc799942"
readonly SIMA_CLI_URL="https://files.pythonhosted.org/packages/6d/40/e12472a5d046c4eeca7f8397ca7b81f980a6025b098f67870293470bfe78/sima_cli-${SIMA_CLI_VERSION}-py3-none-any.whl"
readonly SIMA_CLI_ROOT="/opt/sima-cli"
readonly SIMA_CLI_VENV="${SIMA_CLI_ROOT}/.venv"

if [[ "${EUID}" -ne 0 ]]; then
    echo "install-sima-cli must run as root" >&2
    exit 1
fi

apt-get update --allow-releaseinfo-change
apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    python3-pip \
    python3-venv

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

wheel="${work_dir}/sima_cli-${SIMA_CLI_VERSION}-py3-none-any.whl"
curl --fail --location --silent --show-error \
    --retry 3 \
    --retry-all-errors \
    --output "${wheel}" \
    "${SIMA_CLI_URL}"
echo "${SIMA_CLI_SHA256}  ${wheel}" | sha256sum --check --strict

mkdir -p "${SIMA_CLI_ROOT}"
python3 -m venv "${SIMA_CLI_VENV}"
PIP_DISABLE_PIP_VERSION_CHECK=1 "${SIMA_CLI_VENV}/bin/python" -m pip install \
    --no-cache-dir \
    "${wheel}"

ln -s "${SIMA_CLI_VENV}/bin/sima-cli" /usr/local/bin/sima-cli

version_output="$(sima-cli --version)"
printf '%s\n' "${version_output}"
grep -Fq "${SIMA_CLI_VERSION}" <<< "${version_output}"

rm -rf /var/lib/apt/lists/*
