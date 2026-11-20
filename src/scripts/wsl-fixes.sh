#!/bin/sh
# WSL workstation fixes, as root: what Ubuntu's WSL image does and Debian's
# doesn't. On WSL, install.sh runs it with sudo; never in the image.
# Idempotent: each fix checks first.
set -eu

# ---- Windows programs (.exe) keep running: with systemd, systemd-binfmt drops
#      the WSLInterop registration WSL makes at boot; Ubuntu ships this file ----
if [ ! -e /usr/lib/binfmt.d/WSLInterop.conf ] && [ ! -e /etc/binfmt.d/WSLInterop.conf ]; then
    mkdir -p /etc/binfmt.d
    echo ':WSLInterop:M::MZ::/init:PF' > /etc/binfmt.d/WSLInterop.conf
    if [ -d /run/systemd/system ]; then systemctl restart systemd-binfmt; fi
fi
