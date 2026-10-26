# devcontainer base

One shared development image for all personal projects. Instead of every repo carrying
its own `dev` Dockerfile stage that re-installs the same toolchain, projects
reference this image and add only their project-specific bits (VS Code
extensions, extra services, project-only tools) in their `devcontainer.json`.

## Toolbelt

| Group | Tools |
| :--- | :--- |
| Shell & prompt | `fish`, `starship` (nerd-fonts preset), `tmux`, and the workstation's fish setup: `eza` (`ls`/`la`), `bat` (`cat`, `MANPAGER`), `fzf` (Ctrl+T/R, Alt+C, `f`), `zoxide` (`z`/`zi`) |
| Version control | `git`, `glab` (GitLab CLI) |
| Languages | Python 3.14 (base image), `uv` (+`uvx`), Node 24 via `fnm` (+`npm`/`npx`), `bun`, Rust stable (`rustup`, `cargo`, `clippy`, `rustfmt`) |
| Containers | `docker` CLI + `dockerd` (outside-of-docker with a mounted socket, docker-in-docker when privileged) |
| Database | `postgresql-client-18` (`psql`) |
| Misc | `jq`, `nano`, `less`, `wget`, `zip`, `rsync`, `make`, `curl`, `openssh-client`, Google Chrome stable (headless, for the Chrome DevTools MCP) + Playwright Chromium dependencies |
| Claude Code | `claude` + plugins: ponytail, mattpocock-skills, frontend-design, code-review, chrome-devtools-mcp, and the LSP plugins for TypeScript, Pyright and rust-analyzer (their servers are in the image) |

fish completions are pre-generated for uv, docker, glab, rustup and fnm. (bun has no
`completion fish` subcommand — fish infers it from `--help`; cargo's ship with fish.)

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
- **Base `python:3.14-slim-trixie`.** uv is set to use that Python and never
  download its own (`UV_PYTHON_DOWNLOADS=never`, `UV_PYTHON_PREFERENCE=only-system`),
  so Python comes from the image, not from the home directory.
- **Everything tracks latest; a rebuild is the update.** bun, uv, fnm, rustup
  and Claude Code come from their official install scripts, glab from its latest
  release. Pinned: the Postgres client major (`PG_MAJOR`, to match the server),
  Python's minor (3.14, the base tag) and Node's major (24). `make image-build` passes `--pull`, which refreshes the base
  image; the cached `RUN` layers only move when a layer above them changes.
- **Node via fnm.** fnm's `default` alias is on `PATH`, so non-interactive
  shells (Claude's Bash tool, compose commands) get Node 24; interactive fish
  also switches to a project's `.node-version` / `.nvmrc` on `cd`.
- **Rust** lives in `/usr/local/{rustup,cargo}`, owned by `devcontainer`, so
  `cargo install` and `rustup update` work without sudo. Debian's own `rustc`
  package is frozen per release (1.85 on Trixie).
- **One apt layer.** A single `RUN` bootstraps the minimum to add repositories,
  registers the Docker and PostgreSQL-PGDG repos, does one `apt install`, and
  drops the cache — no per-tool add/install/clean duplication.

## Using it in a project

Reference the published image from the project's `.devcontainer/devcontainer.json`
(see [the example here](./.devcontainer/devcontainer.json)):

```jsonc
{
  "image": "registry.gitlab.com/fhassis/devcontainer:latest",
  "remoteUser": "devcontainer",
  "mounts": [
    "source=${localWorkspaceFolderBasename}-fish-history,target=/home/devcontainer/.local/share/fish,type=volume",
    "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind"
  ],
  "customizations": { "vscode": { "extensions": [ /* project-specific */ ] } },
  "postCreateCommand": "uv sync"  // or: bun install — per project
}
```

Projects that need extra services (Postgres, CouchDB, …) use a `dockerComposeFile`
with this image as the devcontainer service, exactly like the current setups.

## Build & publish

From this machine, no CI. Log in to the registry once
(`docker login registry.gitlab.com`, with a token that has `write_registry`), then:

```bash
make image-build                          # local image, :latest
make image-build image-push               # build + push :latest
make image-build image-push TAG=v2        # build + push a named tag
```

> Built for `linux/amd64`. The Docker apt repo and the glab URL hardcode `amd64`;
> adjust them in `src/Dockerfile` for arm64.
