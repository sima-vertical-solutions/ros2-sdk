#!/usr/bin/env bash

set -euo pipefail

# WHAT to install, as a sima-cli ref. Normally a release tag ("v0.4.0"); see the Dockerfile
# for why it is currently a branch snapshot instead.
readonly NEAT_CORE_SPEC="${NEAT_CORE_SPEC:-v0.4.0}"
# sima-neat is the package the stamp is read from; every *neat* package is checked below.
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

# VERIFY.
#
# The old check compared each installed version against the requested one, which worked only
# while the spec WAS a version. A branch:commit spec cannot be checked that way -- there is no
# string to predict, because the artifact ref and the debs inside it carry DIFFERENT SHAs
# (the ref e42536a7a7bd ships debs stamped ab1903f1ee74). Demanding equality there would fail
# every time; dropping the check entirely would let a partial or mixed install through silently.
#
# So: every neat package must be present and at the SAME version as the others, which is what a
# mixed install breaks. A plain vX.Y.Z spec additionally keeps the exact equality check it
# always had, since there the expected string IS predictable.
# One `core@<ref>` install updates the WHOLE set -- neat-appcomplex, -common, -ev74-firmware,
# -gst-plugins, -internals-dev, -runtime, sima-neat and sima-neat-dev -- so nothing is installed
# separately here. What is worth checking is that they all moved TOGETHER: a half-applied upgrade
# leaves some at the old version and is exactly the skew this pin exists to prevent.
#
# They do not share one version string. The six payload packages carry the BUILD sha while the
# two sima-neat* wrappers carry the artifact REF sha:
#   neat-runtime        0.4.0+feature-yolox-seg-pose.ab1903f1ee74
#   sima-neat           0.4.0+feature-yolox-seg-pose.e42536a7a7bd
# So compare the version with that trailing .<sha> removed -- uniform across all of them, and
# still "0.4.0" for a plain release install.
base_version() { sed -E 's/\.[0-9a-f]{7,40}$//' <<<"$1"; }

# Anchor on the stamp package rather than on whichever package sorts first: if the straggler
# happened to sort earlier it would set the baseline and the error would blame every package
# that upgraded correctly.
expected_version="$(dpkg-query -W -f='${Version}' "${NEAT_STAMP_PACKAGE}" 2>/dev/null || true)"
if [[ -z "${expected_version}" ]]; then
    echo "${NEAT_STAMP_PACKAGE} is not installed after 'sima-cli neat install core@${NEAT_CORE_SPEC}'." >&2
    exit 1
fi
expected_base="$(base_version "${expected_version}")"

mismatch=""
while read -r package installed_version; do
    [[ -n "${installed_version}" ]] || continue      # neat-libcamera* ship no version; skip
    [[ "$(base_version "${installed_version}")" == "${expected_base}" ]] \
        || mismatch+="  ${package} ${installed_version}"$'\n'
done < <(dpkg-query -W -f='${Package} ${Version}\n' '*neat*' 2>/dev/null | sort)

if [[ -n "${mismatch}" ]]; then
    echo "Half-applied neat install -- ${NEAT_STAMP_PACKAGE} is ${expected_version}, but these are not on ${expected_base}:" >&2
    printf '%s' "${mismatch}" >&2
    exit 1
fi

# A plain vX.Y.Z spec still gets the exact equality check it always had, since there the
# expected string IS predictable.
if [[ "${NEAT_CORE_SPEC}" =~ ^v([0-9][^:]*)$ ]] && [[ "${expected_version}" != "${BASH_REMATCH[1]}" ]]; then
    echo "Installed neat ${expected_version}, but core@${NEAT_CORE_SPEC} asked for ${BASH_REMATCH[1]}." >&2
    exit 1
fi

echo "neat core: ${expected_version}  (from core@${NEAT_CORE_SPEC})"
