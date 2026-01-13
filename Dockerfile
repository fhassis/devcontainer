FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install core tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    fish \
    eza \
    curl \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install Starship binary
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y

# Setup non-root user and essential directory tree
ARG USERNAME=vscode
RUN useradd -m -s /usr/bin/fish $USERNAME && \
    mkdir -p /home/$USERNAME/.config/fish /home/$USERNAME/.local/share/fish && \
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.config /home/$USERNAME/.local

# Switch to non-root user
USER $USERNAME
WORKDIR /home/$USERNAME

# Consolidated Config: Set Starship preset and write Fish config
RUN starship preset nerd-font-symbols -o ~/.config/starship.toml && \
    echo "starship init fish | source" > ~/.config/fish/config.fish && \
    echo "alias ls='eza --icons --group-directories-first'" >> ~/.config/fish/config.fish && \
    echo "alias ll='eza -lh --icons --grid-group-directories-first'" >> ~/.config/fish/config.fish

CMD ["fish"]
