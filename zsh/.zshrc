if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
fi

export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Define variables for directories
export PATH=$HOME/.local/share/bin:$PATH

# Remove history data we don't want to see
export HISTIGNORE="pwd:ls:cd"

# Ripgrep alias
# alias search=rg -p --glob '!node_modules/*'  $@

# Emacs is my editor
# export ALTERNATE_EDITOR=""
# export EDITOR="emacsclient -t"
# export VISUAL="emacsclient -c -a emacs"

#e() {
#    emacsclient -t "$@"
#}

# nix shortcuts
shell() {
    nix-shell '<nixpkgs>' -A "$1"
}

bindkey "^[[3~" delete-char
# compinit is run once later (after fpath is fully built) — see below.

# Use difftastic, syntax-aware diffing (guarded: no error if difft is absent)
(( $+commands[difft] )) && alias diff=difft

# Always color ls, portable across GNU (Nix/coreutils) and BSD (macOS) ls.
if ls --color=auto /dev/null >/dev/null 2>&1; then
  alias ls='ls --color=auto'   # GNU coreutils
else
  export CLICOLOR=1            # BSD/macOS ls honors this
  alias ls='ls -G'
fi

# ----- My -----

# Pretty cat via bat, resolved through PATH (not a hardcoded Nix path) so it
# survives a future Nix -> mise migration. `cat` itself stays the real binary.
if (( $+commands[bat] )); then
  alias catt='bat'
elif (( $+commands[batcat] )); then   # Debian/Ubuntu package name
  alias catt='batcat'
fi

## Plugins
# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# NOTE: this oh-my-zsh-style plugins=(...) was dead code (oh-my-zsh is never
# sourced; `plugins` is reassigned lower down for the p10k loader). Removed.

# Aliases

## Terminal

### .zshrc
alias zshv="vim ~/.zshrc"
alias zshs="source ~/.zshrc"

### ssh
# alias server="ssh fileserver -t tmux attach"

#### tmux
alias tm="tmux ls 2>/dev/null | awk 'END{if(NR==1) print $1}' | sed 's/://g' | read -r tmux_session && tmux attach -t \"$tmux_session\" || (tmux ls || tmux new -s default; echo -n \"Enter session name: \"; read tmux_session; tmux attach -t \"$tmux_session\" 2>/dev/null || tmux new -s \"$tmux_session\")"

#### fim mouse after ssh dropped
alias fixm="printf '\e[?1000l'"

#### nix config (adjust flake target/host to your own machine)
# alias nr="nix run .#build-switch"
# alias drn="sudo darwin-rebuild switch --flake ~/.config/nix#<your-hostname>"
# alias drv="vim ~/.config/nix/flake.nix"

## Kubernetes
### K8s
alias k="kubectl"

kerr() {
  kubectl get pods -A -o wide --no-headers | grep -v " Running " | awk '{printf "%-15s %-60s %-6s %-20s %-10s %-10s %-15s %-15s %-20s %-15s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10}'
}

### Krew
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

#### Colima start
# alias cstart="colima start --profile default --activate --arch aarch64 --cpu 10 --disk 48 --memory 16 --mount $\{HOME\}:w --mount-inotify --ssh-agent --vm-type vz --vz-rosetta --verbose --network-address"


# Exports

## Golang
export GO111MODULE="on"
export GOROOT=/usr/local/go
export GOPATH=~/go

# Work-only settings (GOPRIVATE, etc.) live in zsh/work.zsh.example — copy that
# to ~/.zsh/work.zsh and source it separately if you need it.

export PATH=$HOME/bin:/usr/local/bin:$HOME/go/bin:$HOME/.local/bin:/usr/local/go/bin:$PATH

# export COLIMA_VM="default"
# export COLIMA_VM_SOCKET="$\{HOME\}/.colima/$\{COLIMA_VM\}/docker.sock"
# export DOCKER_HOST="unix://$\{COLIMA_VM_SOCKET\}"


export PATH="/opt/homebrew/opt/libxml2/bin:$PATH"
export PKG_CONFIG_PATH="/opt/homebrew/opt/libxml2/lib/pkgconfig"

export PATH=$HOME/.bin:$PATH

# Added by LM Studio CLI (lms)
if [[ -d "$HOME/.lmstudio/bin" ]]; then
  export PATH="$PATH:$HOME/.lmstudio/bin"
fi
# End of LM Studio CLI section

# mise (tool version manager) activation
eval "$(mise activate zsh)"

# direnv hook (only if installed)
(( $+commands[direnv] )) && eval "$(direnv hook zsh)"

typeset -U path cdpath fpath manpath
cdpath+=(~/.local/share/src)

for profile in ${(z)NIX_PROFILES}; do
  fpath+=($profile/share/zsh/site-functions $profile/share/zsh/$ZSH_VERSION/functions $profile/share/zsh/vendor-completions)
done

# HELPDIR: point at the zsh help dir shipped by whichever zsh you're running,
# if it exists (guarded — path varies by install method / OS).
if [[ -d "/usr/local/share/zsh/$ZSH_VERSION/help" ]]; then
  HELPDIR="/usr/local/share/zsh/$ZSH_VERSION/help"
elif [[ -d "/usr/share/zsh/$ZSH_VERSION/help" ]]; then
  HELPDIR="/usr/share/zsh/$ZSH_VERSION/help"
fi

# compinit — full rebuild at most once/day, cached (-C, skip the security
# check + re-parse) the rest of the time. Standard zsh perf pattern.
autoload -Uz compinit
_zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
if [[ -n "$_zcompdump"(#qN.mh+24) ]]; then
  compinit -d "$_zcompdump"
else
  compinit -C -d "$_zcompdump"
fi
unset _zcompdump

# kubectl completion (guarded — only if kubectl is on PATH)
(( $+commands[kubectl] )) && source <(kubectl completion zsh)
compdef k=kubectl

# fzf-tab — replaces the default tab-completion menu with an fzf picker.
# Must load AFTER compinit and BEFORE autosuggestions/syntax-highlighting
# per its README.
if [[ -f "$HOME/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh" ]]; then
  source "$HOME/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh"
fi

# ai.zsh — opt-in AI helpers with per-cwd assistant routing
[[ -f ~/.zsh/ai.zsh ]] && source ~/.zsh/ai.zsh

# zsh-autosuggestions
if [[ -f "$HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS+=(forward-word)
  # Right arrow / End: accept the whole suggestion
  bindkey '^[[C' autosuggest-accept
  bindkey '^[[F' autosuggest-accept
  bindkey '^E'   autosuggest-accept
  # Alt-F and Ctrl-RightArrow: accept one word (via forward-word partial-accept)
  bindkey '^[f'     forward-word
  bindkey '^[[1;5C' forward-word
fi

# fast-syntax-highlighting — must load LAST among the highlighting/completion
# plugins (after autosuggestions), per upstream docs.
if [[ -f "$HOME/.zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]]; then
  source "$HOME/.zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
fi

# zsh-history-substring-search — load (and bind) after fast-syntax-highlighting,
# since its bindings should come after highlighting is wired up.
if [[ -f "$HOME/.zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
  source "$HOME/.zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh"
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
  [[ -n "${terminfo[kcuu1]}" ]] && bindkey "${terminfo[kcuu1]}" history-substring-search-up
  [[ -n "${terminfo[kcud1]}" ]] && bindkey "${terminfo[kcud1]}" history-substring-search-down
fi

# fzf shell integration (completion + Ctrl-T/Alt-C widgets only —
# atuin takes ownership of Ctrl-R since it's initialized after this)
if (( $+commands[fzf] )); then
  source <(fzf --zsh)
fi

# atuin — Ctrl-R fuzzy history search; keep the default up-arrow prefix search
if (( $+commands[atuin] )); then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

# zoxide
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

# starship prompt
eval "$(starship init zsh)"

# History options should be set in .zshrc and after oh-my-zsh sourcing.
# See https://github.com/nix-community/home-manager/issues/177.
HISTSIZE="999999999"
SAVEHIST="999999999"

HISTFILE="$HOME/.zsh_history"
mkdir -p "$(dirname "$HISTFILE")"

setopt HIST_FCNTL_LOCK

# Enabled history options
enabled_opts=(
  HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY
)
for opt in "${enabled_opts[@]}"; do
  setopt "$opt"
done
unset opt enabled_opts

# Disabled history options
disabled_opts=(
  APPEND_HISTORY EXTENDED_HISTORY HIST_EXPIRE_DUPS_FIRST HIST_FIND_NO_DUPS
  HIST_IGNORE_ALL_DUPS HIST_SAVE_NO_DUPS autocd
)
for opt in "${disabled_opts[@]}"; do
  unsetopt "$opt"
done
unset opt disabled_opts

# pip 3 binaries (adjust python version to match yours)
# export PATH="$HOME/Library/Python/3.14/bin:$PATH"

# Extra PATH entries for optional tools — uncomment / adjust as needed:
# export PATH="$HOME/.opencode/bin:$PATH"
# export PATH="$HOME/.antigravity/antigravity/bin:$PATH"          # Antigravity IDE/CLI
# export PATH="$HOME/.antigravity-ide/antigravity-ide/bin:$PATH"  # Antigravity IDE

# Google Cloud SDK — only if installed at this path (adjust to your own location).
# if [ -f "$HOME/path/to/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/path/to/google-cloud-sdk/path.zsh.inc"; fi
# export GOOGLE_CLOUD_PROJECT="your-project-id"
#
# gcloud completion — lazy-loaded, since completion.zsh.inc is slow to source
# and most shells never call gcloud. Defer it to first invocation:
# _GCLOUD_COMPLETION_INC="$HOME/path/to/google-cloud-sdk/completion.zsh.inc"
# if [[ -f "$_GCLOUD_COMPLETION_INC" ]]; then
#   gcloud() {
#     unfunction gcloud
#     source "$_GCLOUD_COMPLETION_INC"
#     gcloud "$@"
#   }
# fi
# unset _GCLOUD_COMPLETION_INC
