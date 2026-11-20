# Shared devcontainer image: Debian Trixie slim + the toolchains in config/mise.toml.
# The terminal setup comes from the dotfiles repo. See README.md.

FROM debian:trixie-slim

# ---- bash with pipefail, so a failing `curl | tar` fails the build ----
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# ---- downloads: to a file, then run (curl | sh can't retry); IPv4 + retries
#      dodge the broken-IPv6 "connection reset" ----
ARG DL="curl -fsSL --ipv4 --retry 5 --retry-delay 2 --retry-all-errors"

# ---- Android command-line tools build: Google has no "latest" URL for the zip ----
ARG ANDROID_CMDLINE_TOOLS=16111833

# ---- everything apt, in one layer: install, clean ----
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      curl ca-certificates unzip xz-utils git openssh-client make jq nano less wget zip rsync \
      # the C linker rustc needs
      gcc libc6-dev \
      # the toolchain for `flutter build linux`
      clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-14-dev \
      # for chrome-devtools-mcp (a Claude plugin below)
      chromium \
 && rm -rf /var/lib/apt/lists/*

# ---- environment variables ----
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 UV_LINK_MODE=copy \
    UV_PYTHON_PREFERENCE=managed \
    # all of Claude Code's config in ~/.claude (one volume)
    CLAUDE_CONFIG_DIR=/home/devcontainer/.claude \
    # Flutter, the Android SDK (Android Studio's default path) and the JDK Gradle uses
    FLUTTER_ROOT=/home/devcontainer/.local/share/flutter \
    ANDROID_HOME=/home/devcontainer/Android/Sdk \
    JAVA_HOME=/home/devcontainer/.local/share/mise/installs/java/temurin-21 \
    # Flutter's `chrome` device and `flutter test --platform chrome` look for Google Chrome
    CHROME_EXECUTABLE=/usr/bin/chromium \
    PATH=/home/devcontainer/.local/bin:/home/devcontainer/.local/share/mise/shims:/home/devcontainer/.cargo/bin:/home/devcontainer/.local/share/flutter/bin:/home/devcontainer/Android/Sdk/cmdline-tools/latest/bin:/home/devcontainer/Android/Sdk/platform-tools:$PATH

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
 # ---- Flutter (stable channel) ----
 && git clone -q --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_ROOT" \
 && flutter config --no-analytics \
 && dart --disable-analytics \
 # ---- Android SDK, with the `android` CLI (sdkmanager's replacement; it unpacks
 #      itself into ~/.android on first run, and accepts the licenses on install):
 #      platform-tools and the platform + build-tools this Flutter compiles
 #      against. Gradle fetches anything else a project needs, NDK included ----
 && $DL "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}_latest.zip" -o /tmp/cmdline-tools.zip \
 && unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools \
 && mkdir -p "$ANDROID_HOME/cmdline-tools" \
 && mv /tmp/cmdline-tools/cmdline-tools "$ANDROID_HOME/cmdline-tools/latest" \
 && echo --no-metrics > ~/.androidrc \
 && sdk=$(sed -n 's/.*val compileSdkVersion: Int = \([0-9]*\).*/\1/p' \
      "$FLUTTER_ROOT/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt") \
 && { [ -n "$sdk" ] || { echo "compileSdkVersion not found in Flutter's FlutterExtension.kt" >&2; exit 1; }; } \
 && bt=$(android sdk list --all "build-tools/$sdk*" | awk '$1 ~ /^build-tools\// {print $1}' | grep -v -- -rc | sort -V | tail -1) \
 && android sdk install platform-tools "platforms/android-$sdk" "$bt" >/dev/null \
 && flutter precache --web --android --linux \
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
 # Dart and Flutter MCP server + the official Flutter/Dart skills
 && claude plugin marketplace add flutter/agent-plugins \
 && claude plugin install dart-flutter@dart-flutter \
 # ---- volumes' mount points (fish history, gradle cache), owned by the user ----
 && mkdir -p ~/.local/share/fish ~/.gradle \
 # ---- cleanup ----
 && rm -rf /tmp/mise.sh /tmp/rustup.sh /tmp/claude.sh /tmp/cmdline-tools* ~/.cache/mise

# ---- container runtime: root as PID 1 (VS Code attaches as `devcontainer`) ----
USER root
WORKDIR /workspaces
CMD ["sleep", "infinity"]

# ---- entrypoint: docker socket permissions ----
COPY --chmod=755 config/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
