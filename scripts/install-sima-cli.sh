#!/usr/bin/env bash

# Container-oriented equivalent of:
# https://artifacts.neat.sima.ai/sima-cli/linux-mac.sh
#
# The public installer intentionally tracks the latest PyPI release and edits
# interactive shell profiles. SDK images instead pin the wheel, verify it, and
# expose a real command that works in both interactive and non-interactive use.

set -euo pipefail

readonly SIMA_CLI_VERSION="2.1.15"
readonly SIMA_CLI_SHA256="05286675443613095ed5fdcdae35784e72de9295cee24c9aa6952f567193888a"
readonly SIMA_CLI_URL="https://files.pythonhosted.org/packages/57/3a/bc60d6648f3d9583e34c21c6a742237351bb9d4d30a0126315b80f79cbf8/sima_cli-${SIMA_CLI_VERSION}-py3-none-any.whl"
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
