# =============================================================================
# fhassis devcontainer base — Bun on Debian Trixie slim (oven/bun) + a toolbelt.
#
# One image for every project: shell, Bun, the Kubernetes/Docker/Postgres/git
# toolbelt, and the system libraries headless Chromium needs.
# Per-project bits (VS Code extensions, extra services, project-only tools) live
# in each project's devcontainer.json — not here.
# =============================================================================

# ---- pinned versions (bump here) -------------------------------------------
ARG UV_VERSION=0.11.24
ARG BUN_VERSION=1.3.14-slim
ARG KUBECTL_VERSION=1.36.1
ARG HELM_VERSION=3.17.0
ARG K3D_VERSION=5.9.0
ARG K9S_VERSION=0.51.0
ARG GLAB_VERSION=1.105.0
ARG PG_MAJOR=18

# ---- uv pulled from its official image (Astral's documented install path) ---
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

# =============================================================================
# Base = oven/bun (Debian Trixie slim).
FROM oven/bun:${BUN_VERSION}

# bash with pipefail so a failing `curl | tar` actually fails the build.
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Re-declare the ARGs needed after this FROM (values inherited from the globals).
ARG PG_MAJOR
ARG KUBECTL_VERSION
ARG HELM_VERSION
ARG K3D_VERSION
ARG K9S_VERSION
ARG GLAB_VERSION

# ---- everything apt, in ONE layer: bootstrap -> add repos -> install -> clean
# Bootstrap curl/gpg, register the third-party repos, then a single apt install and drop the cache.
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates gnupg \
 && install -m 0755 -d /etc/apt/keyrings \
 # Docker CE — for docker-ce-cli
 && curl -fsSL --ipv4 --retry 5 --retry-delay 2 --retry-all-errors https://download.docker.com/linux/debian/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
 && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian trixie stable" \
      > /etc/apt/sources.list.d/docker.list \
 # PostgreSQL PGDG — Trixie only ships up to pg17, we want the pinned major
 && curl -fsSL --ipv4 --retry 5 --retry-delay 2 --retry-all-errors https://www.postgresql.org/media/keys/ACCC4CF8.asc \
      | gpg --dearmor -o /etc/apt/keyrings/pgdg.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/pgdg.gpg] https://apt.postgresql.org/pub/repos/apt trixie-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list \
 # single install: Debian packages + the two repos above
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      git openssh-client make \
      fish starship eza \
      docker-ce-cli docker-buildx-plugin docker-compose-plugin \
      "postgresql-client-${PG_MAJOR}" \
 # browser system libraries (NOT a browser binary) for headless Chromium, so the
 # per-project automation MCPs (Playwright / Chrome DevTools) run its chrome versions.
 && bunx playwright install-deps chromium \
 && rm -rf /var/lib/apt/lists/* /root/.bun/install/cache

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 SHELL=/usr/bin/fish \
    PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 UV_LINK_MODE=copy \
    STARSHIP_CONFIG=/home/devcontainer/.config/starship.toml \
    PATH=/home/devcontainer/.local/bin:$PATH

# ---- Python tooling: uv ----
COPY --from=uv /uv /uvx /bin/

# ---- single-binary tools with no clean apt repo: pinned downloads, one layer ----
# Download to a file THEN extract (curl|tar can't retry safely); `--ipv4` + retries
# dodge the broken-IPv6 "connection reset" we hit on CI runners.
RUN arch=amd64; \
    dl="curl -fsSL --ipv4 --retry 5 --retry-delay 2 --retry-all-errors"; \
    $dl "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${arch}/kubectl" -o /usr/local/bin/kubectl \
 && $dl "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${arch}.tar.gz" -o /tmp/helm.tgz \
 && tar -xzf /tmp/helm.tgz -C /tmp \
 && mv "/tmp/linux-${arch}/helm" /usr/local/bin/helm \
 && $dl "https://github.com/k3d-io/k3d/releases/download/v${K3D_VERSION}/k3d-linux-${arch}" -o /usr/local/bin/k3d \
 && $dl "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_${arch}.tar.gz" -o /tmp/k9s.tgz \
 && tar -xzf /tmp/k9s.tgz -C /tmp k9s \
 && mv /tmp/k9s /usr/local/bin/k9s \
 && $dl "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_${arch}.tar.gz" -o /tmp/glab.tgz \
 && tar -xzf /tmp/glab.tgz -C /tmp \
 && mv /tmp/bin/glab /usr/local/bin/glab \
 && chmod +x /usr/local/bin/{kubectl,helm,k3d,k9s,glab} \
 && rm -rf "/tmp/linux-${arch}" /tmp/bin /tmp/*.tgz

# ---- non-root user: rename oven/bun's preset user (uid/gid 1000) to `devcontainer`,
#      shell fish; docker group GID is auto (the entrypoint aligns it to the socket). ----
RUN groupmod -n devcontainer bun \
 && usermod -l devcontainer -d /home/devcontainer -m -s /usr/bin/fish bun \
 && groupadd docker \
 && usermod -aG docker devcontainer

# ---- shell config + fish completions, as the non-root user ----
USER devcontainer
RUN mkdir -p ~/.local/share/fish ~/.config/fish/completions \
 && starship preset nerd-font-symbols -o ~/.config/starship.toml \
 && uv generate-shell-completion fish > ~/.config/fish/completions/uv.fish \
 && docker  completion fish > ~/.config/fish/completions/docker.fish \
 && kubectl completion fish > ~/.config/fish/completions/kubectl.fish \
 && helm    completion fish > ~/.config/fish/completions/helm.fish \
 && k3d     completion fish > ~/.config/fish/completions/k3d.fish \
 && glab    completion -s fish > ~/.config/fish/completions/glab.fish
# bun has no `completion fish` subcommand (fish infers it from --help); k9s is a TUI.
COPY config/config.fish /etc/fish/conf.d/config.fish

# ---- Claude Code CLI (terminal `claude`), installed for the non-root user ----
RUN curl -fsSL --ipv4 --retry 5 --retry-delay 2 --retry-all-errors https://claude.ai/install.sh | bash

# ---- entrypoint runs as root to align the docker group GID with the mounted
#      socket; VS Code attaches as `devcontainer` via docker exec, separately.
USER root
COPY config/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
WORKDIR /workspaces
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["sleep", "infinity"]
