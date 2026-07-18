#!/usr/bin/env bash
#
# install.sh — idempotent bootstrap for a fresh macOS/Linux box.
#
# What it does:
#   1. Installs mise (tool version manager) if missing.
#   2. Installs the tools pinned in mise/config.toml (`mise use -g`).
#   3. Clones zsh-autosuggestions, fzf-tab, fast-syntax-highlighting, and
#      zsh-history-substring-search into ~/.zsh/plugins/.
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

backup_and_link "$DOTFILES_DIR/zsh/.zshrc"        "$HOME/.zshrc"
backup_and_link "$DOTFILES_DIR/zsh/ai.zsh"        "$HOME/.zsh/ai.zsh"
backup_and_link "$DOTFILES_DIR/zsh/zhelp.zsh"     "$HOME/.zsh/zhelp.zsh"
backup_and_link "$DOTFILES_DIR/zsh/kube.zsh"      "$HOME/.zsh/kube.zsh"
backup_and_link "$DOTFILES_DIR/bin/ws"            "$HOME/.local/bin/ws"
backup_and_link "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
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

# --- 5. global git identity-guard hooks --------------------------------------
# pre-commit/pre-push assert the resolved user.email matches the tree
# (ExampleOrg vs sergeybataev); unknown trees stop and ask for an explicit
# identity. The hooks chain to each repo's own .git/hooks/* so nothing local
# is shadowed by the global core.hooksPath.

backup_and_link "$DOTFILES_DIR/git-hooks" "$HOME/.config/git/hooks"
if command -v git >/dev/null 2>&1; then
  git config --global core.hooksPath "$HOME/.config/git/hooks"
  log "core.hooksPath -> ~/.config/git/hooks"
fi

# --- 6. standalone homelab kubeconfig ---------------------------------------
# kube.zsh points non-ExampleOrg shells at ~/.kube/homelab.yaml. Generate it
# once from the merged ~/.kube/config if the homelab context is available.
# --minify keeps only that context, so enterprise creds never leak into it.

if [ ! -f "$HOME/.kube/homelab.yaml" ]; then
  if command -v kubectl >/dev/null 2>&1 \
     && kubectl config get-contexts admin@homelab >/dev/null 2>&1; then
    log "generating standalone homelab kubeconfig: ~/.kube/homelab.yaml"
    mkdir -p "$HOME/.kube"
    kubectl config view --minify --flatten --context=admin@homelab > "$HOME/.kube/homelab.yaml"
    chmod 600 "$HOME/.kube/homelab.yaml"
  else
    log "skipping ~/.kube/homelab.yaml (kubectl or admin@homelab context not available)"
  fi
else
  log "~/.kube/homelab.yaml already exists"
fi

log "done. Start a new shell (or 'exec zsh') to pick everything up."
log "If you need work-only settings (e.g. GOPRIVATE), copy zsh/work.zsh.example to ~/.zsh/work.zsh, edit it, and source it from a local (untracked) block in ~/.zshrc."
