#!/bin/sh
# System packages, as root: config/apt-packages.txt and Docker from Docker's
# own apt repo. On a workstation, install.sh runs it with sudo; the image runs
# it with --container.
#   --container      Docker CLI + compose/buildx plugins only: the daemon is the host's
#   --docker-engine  the full Docker Engine (a workstation without Docker yet)
#   (neither)        no Docker: there already is one (Rancher Desktop, ...)
set -eu

HERE=$(cd "$(dirname "$0")/.." && pwd)
DL="curl -fsSL --ipv4 --retry 5 --retry-delay 2 --retry-all-errors"
export DEBIAN_FRONTEND=noninteractive

docker=none
for arg; do
    case $arg in
        --container) docker=cli ;;
        --docker-engine) docker=engine ;;
        *) echo "install-system.sh: unknown option $arg" >&2; exit 2 ;;
    esac
done

# ---- Debian packages ----
apt-get update -qq
# shellcheck disable=SC2046
apt-get install -y --no-install-recommends $(sed 's/#.*//' "$HERE/config/apt-packages.txt")

# ---- Docker, from Docker's repo (debian or ubuntu, per /etc/os-release) ----
if [ "$docker" != none ]; then
    . /etc/os-release
    install -m 0755 -d /etc/apt/keyrings
    $DL "https://download.docker.com/linux/$ID/gpg" -o /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$ID $VERSION_CODENAME stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
    pkgs="docker-ce-cli docker-buildx-plugin docker-compose-plugin"
    if [ "$docker" = engine ]; then pkgs="$pkgs docker-ce containerd.io"; fi
    # shellcheck disable=SC2086
    apt-get install -y --no-install-recommends $pkgs
fi

# ---- the image keeps no apt lists ----
if [ "$docker" = cli ]; then rm -rf /var/lib/apt/lists/*; fi
