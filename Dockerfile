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

# Configure prompt and shortcuts for all users
RUN \
    # 1. Create global fish directory structure \
    mkdir -p /etc/fish/conf.d /etc/fish/functions && \
    \
    # 2. Setup Starship globally \
    starship preset nerd-font-symbols -o /etc/starship.toml && \
    echo "set -gx STARSHIP_CONFIG /etc/starship.toml" > /etc/fish/conf.d/starship.fish && \
    echo "starship init fish | source" >> /etc/fish/conf.d/starship.fish && \
    \
    # 3. Create global shortcuts (functions) \
    echo "function ls; eza --icons --group-directories-first \$argv; end" > /etc/fish/functions/ls.fish && \
    echo "function ll; eza -l --icons --group-directories-first \$argv; end" > /etc/fish/functions/ll.fish && \
    echo "function la; eza -la --icons --group-directories-first \$argv; end" > /etc/fish/functions/la.fish && \
    \
    # 4. Set static global greeting \
    echo "set -g fish_greeting '✨ Welcome to the DevContainer! 🚀'" > /etc/fish/conf.d/greeting.fish

# Setup non-root user (Standard UID 1000)
ARG USERNAME=vscode
RUN useradd -m -s /usr/bin/fish $USERNAME

# Switch to non-root user
USER $USERNAME
WORKDIR /home/$USERNAME

# Start fish shell by default
CMD ["fish"]
