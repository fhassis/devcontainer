#!/bin/sh
# Docker for the non-root `devcontainer` user. Runs as root (PID 1); VS Code
# attaches as the remoteUser via a separate `docker exec`.
#  - host socket mounted: align the in-container `docker` group GID with it
#    (docker-outside-of-docker). If another group in the image already holds that
#    GID, `devcontainer` joins that group instead.
#  - no socket, but a privileged container: start our own dockerd
#    (docker-in-docker), then drop to `devcontainer`. /var/lib/docker should be a volume.
# chrome-devtools-mcp's config, from the image on every start (see the Dockerfile).
if [ "$(id -u)" = 0 ]; then
    install -D -o devcontainer -g devcontainer -m 644 /usr/local/share/cd4a/config.json \
        /home/devcontainer/.config/cd4a/config.json
fi
if [ -S /var/run/docker.sock ]; then
    SOCKET_GID=$(stat -c '%g' /var/run/docker.sock)
    SOCKET_GROUP=$(getent group "$SOCKET_GID" | cut -d: -f1)
    if [ -z "$SOCKET_GROUP" ]; then
        groupmod -g "$SOCKET_GID" docker 2>/dev/null || true
    elif [ "$SOCKET_GROUP" != docker ]; then
        usermod -aG "$SOCKET_GROUP" devcontainer 2>/dev/null || true
    fi
elif [ "$(id -u)" = 0 ]; then
    dockerd >/var/log/dockerd.log 2>&1 &
    for _ in $(seq 20); do [ -S /var/run/docker.sock ] && break; sleep 1; done
    [ -S /var/run/docker.sock ] || echo "dockerd did not start (not privileged?): /var/log/dockerd.log" >&2
    exec gosu devcontainer "$@"
fi
exec "$@"
