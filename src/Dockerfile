# Shared devcontainer image: Debian Trixie slim + the toolchains in config/mise.toml.
# The terminal setup comes from the dotfiles repo. See README.md.

FROM debian:trixie-slim

# ---- bash with pipefail, so a failing `curl | tar` fails the build ----
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# ---- downloads: to a file, then run (curl | sh can't retry); IPv4 + retries
#      dodge the broken-IPv6 "connection reset" ----
ARG DL="curl -fsSL --ipv4 --retry 5 --retry-delay 2 --retry-all-errors"

# ---- everything apt, in one layer: install, clean ----
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      curl ca-certificates unzip git openssh-client make jq nano less wget zip rsync \
      # the C linker rustc needs
      gcc libc6-dev \
      # for chrome-devtools-mcp (a Claude plugin below)
      chromium \
 && rm -rf /var/lib/apt/lists/*

# ---- environment variables ----
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 UV_LINK_MODE=copy \
    UV_PYTHON_PREFERENCE=managed \
    # all of Claude Code's config in ~/.claude (one volume)
    CLAUDE_CONFIG_DIR=/home/devcontainer/.claude \
    PATH=/home/devcontainer/.local/bin:/home/devcontainer/.local/share/mise/shims:/home/devcontainer/.cargo/bin:$PATH

# ---- non-root user `devcontainer` (uid/gid 1000), in the docker group ----
RUN useradd -m -u 1000 -U -s /bin/bash devcontainer \
 && groupadd -f docker \
 && usermod -aG docker devcontainer

# ---- global configs ----
COPY config/mise.toml /etc/mise/config.toml
COPY --chown=devcontainer:devcontainer config/chrome-devtools-mcp.json /home/devcontainer/.config/cd4a/config.json

# ---- the rest as the non-root user ----
USER devcontainer

RUN \
 # ---- mise toolchains (config/mise.toml) ----
 $DL https://mise.run -o /tmp/mise.sh \
 && sh /tmp/mise.sh \
 && MISE_YES=1 mise install \
 # ---- docker compose / buildx: the CLI finds its plugins in ~/.docker/cli-plugins ----
 && mkdir -p ~/.docker/cli-plugins \
 && ln -s ~/.local/share/mise/installs/docker-compose/latest/docker-compose ~/.docker/cli-plugins/ \
 && ln -s ~/.local/share/mise/installs/github-docker-buildx/latest/docker-buildx ~/.docker/cli-plugins/ \
 # ---- Rust (rustup) ----
 && $DL https://sh.rustup.rs -o /tmp/rustup.sh \
 && sh /tmp/rustup.sh -y --no-modify-path --profile minimal -c clippy,rustfmt,rust-analyzer \
 # ---- Claude Code CLI (terminal `claude`) ----
 && $DL https://claude.ai/install.sh -o /tmp/claude.sh \
 && bash /tmp/claude.sh \
 && claude plugin marketplace add anthropics/claude-plugins-official \
 && claude plugin marketplace add DietrichGebert/ponytail \
 && claude plugin install ponytail@ponytail \
 && for p in mattpocock-skills frontend-design code-review chrome-devtools-mcp \
             typescript-lsp pyright-lsp rust-analyzer-lsp; do \
      claude plugin install "$p@claude-plugins-official"; \
    done \
 # ---- fish-history volume's mount point, owned by the user ----
 && mkdir -p ~/.local/share/fish \
 # ---- cleanup ----
 && rm -rf /tmp/mise.sh /tmp/rustup.sh /tmp/claude.sh ~/.cache/mise

# ---- container runtime: root as PID 1 (VS Code attaches as `devcontainer`) ----
USER root
WORKDIR /workspaces
CMD ["sleep", "infinity"]

# ---- entrypoint: docker socket permissions ----
COPY --chmod=755 config/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
