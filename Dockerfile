# Set base image
FROM docker.io/debian:trixie-slim

# Set non-interactive frontend for apt
ENV DEBIAN_FRONTEND=noninteractive

# Install core tools
RUN \
    # Install dependencies and tools \
    apt-get update && apt-get install -y --no-install-recommends \
    git \
    git-lfs \
    fish \
    eza \
    starship \
    curl \
    openssh-client \
    ca-certificates && \
    # Clean up apt cache to reduce image size
    rm -rf /var/lib/apt/lists/* && \
    \
    # Configure Git LFS
    git lfs install --system

# Configure prompt and shortcuts for root user
RUN \
    # 1. Create standard config directory structure \
    mkdir -p /root/.config/fish/conf.d /root/.config/fish/functions /root/.config/fish/completions && \
    \
    # 2. Setup Starship (Standard path: ~/.config/starship.toml) \
    starship preset nerd-font-symbols -o /root/.config/starship.toml && \
    echo "starship init fish | source" > /root/.config/fish/conf.d/starship.fish && \
    \
    # 3. Create shortcuts in standard function files \
    echo "function ls; eza --icons --group-directories-first \$argv; end" > /root/.config/fish/functions/ls.fish && \
    echo "function ll; eza -l --icons --group-directories-first \$argv; end" > /root/.config/fish/functions/ll.fish && \
    echo "function la; eza -la --icons --group-directories-first \$argv; end" > /root/.config/fish/functions/la.fish && \
    \
    # 4. Set static greeting \
    echo "set -g fish_greeting '✨ Welcome to the DevContainer! 🚀'" > /root/.config/fish/conf.d/greeting.fish

# Ensure workspaces root exists for DevContainer mounting
RUN mkdir -p /workspaces
WORKDIR /workspaces

# Start fish shell by default
CMD ["fish"]