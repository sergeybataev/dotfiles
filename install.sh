#!/usr/bin/env bash
#
# install.sh — idempotent bootstrap for a fresh macOS/Linux box.
#
# What it does:
#   1. Installs mise (tool version manager) if missing.
#   2. Installs the tools pinned in mise/config.toml (`mise use -g`).
#   3. Clones zsh-autosuggestions into ~/.zsh/plugins/.
#   4. Symlinks (or copies, with a timestamped backup of anything already
#      there) zshrc / starship.toml / ai.zsh into place.
#
# Safe to re-run: every step checks for existing state before acting.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

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

# --- 3. zsh-autosuggestions --------------------------------------------------

PLUGIN_DIR="$HOME/.zsh/plugins/zsh-autosuggestions"
if [ -d "$PLUGIN_DIR" ]; then
  log "zsh-autosuggestions already present at $PLUGIN_DIR"
else
  log "cloning zsh-autosuggestions"
  mkdir -p "$HOME/.zsh/plugins"
  git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$PLUGIN_DIR"
fi

# --- 4. symlink dotfiles into place -----------------------------------------

mkdir -p ~/.config ~/.zsh

backup_and_link "$DOTFILES_DIR/zsh/.zshrc"        "$HOME/.zshrc"
backup_and_link "$DOTFILES_DIR/zsh/ai.zsh"        "$HOME/.zsh/ai.zsh"
backup_and_link "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"

log "done. Start a new shell (or 'exec zsh') to pick everything up."
log "If you need work-only settings (e.g. GOPRIVATE), copy zsh/work.zsh.example to ~/.zsh/work.zsh, edit it, and source it from a local (untracked) block in ~/.zshrc."
