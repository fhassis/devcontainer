# =============================================================================
# fhassis devcontainer base — Python 3.14 on Debian Trixie slim + a toolbelt.
#
# One image for every project: shell, Python, Node, Bun, Rust, the Docker/Postgres/git
# toolbelt, and the system libraries headless Chromium needs.
# Per-project bits (VS Code extensions, extra services, project-only tools) live
# in each project's devcontainer.json — not here.
#
# Everything tracks latest via each tool's official install script: a rebuild is
# the update. `make build` passes --pull, which refreshes the Python base; the
# cached RUN layers only move when one above them does.
# =============================================================================

FROM python:3.14-slim-trixie

ARG PG_MAJOR=18

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
 # Bun first: the install below runs `bunx playwright install-deps`.
 # BUN_INSTALL=/usr/local puts bun + bunx in /usr/local/bin.
 && $DL https://bun.sh/install -o /tmp/bun.sh \
 && BUN_INSTALL=/usr/local bash /tmp/bun.sh \
 # Docker CE — for docker-ce-cli
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
      fish starship eza \
      docker-ce-cli docker-buildx-plugin docker-compose-plugin \
      "postgresql-client-${PG_MAJOR}" \
 # browser system libraries (NOT a browser binary) for headless Chromium, so the
 # per-project automation MCPs (Playwright / Chrome DevTools) run its chrome versions.
 && bunx playwright install-deps chromium \
 && rm -rf /var/lib/apt/lists/* /root/.bun /tmp/bun.sh

# uv uses the image's Python 3.14 (/usr/local/bin, first on PATH) and never
# downloads its own.
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 SHELL=/usr/bin/fish \
    PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never UV_PYTHON_PREFERENCE=only-system \
    STARSHIP_CONFIG=/home/devcontainer/.config/starship.toml \
    RUSTUP_HOME=/usr/local/rustup CARGO_HOME=/usr/local/cargo \
    FNM_DIR=/home/devcontainer/.local/share/fnm \
    # fnm's default alias on PATH, so non-interactive shells (Claude's Bash tool,
    # compose commands) get node too; interactive fish switches per project.
    PATH=/home/devcontainer/.local/bin:/home/devcontainer/.local/share/fnm/aliases/default/bin:/home/devcontainer/.bun/bin:/usr/local/cargo/bin:$PATH

# ---- uv (+uvx), fnm and glab, one layer ----
# glab has no install script, so its latest release tarball.
RUN $DL https://astral.sh/uv/install.sh -o /tmp/uv.sh \
 && UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh /tmp/uv.sh \
 && $DL https://fnm.vercel.app/install -o /tmp/fnm.sh \
 && bash /tmp/fnm.sh --install-dir /usr/local/bin --skip-shell \
 && v=$($DL https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases/permalink/latest \
        | grep -o '"tag_name":"v[^"]*"' | head -1 | cut -d'"' -f4 | tr -d v) \
 && $DL "https://gitlab.com/gitlab-org/cli/-/releases/v${v}/downloads/glab_${v}_linux_amd64.tar.gz" -o /tmp/glab.tgz \
 && tar -xzf /tmp/glab.tgz -C /tmp \
 && mv /tmp/bin/glab /usr/local/bin/glab \
 && rm -rf /tmp/uv.sh /tmp/fnm.sh /tmp/bin /tmp/glab.tgz

# ---- non-root user `devcontainer` (uid/gid 1000), shell fish; docker group GID is
#      auto (the entrypoint aligns it to the socket). The Rust dirs are created
#      owned by it so rustup installs as the user and `cargo install` needs no sudo. ----
RUN useradd -m -u 1000 -U -s /usr/bin/fish devcontainer \
 && groupadd docker \
 && usermod -aG docker devcontainer \
 && install -d -o devcontainer -g devcontainer "$RUSTUP_HOME" "$CARGO_HOME"

# ---- Node 24 (fnm), Rust, shell config + fish completions, as the non-root user ----
USER devcontainer
RUN fnm install 24 \
 && fnm default 24 \
 # language servers for the Claude Code LSP plugins below (rust-analyzer via rustup)
 && npm install -g typescript-language-server typescript pyright \
 && $DL https://sh.rustup.rs -o /tmp/rustup.sh \
 && sh /tmp/rustup.sh -y --no-modify-path --profile minimal -c clippy,rustfmt,rust-analyzer \
 && rm /tmp/rustup.sh \
 && mkdir -p ~/.local/share/fish ~/.config/fish/completions \
 && starship preset nerd-font-symbols -o ~/.config/starship.toml \
 && uv generate-shell-completion fish > ~/.config/fish/completions/uv.fish \
 && docker  completion fish > ~/.config/fish/completions/docker.fish \
 && glab    completion -s fish > ~/.config/fish/completions/glab.fish \
 && rustup  completions fish rustup > ~/.config/fish/completions/rustup.fish \
 && fnm     completions --shell fish > ~/.config/fish/completions/fnm.fish
# bun has no `completion fish` subcommand (fish infers it from --help); cargo's
# completions ship with fish itself.
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

# ---- entrypoint runs as root to align the docker group GID with the mounted
#      socket; VS Code attaches as `devcontainer` via docker exec, separately.
USER root
COPY config/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
WORKDIR /workspaces
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["sleep", "infinity"]
