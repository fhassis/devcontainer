#!/bin/sh
# Docker for the non-root `devcontainer` user. Runs as root (PID 1); VS Code
# attaches as the remoteUser via a separate `docker exec`.
#  - host socket mounted: align the in-container `docker` group GID with it
#    (docker-outside-of-docker).
#  - no socket, but a privileged container: start our own dockerd
#    (docker-in-docker), then drop to `devcontainer`. /var/lib/docker should be a volume.
if [ -S /var/run/docker.sock ]; then
    SOCKET_GID=$(stat -c '%g' /var/run/docker.sock)
    groupmod -g "$SOCKET_GID" docker 2>/dev/null || true
elif [ "$(id -u)" = 0 ]; then
    dockerd >/var/log/dockerd.log 2>&1 &
    for _ in $(seq 20); do [ -S /var/run/docker.sock ] && break; sleep 1; done
    [ -S /var/run/docker.sock ] || echo "dockerd did not start (not privileged?): /var/log/dockerd.log" >&2
    exec gosu devcontainer "$@"
fi
exec "$@"
