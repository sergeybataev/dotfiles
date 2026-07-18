#!/usr/bin/env bash
#
# install.sh — idempotent bootstrap for a fresh macOS/Linux box.
#
# What it does:
#   1. Installs mise (tool version manager) if missing.
#   2. Installs the tools pinned in mise/config.toml (`mise use -g`).
#   3. Clones zsh-autosuggestions, fzf-tab, fast-syntax-highlighting, and
#      zsh-history-substring-search into ~/.zsh/plugins/.
#   4. Symlinks the shell configs into place (timestamped backup of anything
#      already there). Fully symlinked: zhelp.zsh / kube.zsh / bin/ws /
#      atuin / ghostty. Deferred (linked only if absent — see ticket 13):
#      .zshrc / ai.zsh / starship.toml.
#   5. Resolves private work values via the dotfiles-private overlay repo,
#      symlinking its zsh/work.zsh -> ~/.zsh/work.zsh (falls back to the
#      example template when the overlay is unavailable).
#   6. Installs the global git identity-guard hooks.
#   7. Generates a standalone homelab kubeconfig if the context is available.
#
# Safe to re-run: every step checks for existing state before acting.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Work-only values (HOMELAB_CTX, etc.) come from the untracked ~/.zsh/work.zsh
# if present — see zsh/work.zsh.example. Anything unset falls back to a
# neutral default below.
# shellcheck disable=SC1091
[ -f "$HOME/.zsh/work.zsh" ] && . "$HOME/.zsh/work.zsh"
: "${HOMELAB_CTX:=admin@homelab}"

log() { printf '==> %s\n' "$1"; }

backup_and_link() {
  # backup_and_link <source-in-repo> <target-path>
  local src="$1"
  local dst="$2"

  if [ -L "$dst" ]; then
    # Already a symlink — check if it points at our file.
    if [ "$(readlink "$dst")" = "$src" ]; then
      log "already linked: $dst"
      return 0
    fi
    log "backing up existing symlink: $dst -> ${dst}.backup.${TIMESTAMP}"
    mv "$dst" "${dst}.backup.${TIMESTAMP}"
  elif [ -e "$dst" ]; then
    log "backing up existing file: $dst -> ${dst}.backup.${TIMESTAMP}"
    mv "$dst" "${dst}.backup.${TIMESTAMP}"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  log "linked: $dst -> $src"
}

link_if_absent() {
  # link_if_absent <source-in-repo> <target-path>
  # Symlink ONLY when nothing exists at the target yet (fresh machine). If a
  # real file/symlink is already there, leave it untouched. Used for files that
  # are the eventual all-symlink target but whose EXISTING local copies still
  # carry un-migrated machine-specific content (ticket 13): converting those is
  # deferred until their private bits move into ~/.zsh/work.zsh, so we never
  # clobber a populated machine — but a fresh box still gets a working config.
  local src="$1" dst="$2"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    log "keeping existing (deferred, not converting): $dst"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  log "linked (fresh): $dst -> $src"
}

# --- 1. mise ---------------------------------------------------------------

if ! command -v mise >/dev/null 2>&1; then
  log "mise not found, installing via official installer"
  curl -fsSL https://mise.run | sh
  # mise installs to ~/.local/bin by default
  export PATH="$HOME/.local/bin:$PATH"
else
  log "mise already installed: $(command -v mise)"
fi

if ! command -v mise >/dev/null 2>&1; then
  echo "ERROR: mise still not on PATH after install attempt. Add ~/.local/bin to PATH and re-run." >&2
  exit 1
fi

# --- 2. tools from mise/config.toml -----------------------------------------

log "installing tools pinned in mise/config.toml"
mkdir -p ~/.config/mise
cp -n "$DOTFILES_DIR/mise/config.toml" ~/.config/mise/config.toml 2>/dev/null || true
(cd ~/.config/mise && mise install)
mise use -g -y 2>/dev/null || true

# --- 3. zsh plugins ---------------------------------------------------------

clone_plugin() {
  # clone_plugin <name> <repo-url>
  local name="$1" url="$2"
  local dir="$HOME/.zsh/plugins/$name"
  if [ -d "$dir" ]; then
    log "$name already present at $dir"
  else
    log "cloning $name"
    mkdir -p "$HOME/.zsh/plugins"
    git clone --depth 1 "$url" "$dir"
  fi
}

clone_plugin zsh-autosuggestions          https://github.com/zsh-users/zsh-autosuggestions
clone_plugin fzf-tab                      https://github.com/Aloxaf/fzf-tab
clone_plugin fast-syntax-highlighting     https://github.com/zdharma-continuum/fast-syntax-highlighting
clone_plugin zsh-history-substring-search https://github.com/zsh-users/zsh-history-substring-search

# --- 4. symlink dotfiles into place -----------------------------------------

mkdir -p ~/.config ~/.zsh

# Deferred conversions (ticket 13): these three are the all-symlink target, but
# existing local copies may still hold un-migrated machine-specific content, so
# link them only on a fresh machine and never clobber an existing copy. Convert
# them for real once their private bits live in ~/.zsh/work.zsh.
link_if_absent  "$DOTFILES_DIR/zsh/.zshrc"        "$HOME/.zshrc"
link_if_absent  "$DOTFILES_DIR/zsh/ai.zsh"        "$HOME/.zsh/ai.zsh"
link_if_absent  "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"

# Fully symlinked (single source of truth in the repo):
backup_and_link "$DOTFILES_DIR/zsh/zhelp.zsh"     "$HOME/.zsh/zhelp.zsh"
backup_and_link "$DOTFILES_DIR/zsh/kube.zsh"      "$HOME/.zsh/kube.zsh"
backup_and_link "$DOTFILES_DIR/bin/ws"            "$HOME/.local/bin/ws"
backup_and_link "$DOTFILES_DIR/atuin/config.toml" "$HOME/.config/atuin/config.toml"

# ghostty: both files go to the XDG path so the bare `config-file = theme.conf`
# relative include resolves next to the including file. The Application
# Support copy is backed up away below — ghostty reads both locations and the
# docs are ambiguous about which wins, so only one may exist.
backup_and_link "$DOTFILES_DIR/ghostty/config"     "$HOME/.config/ghostty/config"
backup_and_link "$DOTFILES_DIR/ghostty/theme.conf" "$HOME/.config/ghostty/theme.conf"

GHOSTTY_APPSUPPORT="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
if [ -f "$GHOSTTY_APPSUPPORT" ] && [ ! -L "$GHOSTTY_APPSUPPORT" ]; then
  log "backing up Application Support ghostty config -> ${GHOSTTY_APPSUPPORT}.backup.${TIMESTAMP}"
  mv "$GHOSTTY_APPSUPPORT" "${GHOSTTY_APPSUPPORT}.backup.${TIMESTAMP}"
fi

# --- 5. private overlay (real work values) ----------------------------------
# The tracked files reference WORK_ORG / HOMELAB* / GOPRIVATE etc.; the real
# values live ONLY in an untracked ~/.zsh/work.zsh. That file is provided by a
# PRIVATE overlay repo (dotfiles-private) so nothing employer-specific ever
# lands in this public repo. Resolution:
#   - overlay present  -> pull, then symlink its zsh/work.zsh -> ~/.zsh/work.zsh
#   - overlay clonable -> clone it, then symlink as above
#   - overlay missing  -> fall back to the example template ONLY if there is no
#                         ~/.zsh/work.zsh yet (never overwrite a real one)
PRIVATE_REPO="git@github-personal:sergeybataev/dotfiles-private.git"
PRIVATE_DIR="$HOME/.dotfiles-private"

if [ -d "$PRIVATE_DIR/.git" ]; then
  if git -C "$PRIVATE_DIR" pull --ff-only -q 2>/dev/null; then
    log "private overlay: updated ($PRIVATE_DIR)"
  else
    log "private overlay: present but pull skipped (offline / no fast-forward)"
  fi
elif git clone -q "$PRIVATE_REPO" "$PRIVATE_DIR" 2>/dev/null; then
  log "private overlay: cloned $PRIVATE_REPO"
else
  log "private overlay: unavailable (no auth or repo missing)"
fi

if [ -f "$PRIVATE_DIR/zsh/work.zsh" ]; then
  backup_and_link "$PRIVATE_DIR/zsh/work.zsh" "$HOME/.zsh/work.zsh"
elif [ ! -f "$HOME/.zsh/work.zsh" ]; then
  cp "$DOTFILES_DIR/zsh/work.zsh.example" "$HOME/.zsh/work.zsh"
  log "WARNING: no private overlay — seeded ~/.zsh/work.zsh from the example."
  log "         edit ~/.zsh/work.zsh to fill in your values (or leave blank for a personal-only box)."
else
  log "private overlay absent; keeping existing ~/.zsh/work.zsh untouched"
fi

# Re-source work.zsh now that it is resolved, so later steps (e.g. the homelab
# kubeconfig below) see the real HOMELAB_CTX.
# shellcheck disable=SC1091
[ -f "$HOME/.zsh/work.zsh" ] && . "$HOME/.zsh/work.zsh"
: "${HOMELAB_CTX:=admin@homelab}"

# --- 6. global git identity-guard hooks --------------------------------------
# pre-commit/pre-push assert the resolved user.email matches the tree
# (work vs personal); unknown trees stop and ask for an explicit identity. The
# hooks chain to each repo's own .git/hooks/* so nothing local is shadowed by
# the global core.hooksPath.

backup_and_link "$DOTFILES_DIR/git-hooks" "$HOME/.config/git/hooks"
if command -v git >/dev/null 2>&1; then
  git config --global core.hooksPath "$HOME/.config/git/hooks"
  log "core.hooksPath -> ~/.config/git/hooks"
fi

# --- 7. standalone homelab kubeconfig ---------------------------------------
# kube.zsh points non-work shells at ~/.kube/homelab.yaml. Generate it once
# from the merged ~/.kube/config if the homelab context ($HOMELAB_CTX) is
# available. --minify keeps only that context, so enterprise creds never leak
# into it.

if [ ! -f "$HOME/.kube/homelab.yaml" ]; then
  if command -v kubectl >/dev/null 2>&1 \
     && kubectl config get-contexts "$HOMELAB_CTX" >/dev/null 2>&1; then
    log "generating standalone homelab kubeconfig: ~/.kube/homelab.yaml"
    mkdir -p "$HOME/.kube"
    kubectl config view --minify --flatten --context="$HOMELAB_CTX" > "$HOME/.kube/homelab.yaml"
    chmod 600 "$HOME/.kube/homelab.yaml"
  else
    log "skipping ~/.kube/homelab.yaml (kubectl or $HOMELAB_CTX context not available)"
  fi
else
  log "~/.kube/homelab.yaml already exists"
fi

log "done. Start a new shell (or 'exec zsh') to pick everything up."
log "If you need work-only settings (GOPRIVATE, WORK_ORG, …), copy zsh/work.zsh.example to ~/.zsh/work.zsh and edit it; zsh/.zshrc sources it automatically."
