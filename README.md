# dotfiles

My shell setup: zsh + [mise](https://mise.jdx.dev/) (tool versions) + [starship](https://starship.rs/) (prompt) + [atuin](https://atuin.sh/) (history) + [zoxide](https://github.com/ajeetdsouza/zoxide) (cd) + [fzf](https://github.com/junegunn/fzf) + zsh-autosuggestions, plus a small opt-in `ai.zsh` that routes one-shot prompts to whichever AI CLI (`claude`, `codex`, `agy`) is installed and appropriate for the current directory.

## Install

```sh
git clone https://github.com/sergeybataev/dotfiles.git && ~/dotfiles/install.sh
```

`install.sh` is idempotent: installs mise if missing, installs the pinned tool versions, clones zsh-autosuggestions, and symlinks `.zshrc` / `starship.toml` / `ai.zsh` into place (backing up anything already there).

Work-only settings (e.g. `GOPRIVATE`) are kept out of the tracked `.zshrc` — see `zsh/work.zsh.example`.

## Keybinding cheat-sheet

| Key | Action |
|---|---|
| `→` / `End` | Accept the full autosuggestion (ghost text) |
| `Alt-F` | Accept one word of the autosuggestion |
| `Ctrl-R` | Atuin fuzzy history search |
| `Ctrl-T` | fzf file finder |
| `Ctrl-X a` | Cycle active AI assistant (auto → claude → codex → agy → auto) |
| `Ctrl-X Ctrl-A` | Ask the active AI assistant to fix/complete the current command line |

## AI helpers (`ai.zsh`)

- `ai <question>` — one-shot prompt to the active assistant.
- `aix <task>` — same, but asks for a shell command only (prints it, doesn't run it).
- `wtf` — explains why the last command failed.
- Routing: `$AI_ASSISTANT` override > `claude` under any `*/ExampleOrg/*` path (or your own org, edit to taste) > `codex` elsewhere. Falls back to whatever's actually installed.
- The starship prompt shows the active assistant (yellow = manual override, dim = auto).
