# DevContainer (`debian:trixie-slim`)

A lightweight, high-performance development container based on **Debian Trixie Slim**. This image is designed for speed and a modern terminal experience.

## 📦 Included Packages

* **Shell & Prompt**
    * `fish`: A smart and user-friendly command-line shell.
    * `starship`: The cross-shell customizable prompt, pre-configured with the `nerd-font-symbols` preset.
* **Modern CLI Tools**
    * `eza`: A modern replacement for `ls` with color-coding and icons.
* **Core Utilities**
    * `git`: Essential for version control.
    * `git-lfs`: Essential for version control of binary files.
    * `curl` & `ca-certificates`: For secure networking and tool installation.

## 🚀 Key Features

* **Persistence**: Configured to store `fish` history in a persistent volume so your commands are remembered across container rebuilds.
* **Aliased Experience**: The following aliases are baked into the shell:
    * `ls` → `eza --icons --group-directories-first`
    * `ll` → `eza -lh --icons --group-directories-first`
    * `la` → `eza -la --icons --group-directories-first`
* **Non-Root User**: Runs as the `vscode` user for security and seamless VS Code integration.

> ℹ️ **NOTE** the `runArgs` option `--userns=keep-id` in [devcontainer.json](./devcontainer/devcontainer.json) is required to map the permissions from your user and the one in the container, so that you can create files in the project folder with no errors when using `podman`.


## 🛠 Using the image as a devcontainer

To use this image in VS Code, ensure your `.devcontainer/devcontainer.json` includes the persistent volume mount. An example can be found in [devcontainer.json](./devcontainer/devcontainer.json).


## 🚢 Build and Publish

To build this image and push it to your Docker Hub registry (`docker.io/fhassis/devcontainer-base`), follow these steps:

### 1. Build the Image

Build and tag the image using your registry path:

```bash
podman build --format docker -t docker.io/fhassis/devcontainer-base:latest .
```
> ℹ️ **NOTE**: the `--format docker` option removes the warning `WARN[0003] SHELL is not supported for OCI image format... Must use docker format` when creating the devcontainers in vscode.

### 2. Login to Docker Hub
```bash
podman login docker.io -u fhassis
```

### 3. Push the Image

```bash
podman push docker.io/fhassis/devcontainer-base:latest
```
