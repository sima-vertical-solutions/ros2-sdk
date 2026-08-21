#!/usr/bin/env bash

set -euo pipefail

readonly NEAT_CORE_VERSION="${NEAT_CORE_VERSION:-0.4.0}"

if [[ "${EUID}" -ne 0 ]]; then
    echo "install-neat-core must run as root" >&2
    exit 1
fi

if ! command -v sima-cli >/dev/null 2>&1; then
    echo "install-neat-core requires sima-cli" >&2
    exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

(
    cd "${work_dir}"
    SIMA_CLI_CHECK_FOR_UPDATE=0 sima-cli neat install \
        "core@v${NEAT_CORE_VERSION}" \
        -t minimal \
        -f
)

for package in sima-neat sima-neat-dev; do
    installed_version="$(dpkg-query -W -f='${Version}' "${package}")"
    if [[ "${installed_version}" != "${NEAT_CORE_VERSION}" ]]; then
        echo "Installed ${package} ${installed_version}, expected ${NEAT_CORE_VERSION}." >&2
        exit 1
    fi
done
