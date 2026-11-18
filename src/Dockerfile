# =============================================================================
# fhassis devcontainer base — Debian Trixie slim + a toolbelt (Python via uv).
#
# One image for every project: shell, Python, Node, Rust, the Docker/Postgres/git
# toolbelt, and Debian's Chromium (headless, for the Chrome DevTools MCP).
# Per-project bits (VS Code extensions, extra services, project-only tools) live
# in each project's devcontainer.json — not here.
#
# Everything tracks latest via each tool's official install script: a rebuild is
# the update. `make image-build` passes --pull, which refreshes the Debian base; the
# cached RUN layers only move when one above them does.
# =============================================================================

FROM debian:trixie-slim

ARG PG_MAJOR=18
ARG PYTHON_VERSION=3.15
ARG NODE_VERSION=26

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
      # shell toolbelt, the same as the workstation's fish setup (config/config.fish)
      fish starship eza bat fzf zoxide jq tmux nano less wget zip rsync \
      docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
      # dockerd needs iptables; gosu drops the entrypoint back to `devcontainer`
      iptables gosu \
      "postgresql-client-${PG_MAJOR}" \
      # for chrome-devtools-mcp (a Claude plugin below)
      chromium \
 && rm -rf /var/lib/apt/lists/*

# Python comes only from uv (managed builds), in a fixed dir owned by `devcontainer`:
# `uv python install` and the automatic downloads for a project's
# .python-version need no sudo. Its bin dir holds the `python`/`python3` shims.
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 SHELL=/usr/bin/fish \
    PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 UV_LINK_MODE=copy \
    UV_PYTHON_PREFERENCE=only-managed \
    UV_PYTHON_INSTALL_DIR=/usr/local/share/uv/python UV_PYTHON_BIN_DIR=/usr/local/share/uv/bin \
    STARSHIP_CONFIG=/home/devcontainer/.config/starship.toml \
    # Claude Code keeps .claude.json inside ~/.claude too, so one volume holds it all.
    CLAUDE_CONFIG_DIR=/home/devcontainer/.claude \
    RUSTUP_HOME=/usr/local/rustup CARGO_HOME=/usr/local/cargo \
    FNM_DIR=/home/devcontainer/.local/share/fnm \
    # fnm's default alias on PATH, so non-interactive shells (Claude's Bash tool,
    # compose commands) get node too; interactive fish switches per project.
    PATH=/home/devcontainer/.local/bin:/usr/local/share/uv/bin:/home/devcontainer/.local/share/fnm/aliases/default/bin:/usr/local/cargo/bin:$PATH

# ---- uv (+uvx) and fnm, one layer ----
RUN $DL https://astral.sh/uv/install.sh -o /tmp/uv.sh \
 && UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh /tmp/uv.sh \
 && $DL https://fnm.vercel.app/install -o /tmp/fnm.sh \
 && bash /tmp/fnm.sh --install-dir /usr/local/bin --skip-shell \
 && rm -f /tmp/uv.sh /tmp/fnm.sh

# ---- non-root user `devcontainer` (uid/gid 1000), shell fish; docker group GID is
#      auto (the entrypoint aligns it to the socket). The Rust and uv Python dirs
#      are created owned by it, so both install as the user and need no sudo. ----
RUN useradd -m -u 1000 -U -s /usr/bin/fish devcontainer \
 && groupadd -f docker \
 && usermod -aG docker devcontainer \
 && install -d -o devcontainer -g devcontainer "$RUSTUP_HOME" "$CARGO_HOME" \
      "$UV_PYTHON_INSTALL_DIR" "$UV_PYTHON_BIN_DIR"

# ---- Python (uv), Node (fnm), Rust, shell config + fish completions, as the non-root user ----
USER devcontainer
RUN uv python install "$PYTHON_VERSION" --default \
 && fnm install "$NODE_VERSION" \
 && fnm default "$NODE_VERSION" \
 # language servers for the Claude Code LSP plugins below (rust-analyzer via rustup)
 && npm install -g typescript-language-server typescript pyright \
 && $DL https://sh.rustup.rs -o /tmp/rustup.sh \
 && sh /tmp/rustup.sh -y --no-modify-path --profile minimal -c clippy,rustfmt,rust-analyzer \
 && rm /tmp/rustup.sh \
 && mkdir -p ~/.local/share/fish ~/.config/fish/completions \
 && starship preset nerd-font-symbols -o ~/.config/starship.toml \
 && uv generate-shell-completion fish > ~/.config/fish/completions/uv.fish \
 && docker  completion fish > ~/.config/fish/completions/docker.fish \
 && rustup  completions fish rustup > ~/.config/fish/completions/rustup.fish \
 && fnm     completions --shell fish > ~/.config/fish/completions/fnm.fish
# cargo's completions ship with fish itself.
COPY config/config.fish /etc/fish/conf.d/config.fish

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
