#!/bin/sh
# The devcontainer image's development tools on a workstation (Debian/Ubuntu,
# native or WSL): the same scripts the image runs. System packages with sudo,
# then the user's tools in the home. Idempotent: run it again after a pull.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)

# Docker: keep one that's already there (Rancher Desktop, Docker Desktop...),
# else install the Docker Engine
engine=
if ! command -v docker >/dev/null 2>&1; then engine=--docker-engine; fi
sudo sh "$HERE/src/scripts/install-system.sh" $engine
if [ -n "${WSL_DISTRO_NAME:-}" ]; then
    sudo sh "$HERE/src/scripts/wsl-fixes.sh"
fi
if [ -n "$engine" ] && ! id -nG | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    relogin="yes"
fi

bash "$HERE/src/scripts/install-tools.sh"

if [ -n "${relogin:-}" ]; then
    echo "You were added to the docker group: log out and back in (WSL: wsl --shutdown) to use docker without sudo."
fi
