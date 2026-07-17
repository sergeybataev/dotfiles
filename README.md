# dotfiles

My shell setup: zsh + [mise](https://mise.jdx.dev/) (tool versions) + [starship](https://starship.rs/) (prompt) + [atuin](https://atuin.sh/) (history) + [zoxide](https://github.com/ajeetdsouza/zoxide) (cd) + [fzf](https://github.com/junegunn/fzf) + [fzf-tab](https://github.com/Aloxaf/fzf-tab) + zsh-autosuggestions + [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) + [zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search), plus a small opt-in `ai.zsh` that routes one-shot prompts to whichever AI CLI (`claude`, `codex`, `agy`) is installed and appropriate for the current directory.

## Install

```sh
git clone https://github.com/sergeybataev/dotfiles.git && ~/dotfiles/install.sh
```

`install.sh` is idempotent: installs mise if missing, installs the pinned tool versions, clones the zsh plugins (autosuggestions, fzf-tab, fast-syntax-highlighting, history-substring-search), and symlinks `.zshrc` / `starship.toml` / `ai.zsh` / `zhelp.zsh` into place (backing up anything already there).

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
| `zhelp` / `zh` | Print this cheat sheet in the console (`zhelp <filter>` to grep it) |

## AI helpers (`ai.zsh`)

- `ai <question>` — one-shot prompt to the active assistant.
- `aix <task>` — same, but asks for a shell command only (prints it, doesn't run it).
- `wtf` — explains why the last command failed. Includes actual output when it can: if run inside tmux, the last ~50 lines of the pane's scrollback are attached (labeled as possibly containing unrelated lines); otherwise it prints a tip to use `wtf -r`. `wtf -r` re-runs the last command with stdout+stderr captured to a temp file and includes that output — it warns first and requires an explicit `y` confirmation (default No), since re-running a destructive command is exactly the kind of thing you don't want to do by accident.
- Routing: `$AI_ASSISTANT` override > `claude` under any `*/ExampleOrg/*` path (or your own org, edit to taste) > `codex` elsewhere. Falls back to whatever's actually installed.
- **Strict work-dir guard**: under a work path, `codex`/`agy` are refused outright (even via an explicit `$AI_ASSISTANT` override) and `claude` is used instead, with a one-line refusal printed to stderr. `Ctrl-X a` also drops `codex`/`agy` from the cycle while inside a work directory.
- The starship prompt shows the active assistant (bold bright-yellow = manual override, plain yellow = auto — see prompt notes below on why it's no longer `dimmed`).

## `zhelp` / `zh` — cheat sheet

Run `zhelp` (or `zh`) for a compact, colorized cheat sheet covering keybindings, AI helpers, custom aliases, prompt segments, and diagnostics — everything above, condensed for a quick console lookup. `zhelp <filter>` (e.g. `zhelp ai`, `zhelp history`) does a case-insensitive grep over it. Lives in `zsh/zhelp.zsh`, hand-curated (not auto-scraped) — there's a maintenance note at the top of that file as a nudge to keep it in sync when bindings/aliases change.

## Prompt segments (starship)

- `⚙ <dirname>` — shown when the current directory (or an ancestor, up to `$HOME`) has its own `mise.toml` / `.mise.toml` / `.tool-versions`; prints that ancestor's directory name. Nothing is shown otherwise (kept deliberately quiet rather than a fallback label). Computed with a pure-shell walk-up — no `mise` process spawned per prompt.
- `🤖 <assistant>` — see AI helpers above.

## Prompt contrast

Directory, git, mise, kubernetes, and both AI segments use bold + `bright-*` color variants (bright-cyan/bright-purple/bright-yellow/bright-blue/bright-green) so they stay readable on a translucent terminal background. The one exception is `custom.ai_auto` (the cwd-computed default assistant, not a manual override): it's plain `yellow` — same hue as the bold-bright-yellow manual override so it still reads as "AI assistant", but not bold, so it visually reads as secondary. It used to be `dimmed`, which on a translucent background reduced it to barely visible — dropped in favor of a real (non-dim) color at a lower weight instead.

## Shell performance notes

- **Debug timers**: set `ZSHRC_DEBUG=1` before starting a shell (e.g. `ZSHRC_DEBUG=1 zsh`) to get a per-section timing breakdown (sorted slowest-first) printed alongside the usual `⚡ zsh ready in N ms` line at the first prompt. Zero overhead when unset — every checkpoint is gated by a cheap `[[ -n $ZSHRC_DEBUG ]]` check.
- **Stale-while-revalidate caching**: `mise activate zsh`, `atuin init zsh`, `starship init zsh`, and `kubectl completion zsh` (all measured >15ms — things under that, like zoxide/direnv/`fzf --zsh`, are left as plain `eval`/`source`) go through `__zshrc_source_cached`, which:
  - generates the cache **inline** the first time it's missing (nothing to fall back to), or whenever the underlying binary is newer than the cache (an upgrade — correctness over speed, since this is rare);
  - otherwise, if the cache is just aged out (>24h), sources the **existing (stale)** cache immediately for a fast prompt, then regenerates it in a fully silent, disowned background job (atomic tmp-file + `mv`, so a concurrent shell never sees a half-written cache; `&!` so no job-control message ever reaches the prompt) — the refresh benefits *future* shells, not this one.
  - Cache files live under `~/.zsh/cache/`.
- `compinit` follows the same idea: if `~/.zcompdump` is missing (true first run), it does a full rebuild inline and prints `(rebuilding completion cache — first shell of the day is slower)` — the one remaining inline-slow path, worth explaining if seen. Otherwise it always takes the fast `compinit -C` path inline (skips the security audit + re-parse), and if the dump happens to be >24h old, kicks off a full rebuild in a silent, disowned background `zsh -c` so the *next* shell gets a fresh dump (`ZSHRC_DEBUG=1` prints `(completion dump refreshing in background)` when this fires). Staleness is checked via `zstat` mtime arithmetic, not zsh glob qualifiers — `(#qN.mh+24)`-style qualifiers silently require `setopt extendedglob` (which this config doesn't set), so an earlier version of this check was quietly always taking the slow "full rebuild" branch on every single startup, which was the actual cause of a startup-time regression at one point.
- `kubectl completion zsh` forking the `kubectl` binary on every invocation used to be the single biggest measured startup cost (tens of ms just to fork+exec `kubectl`) — now covered by the same caching helper as above.
- gcloud's `completion.zsh.inc` is lazy-loaded behind a `gcloud()` stub that sources it (and unfunctions itself) on first real invocation, instead of paying that cost on every shell startup.
