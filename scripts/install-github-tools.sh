#!/usr/bin/env bash

# Installs Git/GitHub tooling and prepares private GitHub submodules to use the
# credentials established later by `gh auth login`. No credentials are baked
# into the SDK image.

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "install-github-tools must run as root" >&2
    exit 1
fi

apt-get update --allow-releaseinfo-change
apt-get install -y --no-install-recommends \
    ca-certificates \
    gh \
    git \
    openssh-client

# Repository manifests commonly use SSH-form GitHub URLs. Rewriting them to
# HTTPS lets an SDK user authenticate once with `gh auth login` without copying
# an SSH private key into the container.
git config --system \
    url."https://github.com/".insteadOf \
    "git@github.com:"
git config --system --add \
    url."https://github.com/".insteadOf \
    "ssh://git@github.com/"

# Preconfigure the same credential integration installed by `gh auth
# setup-git`. It becomes active after the user authenticates inside the
# container and is harmless before credentials exist.
git config --system \
    credential."https://github.com".helper \
    "!/usr/bin/gh auth git-credential"

git --version
gh --version | head -n 1
ssh -V

test "$(git config --system --get credential.https://github.com.helper)" \
    = "!/usr/bin/gh auth git-credential"
test "$(git config --system --get-all url.https://github.com/.insteadOf | wc -l)" \
    -eq 2

rm -rf /var/lib/apt/lists/*
