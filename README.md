# devcontainer base

One shared development image for all my projects. Instead of every repo carrying
its own `dev` Dockerfile stage that re-installs the same toolchain, projects
reference this image and add only their project-specific bits (VS Code
extensions, extra services, project-only tools) in their `devcontainer.json`.

## Toolbelt

| Group | Tools |
| :--- | :--- |
| Shell & prompt | `fish`, `starship` (no-runtime-versions preset), `eza` (aliased to `ls`/`ll`/`la`) |
| Version control | `git`, `git-lfs`, `glab` (GitLab CLI), `openssh-client` |
| Languages | Python 3.14 (system), `uv` (+`uvx`), `bun` (JS/TS runtime) |
| Kubernetes | `kubectl`, `k3d`, `helm`, `k9s` |
| Containers | `docker` CLI (docker-outside-of-docker) |
| Database | `postgresql-client-18` (`psql`) |
| Misc | `make`, `curl`, locales (`en_US.UTF-8`) |

fish completions are pre-generated for uv, docker, kubectl, helm, k3d and glab.
(bun has no `completion fish` subcommand — fish infers it from `--help`; k9s is a
TUI with no completion.)

## Design notes

- **Non-root user `devcontainer`** (UID/GID 1000, matches the typical host user),
  so files created in the workspace are owned correctly. fish is its login shell.
- **docker-outside-of-docker.** The Docker CLI talks to the *host* daemon via the
  mounted `/var/run/docker.sock`. The entrypoint runs as root (PID 1) to align the
  in-container `docker` group GID with that socket, so the non-root user uses
  `docker`/`k3d` without sudo; VS Code attaches as `devcontainer` separately.
- **k3d access model.** The k3d *cluster* runs on the host (managed by the
  `vps-infra` repo, `make k3d-local`); this image gives you the CLIs + the host
  docker socket to *operate* it (`kubectl`, `k3d image import`, `k9s`). The
  cluster does not run inside the container.
- **Pinned versions.** All tool versions are `ARG`s at the top of the
  [`Dockerfile`](./Dockerfile) — bump them there. uv and bun are copied from their
  official images; the k8s tools and glab are pinned binary downloads.
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

CI ([`.gitlab-ci.yml`](./.gitlab-ci.yml)) builds and pushes to the project's GitLab
Container Registry on the default branch (`:latest` + `:<short-sha>`) and on git
tags (`:<tag>`). Pin projects to a tag, not `:latest`, so a base bump is explicit.

Local build for testing:

```bash
docker build -t registry.gitlab.com/fhassis/devcontainer:dev .
```

> Built for `linux/amd64`. The k8s/glab binary URLs hardcode `amd64`; adjust the
> `arch` in the Dockerfile for arm64.
