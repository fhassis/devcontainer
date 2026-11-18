# devcontainer base

One shared development image for all personal projects. Instead of every repo carrying
its own `dev` Dockerfile stage that re-installs the same toolchain, projects
reference this image and add only their project-specific bits (VS Code
extensions, extra services, project-only tools) in their `devcontainer.json`.

## Toolbelt

| Group | Tools |
| :--- | :--- |
| Shell & prompt | `fish`, `starship` (nerd-fonts preset), `tmux`, and the workstation's fish setup: `eza` (`ls`/`la`), `bat` (`cat`, `MANPAGER`), `fzf` (Ctrl+T/R, Alt+C, `f`), `zoxide` (`z`/`zi`) |
| Version control | `git` |
| Languages | Python 3.15 via `uv` (+`uvx`), Node 26 via `fnm` (+`npm`/`npx`), Rust stable (`rustup`, `cargo`, `clippy`, `rustfmt`) |
| Containers | `docker` CLI + `dockerd` (outside-of-docker with a mounted socket, docker-in-docker when privileged) |
| Database | `postgresql-client-18` (`psql`) |
| Misc | `jq`, `nano`, `less`, `wget`, `zip`, `rsync`, `make`, `curl`, `openssh-client`, Debian's Chromium (headless and isolated, sized as a Xiaomi Redmi 12, for the Chrome DevTools MCP) |
| Claude Code | `claude` + plugins: ponytail, mattpocock-skills, frontend-design, code-review, chrome-devtools-mcp, and the LSP plugins for TypeScript, Pyright and rust-analyzer (their servers are in the image) |

fish completions are pre-generated for uv, docker, rustup and fnm (cargo's ship with fish).

## Design notes

- **Non-root user `devcontainer`** (UID/GID 1000, matches the typical host user),
  so files created in the workspace are owned correctly. fish is its login shell.
- **docker-outside-of-docker.** The Docker CLI talks to the *host* daemon via the
  mounted `/var/run/docker.sock`. The entrypoint runs as root (PID 1) to align the
  in-container `docker` group GID with that socket, so the non-root user uses
  `docker` without sudo; VS Code attaches as `devcontainer` separately.
- **docker-in-docker.** With no socket mounted and a privileged container, the
  entrypoint starts `dockerd` and drops to `devcontainer` via `gosu` (mount
  `/var/lib/docker` as a volume).
- **Base `debian:trixie-slim`, Python from uv.** `uv python install --default`
  puts the `PYTHON_VERSION` build's `python` / `python3` in `/usr/local/share/uv/bin`,
  on `PATH`, so every shell (Claude's Bash tool included) has Python. uv uses only
  its managed Pythons (`UV_PYTHON_PREFERENCE=only-managed`) and downloads the one a
  project's `.python-version` asks for on `uv sync`. Both dirs are owned by
  `devcontainer`, so no sudo.
- **Everything tracks latest; a rebuild is the update.** uv, fnm, rustup
  and Claude Code come from their official install scripts. Pinned, as build args:
  the Postgres client major (`PG_MAJOR`, to match the server), Python's minor
  (`PYTHON_VERSION`, 3.15) and Node's major (`NODE_VERSION`, 26); a rebuild takes
  their latest patch. `make image-build` passes `--pull`, which refreshes the base
  image; the cached `RUN` layers only move when a layer above them changes.
- **Node via fnm.** fnm's `default` alias is on `PATH`, so non-interactive
  shells (Claude's Bash tool, compose commands) get Node 26; interactive fish
  also switches to a project's `.node-version` / `.nvmrc` on `cd`.
- **Rust** lives in `/usr/local/{rustup,cargo}`, owned by `devcontainer`, so
  `cargo install` and `rustup update` work without sudo. Debian's own `rustc`
  package is frozen per release (1.85 on Trixie).
- **Claude Code config in a shared volume.** `~/.claude` is the named volume
  `claude-config`, shared by every project: one `/login`, the same settings and
  plugins. `CLAUDE_CONFIG_DIR` points at it, so `.claude.json` lives there too.
  Docker seeds it from the image's plugins on first mount; plugins added to the
  image later need `claude plugin install` (or `docker volume rm claude-config`).
  Don't bind the host's `~/.claude`: it hides the image's plugins and carries
  host paths (e.g. `C:\...` from Windows).
- **One apt layer.** A single `RUN` bootstraps the minimum to add repositories,
  registers the Docker and PostgreSQL-PGDG repos, does one `apt install`, and
  drops the cache — no per-tool add/install/clean duplication.

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

**Volumes.** `fish-history` and service data (`postgres-data`) are per project
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
`FROM registry.gitlab.com/fhassis/devcontainer:latest` (commented in `compose.yml`).

## On Windows (Rancher Desktop)

The same `.devcontainer/` works with Rancher Desktop's WSL engine; the
differences are where the code lives and a few path rules.

- **Engine: dockerd (moby)**, not containerd, in Rancher Desktop's settings.
- **Registry login** from PowerShell (Git Bash's `docker login` fails with
  "non TTY device"), with a GitLab personal access token (`read_registry`, plus
  `write_registry` to push):
  ```powershell
  docker login registry.gitlab.com -u fhassis   # paste the token as the password
  ```
  The credential is kept in the Windows credential store and reused by VS Code.
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

## Build & publish

From this machine, no CI. Log in to the registry once
(`docker login registry.gitlab.com`, with a token that has `write_registry`), then:

```bash
make image-build                          # local image, :latest
make image-build image-push               # build + push :latest
make image-build image-push TAG=v2        # build + push a named tag
```

> Built for `linux/amd64`. The Docker apt repo hardcodes `amd64`;
> adjust it in `src/Dockerfile` for arm64.
