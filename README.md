# devcontainer base

One shared development image for all personal projects. Instead of every repo carrying
its own `dev` Dockerfile stage that re-installs the same toolchain, projects
reference this image and add only their project-specific bits (VS Code
extensions, extra services, project-only tools) in their `devcontainer.json`.

The same tools also install straight on a workstation, without containers: the
image is built by the same scripts.

## With or without devcontainers

| | How | What runs |
|---|---|---|
| **Devcontainer** | the image, `ghcr.io/fhassis/devcontainer` | the Dockerfile runs `src/scripts/install-system.sh --container` (root) and `src/scripts/install-tools.sh --container` (user) |
| **Workstation** (Debian/Ubuntu, native or WSL) | `./install.sh` | `install-system.sh` (+ `wsl-fixes.sh` on WSL) with sudo, then `install-tools.sh` |

```sh
git clone https://github.com/fhassis/devcontainer ~/devcontainer
~/devcontainer/install.sh      # run it again after a pull: it is idempotent
```

- [`src/scripts/install-system.sh`](./src/scripts/install-system.sh) (root): the Debian packages in
  [`config/apt-packages.txt`](./src/config/apt-packages.txt) and Docker from Docker's
  own apt repo: the CLI with the compose and buildx plugins in the image (the daemon
  is the host's), the full Docker Engine on a workstation.
- [`src/scripts/wsl-fixes.sh`](./src/scripts/wsl-fixes.sh) (root, WSL only): what
  Ubuntu's WSL image does and Debian's doesn't. Today one fix: Windows programs
  (`.exe`) keep running under systemd (`/etc/binfmt.d/WSLInterop.conf`).
- [`src/scripts/install-tools.sh`](./src/scripts/install-tools.sh) (user, no sudo, all in the home):
  the toolchains in [`config/mise.toml`](./src/config/mise.toml), Rust, Claude Code +
  plugins, chrome-devtools-mcp's config.

The terminal (fish, prompt, fzf, nvim…) is a separate layer: the
[dotfiles](https://github.com/fhassis/dotfiles) repo, on a workstation and in containers.

## Toolbelt

| Group | Tools |
| :--- | :--- |
| Shell | `bash` (login shell). The terminal (fish, tmux, prompt, fzf, zoxide, nvim, theme…) comes from [dotfiles](#terminal-setup-dotfiles) |
| Version control | `git` |
| Languages | Python 3.15 (+`uv`/`uvx`), Node 26 (+`npm`/`npx`), Rust stable (`rustup`, `cargo`, `clippy`, `rustfmt`) |
| Tool versions | [`mise`](https://mise.jdx.dev): installs python, node, postgres, kubectl, k3d, uv, helm, gh and the LSPs from [`config/mise.toml`](./src/config/mise.toml); a project's `mise.toml` (or `.nvmrc`) pins its own |
| Containers | `docker` CLI + `compose` + `buildx` (Docker's apt repo), using the host daemon through the mounted socket (docker-outside-of-docker), `kubectl` 1.37, `helm`, `k3d` 5 (local k3s clusters on the host daemon) |
| GitHub | `gh` |
| Database | PostgreSQL 18 client tools (`psql`, `pg_dump`…); the server runs as a compose service |
| Misc | `jq`, `nano`, `less`, `wget`, `zip`, `rsync`, `make`, `curl`, `openssh-client`, Debian's Chromium (headless and isolated, sized as a Xiaomi Redmi 12, for the Chrome DevTools MCP) |
| Claude Code | `claude` + plugins: ponytail, mattpocock-skills, frontend-design, code-review, chrome-devtools-mcp, and the LSP plugins for TypeScript, Pyright and rust-analyzer (their servers are in the image) |

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
  (with the compose and buildx plugins, from Docker's repo) talks to the *host* daemon
  (the workstation's Docker Engine, native or WSL) via the mounted `/var/run/docker.sock`.
  The entrypoint runs as root (PID 1) to align the in-container `docker` group GID
  with that socket, so the non-root user uses `docker` without sudo; VS Code
  attaches as `devcontainer` separately.
- **Everything in the home, at default locations, owned by `devcontainer`**, so
  installing another version needs no sudo: mise's tools in `~/.local/share/mise`,
  Rust in `~/.rustup` and `~/.cargo`.
- **Toolchains via mise.** `install-tools.sh` copies [`config/mise.toml`](./src/config/mise.toml)
  to `~/.config/mise/conf.d/dev.toml` and installs it: python, node, postgres,
  kubectl, k3d, uv, helm, gh and the language servers. mise merges it with the user's
  config (the dotfiles' terminal tools) and a project's `mise.toml`. In the image its
  shims are on `PATH`, so
  non-interactive shells (Claude's Bash tool, compose commands) get the tools and
  honor a project's pinned versions; interactive fish activates mise and switches
  on `cd`. A project's `.nvmrc` / `.node-version` is read too.
- **Python from mise, reused by uv.** mise installs a prebuilt Python (the same
  python-build-standalone builds uv uses). uv (by default, `python-preference =
  managed`) reuses it when a project's `.python-version` matches, and downloads its
  own otherwise.
- **Rust via rustup**, its own manager (Debian's `rustc` is frozen per release,
  1.85 on Trixie).
- **Everything tracks latest; a rebuild is the update.** mise, rustup and Claude
  Code come from their official install scripts. Pinned in `mise.toml`: Python
  3.15, Node 26, Postgres 18 (to match the server) and kubectl 1.37 (to match the
  cluster), k3d 5; a rebuild takes their latest patch.
  `make build` passes `--pull`, which refreshes the base image; the cached
  `RUN` layers only move when a layer above them changes.
- **Claude Code config in a shared volume.** `~/.claude` is the named volume
  `claude-config`, shared by every project: one `/login`, the same settings and
  plugins. `CLAUDE_CONFIG_DIR` points at it, so `.claude.json` lives there too.
  Docker seeds it from the image's plugins on first mount; plugins added to the
  image later need `claude plugin install` (or `docker volume rm claude-config`).
  Don't bind the host's `~/.claude`: it hides the image's plugins and carries
  host paths (e.g. `C:\...` from Windows).
- **apt for Debian's own packages** (git, gcc, chromium…) and Docker (from Docker's
  repo); everything else versioned comes from mise. In the image, the apt layer and
  the user's tools layer are separate, so a change to `mise.toml` doesn't redo apt.

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
`FROM ghcr.io/fhassis/devcontainer:latest` (commented in `compose.yml`).

## On Windows (WSL)

Debian in WSL is a workstation like any other: `install.sh` installs the Docker
Engine there, and VS Code (with the WSL extension) opens the devcontainer from it.

- **Code in the WSL filesystem** (e.g. `~/repos`), not `C:\`. A bind of `/mnt/c/…`
  goes through the Windows↔WSL file bridge: slow installs and builds, and file
  watching breaks. Open the folder from WSL (`code ~/repos/<repo>`) and *Reopen in
  Container*: compose.yml's `../..` bind puts the siblings in `/workspaces`, as on
  Linux.
- **Line endings.** `.gitattributes` forces LF: with `core.autocrlf=true` a
  Windows checkout would copy CRLF scripts into the image and break the
  entrypoint.
- **Paths in `docker run -v` / compose from inside the container** are resolved by
  the host's daemon, not the container: `/workspaces/...` doesn't exist there. Use
  the host's path or a named volume.

## Build & push

From this machine, no CI. The image goes to the GitHub Container Registry,
`ghcr.io/fhassis/devcontainer`. `make login` logs Docker in with the GitHub CLI's
token; once per machine, set up `gh` (from mise) with the packages scopes:

```bash
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
