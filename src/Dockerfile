# Shared devcontainer image: Debian Trixie slim + the development tools that
# scripts/install-system.sh and scripts/install-tools.sh install, the same scripts install.sh
# runs on a workstation. The terminal setup comes from the dotfiles repo. See README.md.

FROM debian:trixie-slim

# ---- bash with pipefail, so a failing pipe fails the build ----
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# ---- system packages (apt-packages.txt) + the Docker CLI: the daemon is the host's ----
COPY scripts/install-system.sh /opt/devcontainer/scripts/
COPY config/apt-packages.txt /opt/devcontainer/config/
RUN sh /opt/devcontainer/scripts/install-system.sh --container

# ---- environment variables ----
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 UV_LINK_MODE=copy \
    # all of Claude Code's config in ~/.claude (one volume)
    CLAUDE_CONFIG_DIR=/home/devcontainer/.claude \
    PATH=/home/devcontainer/.local/bin:/home/devcontainer/.local/share/mise/shims:/home/devcontainer/.cargo/bin:$PATH

# ---- non-root user `devcontainer` (uid/gid 1000), in the docker group ----
RUN useradd -m -u 1000 -U -s /bin/bash devcontainer \
 && groupadd -f docker \
 && usermod -aG docker devcontainer

# ---- development tools, as the user (mise toolchains, Rust, Claude Code) ----
COPY scripts/install-tools.sh /opt/devcontainer/scripts/
COPY config/mise.toml config/chrome-devtools-mcp.json /opt/devcontainer/config/
USER devcontainer
RUN bash /opt/devcontainer/scripts/install-tools.sh --container

# ---- container runtime: root as PID 1 (VS Code attaches as `devcontainer`) ----
USER root
WORKDIR /workspaces
CMD ["sleep", "infinity"]

# ---- entrypoint: docker socket permissions ----
COPY --chmod=755 scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
