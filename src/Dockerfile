# =============================================================================
# fhassis devcontainer base — Debian Trixie slim + a development toolbelt.
#
# One image for every project: Python, Node, Rust, kubectl/helm, the
# Docker/Postgres/git toolbelt, and Debian's Chromium (headless, for the Chrome
# DevTools MCP). Development toolchains come from mise (config/mise.toml).
# The terminal setup (prompt, fzf, zoxide, nvim, theme...) is not here: it comes
# from the dotfiles repo, which VS Code installs in every new container.
# Per-project bits (VS Code extensions, extra services, project-only tools) live
# in each project's devcontainer.json — not here.
#
# Everything tracks latest: a rebuild is the update. `make image-build` passes
# --pull, which refreshes the Debian base; the cached RUN layers only move when
# one above them does.
# =============================================================================

FROM debian:trixie-slim

ARG PG_MAJOR=18
ARG PYTHON_VERSION=3.15

# bash with pipefail so a failing `curl | tar` actually fails the build.
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Download to a file THEN run/extract (curl|sh can't retry safely); `--ipv4` +
# retries dodge the broken-IPv6 "connection reset" we hit on CI runners.
ARG DL="curl -fsSL --ipv4 --retry 5 --retry-delay 2 --retry-all-errors"

# ---- everything apt, in ONE layer: bootstrap -> add repos -> install -> clean
# Bootstrap curl/gpg, register the third-party repos, then a single apt install and drop the cache.
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates gnupg unzip \
 && install -m 0755 -d /etc/apt/keyrings \
 # Docker CE — the CLI plus dockerd (docker-in-docker, see the entrypoint)
 && $DL https://download.docker.com/linux/debian/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
 && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian trixie stable" \
      > /etc/apt/sources.list.d/docker.list \
 # PostgreSQL PGDG — Trixie only ships up to pg17, we want the pinned major
 && $DL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
      | gpg --dearmor -o /etc/apt/keyrings/pgdg.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/pgdg.gpg] https://apt.postgresql.org/pub/repos/apt trixie-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list \
 # single install: Debian packages + the two repos above
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      git openssh-client make \
      # the C linker rustc needs
      gcc libc6-dev \
      # shell basics; the terminal tools (fzf, bat, nvim...) come from the dotfiles
      fish tmux jq nano less wget zip rsync \
      docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
      # dockerd needs iptables; gosu drops the entrypoint back to `devcontainer`
      iptables gosu \
      "postgresql-client-${PG_MAJOR}" \
      # for chrome-devtools-mcp (a Claude plugin below)
      chromium \
 && rm -rf /var/lib/apt/lists/*

# Everything lives in the user's home, at each tool's default location: mise's
# tools in ~/.local/share/mise (its shims on PATH, so non-interactive shells such
# as Claude's Bash tool get node, uv, kubectl...), uv's Python in ~/.local/bin,
# Rust in ~/.rustup and ~/.cargo. All owned by `devcontainer`: no sudo needed.
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 SHELL=/usr/bin/fish \
    PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 UV_LINK_MODE=copy \
    UV_PYTHON_PREFERENCE=only-managed \
    # Claude Code keeps .claude.json inside ~/.claude too, so one volume holds it all.
    CLAUDE_CONFIG_DIR=/home/devcontainer/.claude \
    PATH=/home/devcontainer/.local/bin:/home/devcontainer/.local/share/mise/shims:/home/devcontainer/.cargo/bin:$PATH

# ---- non-root user `devcontainer` (uid/gid 1000), shell fish; docker group GID is
#      auto (the entrypoint aligns it to the socket). ----
RUN useradd -m -u 1000 -U -s /usr/bin/fish devcontainer \
 && groupadd -f docker \
 && usermod -aG docker devcontainer

# The image's toolchains; mise merges it with the user's and the project's configs.
COPY config/mise.toml /etc/mise/config.toml

# ---- mise toolchains (node, uv, kubectl, helm, LSPs), Python (uv), Rust (rustup) ----
USER devcontainer
RUN $DL https://mise.run -o /tmp/mise.sh \
 && sh /tmp/mise.sh \
 && MISE_YES=1 mise install \
 && uv python install "$PYTHON_VERSION" --default \
 && $DL https://sh.rustup.rs -o /tmp/rustup.sh \
 && sh /tmp/rustup.sh -y --no-modify-path --profile minimal -c clippy,rustfmt,rust-analyzer \
 && rm /tmp/mise.sh /tmp/rustup.sh \
 # the fish-history volume's mount point, so Docker seeds it owned by the user
 && mkdir -p ~/.local/share/fish

# ---- Claude Code CLI (terminal `claude`), installed for the non-root user ----
RUN $DL https://claude.ai/install.sh | bash

# ---- Claude Code plugins (user scope, in ~/.claude). They seed a home volume on
#      its first mount; after that, updates happen in the container. ----
RUN claude plugin marketplace add anthropics/claude-plugins-official \
 && claude plugin marketplace add DietrichGebert/ponytail \
 && claude plugin install ponytail@ponytail \
 && for p in mattpocock-skills frontend-design code-review chrome-devtools-mcp \
             typescript-lsp pyright-lsp rust-analyzer-lsp; do \
      claude plugin install "$p@claude-plugins-official"; \
    done

# chrome-devtools-mcp's config file: Debian's /usr/bin/chromium (it looks for
# Google Chrome by default), headless (no X server here, and it launches
# headful by default), no sandbox (Docker's seccomp denies the user namespace
# Chrome's sandbox needs; the container is the isolation), isolated (a profile in
# a persistent home keeps a SingletonLock naming the previous container's
# hostname, and Chrome refuses it on the next one), and the owner's phone as the
# window and user agent. Kept outside ~ and installed there by the entrypoint on
# every start: a home volume is seeded once, and this must reach existing ones.
COPY config/chrome-devtools-mcp.json /usr/local/share/cd4a/config.json

# ---- entrypoint runs as root to align the docker group GID with the mounted
#      socket, or to start dockerd when none is mounted (privileged); VS Code attaches as `devcontainer` via docker exec, separately.
USER root
COPY config/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
WORKDIR /workspaces
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["sleep", "infinity"]
