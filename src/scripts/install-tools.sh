#!/bin/bash
# Development tools, as the user (no sudo), all in the home: mise toolchains
# (config/mise.toml), Rust, Claude Code + plugins, chrome-devtools-mcp's config.
# Idempotent: run it again to add what's new. --container: also prepare the
# image (volumes' mount points, no download caches).
set -euo pipefail

HERE=$(cd "$(dirname "$0")/.." && pwd)
DL="curl -fsSL --ipv4 --retry 5 --retry-delay 2 --retry-all-errors"
container=false
if [ "${1:-}" = --container ]; then container=true; fi
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/.cargo/bin:$PATH" MISE_YES=1
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
say() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }

# ---- Rust (rustup), before mise: its cargo: tools build with cargo ----
if ! command -v rustup >/dev/null; then
    say "installing Rust"
    $DL https://sh.rustup.rs -o "$tmp/rustup.sh"
    sh "$tmp/rustup.sh" -y --no-modify-path --profile minimal -c clippy,rustfmt,rust-analyzer
fi

# ---- mise toolchains ----
if ! command -v mise >/dev/null; then
    say "installing mise"
    $DL https://mise.run -o "$tmp/mise.sh" && sh "$tmp/mise.sh"
fi
mkdir -p ~/.config/mise/conf.d
cp "$HERE/config/mise.toml" ~/.config/mise/conf.d/dev.toml
say "installing the mise toolchains"
mise install

# ---- Claude Code CLI (terminal `claude`) + plugins ----
if ! command -v claude >/dev/null; then
    say "installing Claude Code"
    $DL https://claude.ai/install.sh -o "$tmp/claude.sh" && bash "$tmp/claude.sh"
fi
say "Claude Code plugins"
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin marketplace add DietrichGebert/ponytail
claude plugin install ponytail@ponytail
for p in mattpocock-skills frontend-design code-review chrome-devtools-mcp \
         typescript-lsp pyright-lsp rust-analyzer-lsp; do
    claude plugin install "$p@claude-plugins-official"
done

# ---- chrome-devtools-mcp config (headless Chromium) ----
install -D -m 644 "$HERE/config/chrome-devtools-mcp.json" ~/.config/cd4a/config.json

# ---- image only: volumes' mount points owned by the user, no download caches ----
if $container; then
    mkdir -p ~/.local/share/fish
    rm -rf ~/.cache/mise
fi

say "done"
