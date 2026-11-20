# devcontainer base

One shared development image for all personal projects. Instead of every repo carrying
its own `dev` Dockerfile stage that re-installs the same toolchain, projects
reference this image and add only their project-specific bits (VS Code
extensions, extra services, project-only tools) in their `devcontainer.json`.

## Toolbelt

| Group | Tools |
| :--- | :--- |
| Shell | `bash` (login shell). The terminal (fish, tmux, prompt, fzf, zoxide, nvim, theme…) comes from [dotfiles](#terminal-setup-dotfiles) |
| Version control | `git` |
| Languages | Python 3.15 (+`uv`/`uvx`), Node 26 (+`npm`/`npx`), Rust stable (`rustup`, `cargo`, `clippy`, `rustfmt`), Flutter stable + Dart |
| Mobile & desktop builds | Android SDK (the `android` CLI, `adb`) + Java 21 (Temurin); `clang`, `cmake`, `ninja`, GTK 3 for `flutter build linux` |
| Tool versions | [`mise`](https://mise.jdx.dev): installs python, node, java, postgres, kubectl, uv, helm, gh and the LSPs from [`config/mise.toml`](./src/config/mise.toml); a project's `mise.toml` (or `.nvmrc`) pins its own |
| Containers | `docker` CLI + `compose` + `buildx`, using the host daemon through the mounted socket (docker-outside-of-docker), `kubectl` 1.37, `helm` |
| Database | PostgreSQL 18 client tools (`psql`, `pg_dump`…); the server runs as a compose service |
| Misc | `jq`, `nano`, `less`, `wget`, `zip`, `rsync`, `make`, `curl`, `openssh-client`, Debian's Chromium (headless and isolated, sized as a Xiaomi Redmi 12, for the Chrome DevTools MCP) |
| Claude Code | `claude` + plugins: ponytail, mattpocock-skills, frontend-design, code-review, chrome-devtools-mcp, dart-flutter (the Dart and Flutter MCP server and the official skills), and the LSP plugins for TypeScript, Pyright and rust-analyzer (their servers are in the image) |

## Terminal setup (dotfiles)

The image ships the tools, not the terminal's look and feel. That comes from the
[dotfiles](https://github.com/fhassis/dotfiles) repo, which VS Code clones into
every new container and installs (`~/dotfiles/install.sh`: fish config, starship,
fzf, zoxide, eza, bat, nvim, delta, Catppuccin, fish completions). The template's
`devcontainer.json` already sets it, in `customizations.vscode.settings` (the same
two settings also work in your VS Code *user* settings, for every container):

```jsonc
"dotfiles.repository": "fhassis/dotfiles",
"dotfiles.installCommand": "install.sh"
```

Without it the container works the same, with a plain fish.

## Design notes

- **Non-root user `devcontainer`** (UID/GID 1000, matches the typical host user),
  so files created in the workspace are owned correctly. Its login shell is bash;
  VS Code's terminal opens `~/.local/bin/fish` (installed by the dotfiles), or
  bash when it isn't there.
- **docker-outside-of-docker only.** The image has no daemon: the Docker CLI
  (with the compose and buildx plugins, all from mise) talks to the *host* daemon
  (Rancher Desktop, or Docker on Linux) via the mounted `/var/run/docker.sock`.
  The entrypoint runs as root (PID 1) to align the in-container `docker` group GID
  with that socket, so the non-root user uses `docker` without sudo; VS Code
  attaches as `devcontainer` separately.
- **Everything in the home, at default locations, owned by `devcontainer`**, so
  installing another version needs no sudo: mise's tools in `~/.local/share/mise`,
  Rust in `~/.rustup` and `~/.cargo`, Flutter in `~/.local/share/flutter`, the
  Android SDK in `~/Android/Sdk` (Android Studio's default).
- **Toolchains via mise.** [`config/mise.toml`](./src/config/mise.toml) is copied
  to `/etc/mise/config.toml` and installed at build time: python, node, postgres,
  java, kubectl, uv, helm, gh, the docker CLI and plugins, and the language
  servers. mise merges it with the user's config (the dotfiles'
  terminal tools) and a project's `mise.toml`. Its shims are on `PATH`, so
  non-interactive shells (Claude's Bash tool, compose commands) get the tools and
  honor a project's pinned versions; interactive fish activates mise and switches
  on `cd`. A project's `.nvmrc` / `.node-version` is read too.
- **Python from mise, reused by uv.** mise installs a prebuilt Python (the same
  python-build-standalone builds uv uses). With `UV_PYTHON_PREFERENCE=managed`, uv
  reuses it when a project's `.python-version` matches, and downloads its own
  otherwise.
- **Rust via rustup**, its own manager (Debian's `rustc` is frozen per release,
  1.85 on Trixie).
- **Flutter and the Android SDK.** Flutter is a clone of the stable channel and
  writes its own `bin/cache`. The SDK has the cmdline-tools (a pinned build,
  `ANDROID_CMDLINE_TOOLS`: Google has no "latest" URL) and its `android` CLI, which
  replaced `sdkmanager` and accepts the licenses on install; the
  platform-tools, and the platform + build-tools this Flutter compiles against;
  Gradle downloads anything else a project needs (NDK included) on its first build.
  Java comes from mise (`JAVA_HOME` points at it); `~/.gradle` is a per-project
  volume. **Windows builds aren't possible here**: Flutter doesn't cross-compile,
  and `flutter build windows` needs a Windows host with Visual Studio.
- **Everything tracks latest; a rebuild is the update.** mise, rustup and Claude
  Code come from their official install scripts, Flutter from its stable branch.
  Pinned in `mise.toml`: Python 3.15, Node 26, Java 21, Postgres 18 (to match the
  server) and kubectl 1.37 (to match the cluster); a rebuild takes their latest patch.
  `make build` passes `--pull`, which refreshes the base image; the cached
  `RUN` layers only move when a layer above them changes.
- **Claude Code config in a shared volume.** `~/.claude` is the named volume
  `claude-config`, shared by every project: one `/login`, the same settings and
  plugins. `CLAUDE_CONFIG_DIR` points at it, so `.claude.json` lives there too.
  Docker seeds it from the image's plugins on first mount; plugins added to the
  image later need `claude plugin install` (or `docker volume rm claude-config`).
  Don't bind the host's `~/.claude`: it hides the image's plugins and carries
  host paths (e.g. `C:\...` from Windows).
- **apt only for Debian's own packages** (git, gcc, chromium…), in one layer with
  no third-party repos; everything versioned comes from mise.

## Using it in a project

Copy this repo's [`.devcontainer/`](./.devcontainer/) folder into the project as is:
the setup is always a compose, even with no extra services.

- [`compose.yml`](./.devcontainer/compose.yml) holds the containers and volumes: the
  `devcontainer` service (this image, the parent folder at `/workspaces`, the docker
  socket) and optional services such as the example Postgres.
- [`devcontainer.json`](./.devcontainer/devcontainer.json) holds VS Code's part: which
  service to attach to, `remoteUser`, extensions and settings, `postCreateCommand`.

Per project, change the `name` in `devcontainer.json` and in `compose.yml`, trim the
extensions, and add a `postCreateCommand` (`uv sync`, `npm install`, …). The compose
`name:` prefixes the project's containers, volumes and network, so it must be unique:
two projects left with the same name share them. Keep it set even though Docker
Compose would derive one: without it, the setup breaks under Podman.

**Volumes.** `fish-history`, `gradle-cache` and service data (`postgres-data`) are per project
(compose prefixes them). `claude-config` is shared by every project, so it is
`external`: `docker compose down -v` never deletes it, and the `initializeCommand`
creates it on the host if it doesn't exist yet.

**Extra services** sit behind a compose `profile`, so copying the folder doesn't start
them. Turn one on with `"runServices": ["postgres"]` in
`devcontainer.json` (naming a profiled service starts it; the `devcontainer`
service is added automatically), or outside VS Code with
`docker compose --profile postgres up -d`. The devcontainer reaches them by service
name (`postgres:5432`). No port is published on the host, so several projects can
run side by side; add `127.0.0.1:` ports when a host tool needs one.

**Project-only tools:** swap `image:` for a small Dockerfile that starts
`FROM ghcr.io/fhassis/devcontainer:latest` (commented in `compose.yml`).

## Flutter

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080  # r = hot reload, R = restart
flutter build apk          # or appbundle; build/app/outputs/...
flutter build linux        # build/linux/x64/release/bundle, runs on the host
```

The web server is what the phone's browser opens; Claude can also hot reload it
through the Dart MCP server. To run on the phone itself (native hot reload), turn
on *Wireless debugging* (Android 11+) and `adb pair <ip>:<port>` once, then
`adb connect <ip>:<port>` and `flutter run`.

## On Windows (Rancher Desktop)

The same `.devcontainer/` works with Rancher Desktop's WSL engine; the
differences are where the code lives and a few path rules.

- **Engine: dockerd (moby)**, not containerd, in Rancher Desktop's settings.
- **Registry login:** `make login` (see [Build & push](#build--push)). The
  credential is kept in the Windows credential store and reused by VS Code.
- **Clone into a container volume, not `C:\`.** A bind of `C:\Users\…\Repos` goes
  through the Windows↔WSL file bridge: slow installs and builds, and file
  watching breaks. Instead use *Dev Containers: Clone Repository in Named Container
  Volume…* and pick the same volume (e.g. `repos`) every time: it is mounted at
  `/workspaces` and each repo lands in `/workspaces/<repo>`, so siblings are reachable
  as on Linux. In this mode VS Code mounts that volume itself, and compose.yml's
  `../..` bind and the `workspaceFolder` here are not what places the code
  (not yet re-tested with the compose setup). The code lives only in the volume — push often, and reach it through
  VS Code or `docker cp`, not Explorer.
- **The Docker socket** (`/var/run/docker.sock`) resolves inside Rancher's WSL
  distro, so the mount works as is. There it is `660` with GID 101, which this
  image already uses for `_ssh` (from `openssh-client`), so the entrypoint adds
  `devcontainer` to that group instead of renumbering `docker`.
- **Line endings.** `.gitattributes` forces LF: with `core.autocrlf=true` a
  Windows checkout would copy CRLF scripts into the image and break the
  entrypoint.
- **Paths in `docker run -v` / compose from inside the container** are resolved by
  Rancher's daemon, not the container: `/workspaces/...` doesn't exist there. Mount
  named volumes instead (e.g. `-v repos:/workspaces`).
- **Git Bash** rewrites leading-`/` arguments into Windows paths
  (`/var/run/docker.sock` → `C:/Program Files/Git/var/...`); prefix the command
  with `MSYS_NO_PATHCONV=1`, or use PowerShell.
- **`make`** isn't part of Windows; install it (`winget install ezwinports.make`),
  or run the `docker build` / `docker push` lines from the [Makefile](./Makefile).

## Build & push

From this machine, no CI. The image goes to the GitHub Container Registry,
`ghcr.io/fhassis/devcontainer`. `make login` logs Docker in with the GitHub CLI's
token; once per machine, set up `gh` with the packages scopes:

```bash
winget install --id GitHub.cli -e                  # Windows; on Linux, your package manager
gh auth login                                      # GitHub.com, SSH, browser
gh auth refresh -s write:packages,read:packages
```

Then:

```bash
make login                                # once per machine
make build                                # local image, :latest
make build push                           # build + push :latest
make build push TAG=v2                    # build + push a named tag
```

A new package on ghcr.io is private: other machines must `make login` to pull
it, or make it public in the package's settings on GitHub.
