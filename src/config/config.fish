# Disable the default greeting
set -g fish_greeting ''

# Starship prompt — only for interactive sessions. The guard avoids breaking
# non-TTY launches (e.g. some IDEs spawn fish before opening the terminal).
if status is-interactive
    starship init fish | source
end

# eza aliases
alias ls='eza --icons --group-directories-first'
alias ll='eza -lh --icons --group-directories-first'
alias la='eza -la --icons --group-directories-first'
