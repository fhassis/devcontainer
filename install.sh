#!/bin/sh
# The devcontainer image's development tools on a workstation (Debian/Ubuntu,
# native or WSL): the same scripts the image runs. System packages and the
# Docker Engine with sudo, then the user's tools in the home. Idempotent: run
# it again after a pull.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)

sudo sh "$HERE/src/scripts/install-system.sh"
if [ -n "${WSL_DISTRO_NAME:-}" ]; then
    sudo sh "$HERE/src/scripts/wsl-fixes.sh"
fi
if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    relogin=yes
fi

bash "$HERE/src/scripts/install-tools.sh"

if [ -n "${relogin:-}" ]; then
    echo "You were added to the docker group: log out and back in (WSL: wsl --shutdown) to use docker without sudo."
fi
