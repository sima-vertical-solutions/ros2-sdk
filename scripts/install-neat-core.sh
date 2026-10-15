#!/usr/bin/env bash

set -euo pipefail

# WHAT to install, as a sima-cli ref: a release tag ("v0.5.0") or a branch. The Dockerfile
# always passes it; this default only covers a hand-run, so keep it on the pinned ref.
readonly NEAT_CORE_SPEC="${NEAT_CORE_SPEC:-release-0.5.1-pc}"
# sima-neat is the package the installed version is read from.
readonly NEAT_STAMP_PACKAGE=sima-neat

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
        "core@${NEAT_CORE_SPEC}" \
        -t minimal \
        -f
)

# VERIFY that the stamp package landed. Which packages a ref moves is the REF's business: a
# branch can ship new sima-neat* wrappers over unchanged payload debs (release-0.5.1-pc does),
# so there is no uniform version to require across the set.
expected_version="$(dpkg-query -W -f='${Version}' "${NEAT_STAMP_PACKAGE}" 2>/dev/null || true)"
if [[ -z "${expected_version}" ]]; then
    echo "${NEAT_STAMP_PACKAGE} is not installed after 'sima-cli neat install core@${NEAT_CORE_SPEC}'." >&2
    exit 1
fi

# A plain vX.Y.Z spec still gets the exact equality check it always had, since there the
# expected string IS predictable.
if [[ "${NEAT_CORE_SPEC}" =~ ^v([0-9][^:]*)$ ]] && [[ "${expected_version}" != "${BASH_REMATCH[1]}" ]]; then
    echo "Installed neat ${expected_version}, but core@${NEAT_CORE_SPEC} asked for ${BASH_REMATCH[1]}." >&2
    exit 1
fi

echo "neat core: ${expected_version}  (from core@${NEAT_CORE_SPEC})"
