#!/bin/sh
# Align the in-container `docker` group GID with the mounted host socket so the
# non-root `devcontainer` user can use the Docker CLI without sudo. Runs as root
# (PID 1); VS Code attaches as the remoteUser via a separate `docker exec`.
if [ -S /var/run/docker.sock ]; then
    SOCKET_GID=$(stat -c '%g' /var/run/docker.sock)
    groupmod -g "$SOCKET_GID" docker 2>/dev/null || true
fi
exec "$@"
