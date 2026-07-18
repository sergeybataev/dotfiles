# --- startup timer: stamp as early as possible ---
zmodload zsh/datetime
zmodload zsh/stat
typeset -F __zshrc_start=$EPOCHREALTIME

# __zshrc_stale <file> <max_age_hours> — true (0) if <file> is missing or its
# mtime is older than <max_age_hours>. Used to gate the once-a-day compinit
# rebuild and the kubectl-completion cache below. Deliberately NOT using
# zsh glob qualifiers like (#qN.mh+24) here — that syntax silently requires
# `setopt extendedglob` (unset in this file), so it was quietly always
# matching "stale" regardless of actual file age. zstat's mtime is exact
# and doesn't depend on glob options.
__zshrc_stale() {
  local f="$1" max_hours="$2" mtime
  [[ -f "$f" ]] || return 0
  mtime=$(zstat +mtime "$f" 2>/dev/null) || return 0
  (( EPOCHSECONDS - mtime > max_hours * 3600 ))
}

# __zshrc_source_cached <cache-file> <binary-path-or-empty> <generate-cmd...>
# Stale-while-revalidate caching for `eval "$(X init zsh)"`-style one-time
# shell-function bootstraps that measured >15ms (mise activate, starship
# init, atuin init, kubectl completion): their output is a deterministic
# function of the tool's version, so caching is safe as long as it's
# invalidated on binary upgrade.
#
#   - cache missing/empty:        generate INLINE (first run — nothing to
#                                  fall back to), then source.
#   - <binary> newer than cache:  generate INLINE (binary upgrade is rare
#                                  and correctness matters more than a few
#                                  ms here), then source.
#   - cache exists but >24h old:  source the EXISTING (stale) cache
#                                  immediately for a fast prompt, then
#                                  regenerate in a fully silent, disowned
#                                  background job — atomic tmp-file + mv so
#                                  concurrent shells never see a half-written
#                                  cache, `&!` so no job-control output ever
#                                  reaches this shell's prompt.
#   - cache exists and fresh:     just source it.
__zshrc_source_cached() {
  local cache="$1" bin="$2"
  shift 2
  if [[ ! -s "$cache" ]]; then
    mkdir -p "${cache:h}"
    "$@" >| "$cache" 2>/dev/null
  elif [[ -n "$bin" ]] && [[ "$bin" -nt "$cache" ]]; then
    mkdir -p "${cache:h}"
    "$@" >| "$cache" 2>/dev/null
  elif __zshrc_stale "$cache" 24; then
    [[ -n "$ZSHRC_DEBUG" ]] && print -u2 "(${cache:t}: refreshing in background)"
    ( "$@" >| "${cache}.tmp.$$" 2>/dev/null && mv -f "${cache}.tmp.$$" "$cache" ) &>/dev/null &!
  fi
  [[ -s "$cache" ]] && source "$cache"
}

# --- per-section debug timers, gated by ZSHRC_DEBUG=1 (see README) ---
# Zero overhead when unset: every call site is guarded by a cheap
# [[ -n $ZSHRC_DEBUG ]] before __zshrc_mark is even invoked, and
# __zshrc_mark itself re-checks and bails immediately.
if [[ -n "$ZSHRC_DEBUG" ]]; then
  typeset -F __zshrc_last=$__zshrc_start
  typeset -a __zshrc_mark_order
  typeset -A __zshrc_marks
fi
__zshrc_mark() {
  [[ -n "$ZSHRC_DEBUG" ]] || return
  local now=$EPOCHREALTIME
  __zshrc_marks[$1]=$(( (now - __zshrc_last) * 1000 ))
  __zshrc_mark_order+=("$1")
  __zshrc_last=$now
}

if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
fi
[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark nix

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

# Work-only settings (GOPRIVATE, WORK_ORG, WORK_GH_USER, WORK_LABEL, …) live in
# an untracked ~/.zsh/work.zsh — see zsh/work.zsh.example. Sourced here early so
# the identity/routing modules (ai.zsh, kube.zsh, zhelp.zsh) and the starship
# prompt can see the exported values.
[[ -f ~/.zsh/work.zsh ]] && source ~/.zsh/work.zsh

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

[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark "PATH/exports"

# mise (tool version manager) activation — cached (>15ms measured cost),
# regenerated when the mise binary is upgraded or the cache is >24h old.
__zshrc_source_cached "$HOME/.zsh/cache/mise_activate.zsh" "$commands[mise]" mise activate zsh
[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark "mise activate"

# direnv hook (only if installed)
(( $+commands[direnv] )) && eval "$(direnv hook zsh)"
[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark "direnv hook"

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

# compinit — stale-while-revalidate, same idea as __zshrc_source_cached:
#   - dump missing (true first run): full rebuild INLINE — nothing to fall
#     back to, so this is the one case that has to block. Announce it
#     unconditionally (not just under ZSHRC_DEBUG) since it's the only
#     inline-slow path left and worth explaining if seen.
#   - dump exists (even if >24h stale): always take the fast `-C` path
#     inline (skip the security check + re-parse) so this shell's startup
#     is never blocked by a dump rebuild.
#   - dump exists but >24h old: after the fast `-C` load above, kick off a
#     full rebuild in a silent, disowned background `zsh -c` so *future*
#     shells get a fresh dump — this shell already started with `-C`.
autoload -Uz compinit
_zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
if [[ ! -s "$_zcompdump" ]]; then
  print -u2 "(rebuilding completion cache — first shell of the day is slower)"
  compinit -d "$_zcompdump"
else
  compinit -C -d "$_zcompdump"
  if __zshrc_stale "$_zcompdump" 24; then
    [[ -n "$ZSHRC_DEBUG" ]] && print -u2 "(completion dump refreshing in background)"
    ( zsh -c "autoload -Uz compinit; compinit -d '$_zcompdump'" ) &>/dev/null &!
  fi
fi
unset _zcompdump
[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark compinit

# kubectl completion — cached to disk via the same stale-while-revalidate
# helper as mise/atuin/starship below. `kubectl completion zsh` forking
# kubectl on every shell was one of the biggest measured startup
# regressions before this cache existed.
if (( $+commands[kubectl] )); then
  __zshrc_source_cached "$HOME/.zsh/cache/kubectl_completion.zsh" "$commands[kubectl]" kubectl completion zsh
fi
compdef k=kubectl
[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark "kubectl completion"

# fzf-tab — replaces the default tab-completion menu with an fzf picker.
# Must load AFTER compinit and BEFORE autosuggestions/syntax-highlighting
# per its README.
if [[ -f "$HOME/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh" ]]; then
  source "$HOME/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh"
fi
[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark fzf-tab

# ai.zsh — opt-in AI helpers with per-cwd assistant routing
[[ -f ~/.zsh/ai.zsh ]] && source ~/.zsh/ai.zsh
[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark ai.zsh

# kube.zsh — per-directory KUBECONFIG binding (work ↔ homelab)
[[ -f ~/.zsh/kube.zsh ]] && source ~/.zsh/kube.zsh
[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark kube.zsh

# zhelp.zsh — `zhelp`/`zh` cheat-sheet command for this setup
[[ -f ~/.zsh/zhelp.zsh ]] && source ~/.zsh/zhelp.zsh
[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark zhelp

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
[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark autosuggestions

# fast-syntax-highlighting — must load LAST among the highlighting/completion
# plugins (after autosuggestions), per upstream docs.
if [[ -f "$HOME/.zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]]; then
  source "$HOME/.zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
fi
[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark fast-syntax-highlighting

# zsh-history-substring-search — load (and bind) after fast-syntax-highlighting,
# since its bindings should come after highlighting is wired up.
if [[ -f "$HOME/.zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
  source "$HOME/.zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh"
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
  [[ -n "${terminfo[kcuu1]}" ]] && bindkey "${terminfo[kcuu1]}" history-substring-search-up
  [[ -n "${terminfo[kcud1]}" ]] && bindkey "${terminfo[kcud1]}" history-substring-search-down
fi
[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark substring-search

# fzf shell integration (completion + Ctrl-T/Alt-C widgets only —
# atuin takes ownership of Ctrl-R since it's initialized after this)
if (( $+commands[fzf] )); then
  source <(fzf --zsh)
fi
[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark fzf

# atuin — Ctrl-R global fuzzy history search; up-arrow is atuin too, scoped
# to the current directory (filter_mode_shell_up_key_binding in
# ~/.config/atuin/config.toml). Cached (>15ms measured cost), same
# invalidation as mise above.
if (( $+commands[atuin] )); then
  __zshrc_source_cached "$HOME/.zsh/cache/atuin_init.zsh" "$commands[atuin]" atuin init zsh
fi
[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark atuin

# zoxide
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi
[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark zoxide

# starship prompt. Cached (>15ms measured cost), same invalidation as mise above.
__zshrc_source_cached "$HOME/.zsh/cache/starship_init.zsh" "$commands[starship]" starship init zsh
[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark starship

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
[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark "history opts"

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
[[ -n "$ZSHRC_DEBUG" ]] && __zshrc_mark gcloud

# --- startup timer: report elapsed time at the first prompt, then remove itself ---
__zshrc_report_startup() {
  local -F elapsed=$(( EPOCHREALTIME - __zshrc_start ))
  printf '⚡ zsh ready in %.0f ms\n' $(( elapsed * 1000 ))

  if [[ -n "$ZSHRC_DEBUG" ]]; then
    echo "--- ZSHRC_DEBUG: per-section timings (sorted, slowest first) ---"
    local name
    for name in "${__zshrc_mark_order[@]}"; do
      printf '%7.1f ms  %s\n' "${__zshrc_marks[$name]}" "$name"
    done | sort -rn
    echo "-----------------------------------------------------------------"
  fi

  # one-shot: unhook and clean up
  add-zsh-hook -d precmd __zshrc_report_startup
  unfunction __zshrc_report_startup
  unset __zshrc_start __zshrc_last __zshrc_mark_order __zshrc_marks
  unfunction __zshrc_mark
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd __zshrc_report_startup
