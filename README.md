# dotfiles

My shell setup: zsh + [mise](https://mise.jdx.dev/) (tool versions) + [starship](https://starship.rs/) (prompt) + [atuin](https://atuin.sh/) (history) + [zoxide](https://github.com/ajeetdsouza/zoxide) (cd) + [fzf](https://github.com/junegunn/fzf) + [fzf-tab](https://github.com/Aloxaf/fzf-tab) + zsh-autosuggestions + [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) + [zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search), plus a small opt-in `ai.zsh` that routes one-shot prompts to whichever AI CLI (`claude`, `codex`, `agy`) is installed and appropriate for the current directory.

## Install

```sh
git clone https://github.com/sergeybataev/dotfiles.git && ~/dotfiles/install.sh
```

`install.sh` is idempotent: installs mise if missing, installs the pinned tool versions, clones the zsh plugins (autosuggestions, fzf-tab, fast-syntax-highlighting, history-substring-search), and symlinks `.zshrc` / `starship.toml` / `ai.zsh` into place (backing up anything already there).

Work-only settings (e.g. `GOPRIVATE`) are kept out of the tracked `.zshrc` — see `zsh/work.zsh.example` (shell-level) and `mise/org-example.mise.toml` (mise project-scoped equivalent — drop it at the root of a directory tree and `mise trust` it).

`mise/config.toml` also pins `bat`, `difftastic`, `ripgrep` at user scope (alongside starship/fzf/zoxide); these can coexist with Nix-provided copies of the same tools since mise shims win on `$PATH`.

## Keybinding cheat-sheet

| Key | Action |
|---|---|
| `→` / `End` | Accept the full autosuggestion (ghost text) |
| `Alt-F` | Accept one word of the autosuggestion |
| `↑` / `↓` | History substring search (matches what's typed so far, not just prefix) |
| `Ctrl-R` | Atuin fuzzy history search |
| `Ctrl-T` | fzf file finder |
| `Tab` (on a completion) | fzf-tab picker instead of the default completion menu |
| `Ctrl-X a` | Cycle active AI assistant (auto → claude → codex → agy → auto) |
| `Ctrl-X Ctrl-A` | Ask the active AI assistant to fix/complete the current command line |

## AI helpers (`ai.zsh`)

- `ai <question>` — one-shot prompt to the active assistant.
- `aix <task>` — same, but asks for a shell command only (prints it, doesn't run it).
- `wtf` — explains why the last command failed. Includes actual output when it can: if run inside tmux, the last ~50 lines of the pane's scrollback are attached (labeled as possibly containing unrelated lines); otherwise it prints a tip to use `wtf -r`. `wtf -r` re-runs the last command with stdout+stderr captured to a temp file and includes that output — it warns first and requires an explicit `y` confirmation (default No), since re-running a destructive command is exactly the kind of thing you don't want to do by accident.
- Routing: `$AI_ASSISTANT` override > `claude` under any `*/ExampleOrg/*` path (or your own org, edit to taste) > `codex` elsewhere. Falls back to whatever's actually installed.
- **Strict work-dir guard**: under a work path, `codex`/`agy` are refused outright (even via an explicit `$AI_ASSISTANT` override) and `claude` is used instead, with a one-line refusal printed to stderr. `Ctrl-X a` also drops `codex`/`agy` from the cycle while inside a work directory.
- The starship prompt shows the active assistant (yellow = manual override, dim = auto).

## Prompt segments (starship)

- `⚙ <dirname>` — shown when the current directory (or an ancestor, up to `$HOME`) has its own `mise.toml` / `.mise.toml` / `.tool-versions`; prints that ancestor's directory name. Nothing is shown otherwise (kept deliberately quiet rather than a fallback label). Computed with a pure-shell walk-up — no `mise` process spawned per prompt.
- `🤖 <assistant>` — see AI helpers above.

## Shell performance notes

- `compinit` only does a full rebuild once every 24h (checked via `.zcompdump` mtime); the rest of the time it uses `compinit -C` (skips the security audit + re-parse).
- gcloud's `completion.zsh.inc` is lazy-loaded behind a `gcloud()` stub that sources it (and unfunctions itself) on first real invocation, instead of paying that cost on every shell startup.
