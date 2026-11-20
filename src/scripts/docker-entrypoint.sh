#!/bin/sh
# docker-outside-of-docker for the non-root `devcontainer` user. Runs as root
# (PID 1); VS Code attaches as the remoteUser via a separate `docker exec`.
#
# Why this exists: the mounted /var/run/docker.sock belongs to a host group whose
# GID changes per machine:
#  - Rancher Desktop (WSL): GID 101, which in the image is already `_ssh`
#  - Docker on native Linux: usually 999, 984... depends on the distro
# `devcontainer` can only use `docker` without sudo if it is in a group with that
# GID, and the GID is only known once the container runs. So, as root, at start:
# renumber the `docker` group to the socket's GID, or, if another group already
# holds it, add `devcontainer` to that group.
#
# Alternatives, all worse:
#  - `group_add` in compose: a fixed GID in compose.yml (or a variable set on each
#    host); no longer portable between Rancher and Linux
#  - `chmod 666` on the socket: any process could drive the host's Docker
#  - running the container as root: loses the non-root user
if [ -S /var/run/docker.sock ]; then
    SOCKET_GID=$(stat -c '%g' /var/run/docker.sock)
    SOCKET_GROUP=$(getent group "$SOCKET_GID" | cut -d: -f1)
    if [ -z "$SOCKET_GROUP" ]; then
        groupmod -g "$SOCKET_GID" docker 2>/dev/null || true
    elif [ "$SOCKET_GROUP" != docker ]; then
        usermod -aG "$SOCKET_GROUP" devcontainer 2>/dev/null || true
    fi
fi
exec "$@"
