# Personal Dev Container (`debian:trixie-slim`)

A lightweight, high-performance development container based on **Debian Trixie Slim**. This image is designed for speed and a modern terminal experience.

## 📦 Included Packages

* **Shell & Prompt**
    * `fish`: A smart and user-friendly command-line shell.
    * `starship`: The cross-shell customizable prompt, pre-configured with the `nerd-font-symbols` preset.
* **Modern CLI Tools**
    * `eza`: A modern replacement for `ls` with color-coding and icons.
* **Core Utilities**
    * `git`: Essential for version control.
    * `curl` & `ca-certificates`: For secure networking and tool installation.

## 🚀 Key Features

* **Persistence**: Configured to store `fish` history in a persistent volume so your commands are remembered across container rebuilds.
* **Aliased Experience**: The following aliases are baked into the shell:
    * `ls` → `eza --icons --group-directories-first`
    * `ll` → `eza -lh --icons --grid-group-directories-first`
* **Non-Root User**: Runs as the `vscode` user for security and seamless VS Code integration.

## 🛠 Local Setup

To use this image in VS Code, ensure your `.devcontainer/devcontainer.json` includes the persistent volume mount and font settings:

```json
{
    "name": "Personal Dev Environment",
    "image": "fhassis/devcontainer:trixie",
    "mounts": [
        "source=fish-history,target=/home/vscode/.local/share/fish,type=volume"
    ],
    "customizations": {
        "vscode": {
            "settings": {
                "terminal.integrated.defaultProfile.linux": "fish"
            }
        }
    },
    "remoteUser": "vscode"
}