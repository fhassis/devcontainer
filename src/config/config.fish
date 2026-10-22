# Mirrors the workstation's ~/.config/fish/conf.d (aliases, modern, starship, fnm).

# Disable the default greeting
set -g fish_greeting ''

# Everything below is for interactive sessions only. The guard avoids breaking
# non-TTY launches (e.g. some IDEs spawn fish before opening the terminal).
status is-interactive; or return

starship init fish | source

# Switch node to the project's .node-version / .nvmrc on cd.
fnm env --use-on-cd --shell fish | source

# ---- aliases ----
alias ls="eza -l --icons"
alias la="eza -la --icons"

# bat (Debian ships it as batcat); $bat is also used below
if command -q batcat; and not command -q bat
    alias bat batcat
end
set -g bat (command -s bat batcat)[1]
alias cat "$bat --paging=never"

# ---- modern ----
set -gx MANPAGER "sh -c 'col -bx | $bat -l man -p'"

# zoxide: z <dir>, zi (interactive)
zoxide init fish | source

# fzf: Ctrl+T files, Ctrl+R history, Alt+C cd
fzf --fish | source
set -gx FZF_DEFAULT_OPTS '--height=60% --layout=reverse --border --info=inline'
set -gx FZF_CTRL_T_OPTS "--preview '$bat --color=always --style=numbers --line-range=:300 {}' --bind 'ctrl-/:toggle-preview'"
set -gx FZF_ALT_C_OPTS "--preview 'eza --tree --level=2 --icons --color=always {}'"
set -gx FZF_CTRL_R_OPTS "--preview 'echo {}' --preview-window=down:3:wrap"

# zi picker also previews
set -gx _ZO_FZF_OPTS "$FZF_DEFAULT_OPTS --preview 'eza --tree --level=2 --icons --color=always {2..}'"

# f: fuzzy-open file in $EDITOR with bat preview
function f
    set -l file (fzf --preview "$bat --color=always --style=numbers --line-range=:300 {}")
    and $EDITOR $file
end
