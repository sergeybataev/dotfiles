# dotfiles

My shell setup: zsh + [mise](https://mise.jdx.dev/) (tool versions) + [starship](https://starship.rs/) (prompt) + [atuin](https://atuin.sh/) (history) + [zoxide](https://github.com/ajeetdsouza/zoxide) (cd) + [fzf](https://github.com/junegunn/fzf) + [fzf-tab](https://github.com/Aloxaf/fzf-tab) + zsh-autosuggestions + [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) + [zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search), plus a small opt-in `ai.zsh` that routes one-shot prompts to whichever AI CLI (`claude`, `codex`, `agy`) is installed and appropriate for the current directory.

## Install

```sh
git clone https://github.com/sergeybataev/dotfiles.git && ~/dotfiles/install.sh
```

`install.sh` is idempotent: installs mise if missing, installs the pinned tool versions, clones the zsh plugins (autosuggestions, fzf-tab, fast-syntax-highlighting, history-substring-search), and symlinks `.zshrc` / `starship.toml` / `ai.zsh` / `zhelp.zsh` / `kube.zsh` / `bin/ws` / `atuin/config.toml` / `ghostty/config` + `ghostty/theme.conf` into place (backing up anything already there). It also links `git-hooks/` as the global `core.hooksPath` (identity guards), generates a standalone `~/.kube/homelab.yaml` if the homelab context is available, and backs up the ghostty Application Support config so the XDG copy is the single source of truth.

### Work-specific setup (`work.zsh`)

This repo is public, so nothing employer-specific is hard-coded. All the work/homelab specifics live in an **untracked** `~/.zsh/work.zsh` (gitignored) that a few modules read as environment variables:

```sh
cp zsh/work.zsh.example ~/.zsh/work.zsh   # then edit the values
```

`zsh/.zshrc` sources it early, and `kube.zsh`, `bin/ws`, `zhelp.zsh`, and the git identity hooks self-source it too, so it works whether installed via symlink or copy. Variables it defines:

| Variable | Purpose |
|---|---|
| `WORK_ORG` | GitHub org that marks a "work" directory tree (`~/go/src/github.com/$WORK_ORG/...`). Drives AI routing, the starship work box, KUBECONFIG binding, and the gh/git identity guards. |
| `WORK_REPO` | Primary work repo dir name — `ws` opens the workspace at `$WORK_ORG/$WORK_REPO`. |
| `WORK_GH_USER` | gh CLI username the wrapper switches to inside work trees. |
| `WORK_LABEL` | Short label shown in the starship work box. |
| `HOMELAB` / `HOMELAB_CTX` | Homelab repo dir name and kube context. |
| `WORK_GITCONFIG` | Path to your work `user.email`/`name` git config (defaults to `~/.gitconfig-work`). Point it at your existing work gitconfig, or create `~/.gitconfig-work`. |
| `GOPRIVATE` | Go private module prefix for your work org. |

`mise/org-example.mise.toml` is the mise project-scoped equivalent for env vars like `GOPRIVATE` — drop it at the root of a directory tree and `mise trust` it.

`mise/config.toml` also pins `bat`, `difftastic`, `ripgrep`, `kubie`, and `bats` (test runner for `tests/*.bats`) at user scope (alongside starship/fzf/zoxide); these can coexist with Nix-provided copies of the same tools since mise shims win on `$PATH`.

One deliberately manual step: importing old-machine shell history into atuin. `atuin import zsh` has no idempotent re-import (duplicates on overlap), so locate the old `~/.zsh_history` and run the import exactly once — see the note at the top of `atuin/config.toml`.

## Keybinding cheat-sheet

| Key | Action |
|---|---|
| `→` / `End` | Accept the full autosuggestion (ghost text) |
| `Alt-F` | Accept one word of the autosuggestion |
| `↑` | Atuin history search scoped to the current directory ("what did I run *here*") |
| `↓` | History substring search down |
| `Ctrl-R` | Atuin fuzzy history search (global; inside the TUI `Ctrl-R` cycles filter, `Ctrl-S` cycles search mode) |
| `Ctrl-T` | fzf file finder |
| `Tab` (on a completion) | fzf-tab picker instead of the default completion menu |
| `Ctrl-X a` | Cycle active AI assistant (auto → claude → codex → agy → auto) |
| `Ctrl-X Ctrl-A` | Ask the active AI assistant to fix/complete the current command line |
| `zhelp` / `zh` | Print this cheat sheet in the console (`zhelp <filter>` to grep it) |

## AI helpers (`ai.zsh`)

- `ai <question>` — one-shot prompt to the active assistant.
- `aix <task>` — same, but asks for a shell command only (prints it, doesn't run it).
- `wtf` — explains why the last command failed. Includes actual output when it can: if run inside tmux, the last ~50 lines of the pane's scrollback are attached (labeled as possibly containing unrelated lines); otherwise it prints a tip to use `wtf -r`. `wtf -r` re-runs the last command with stdout+stderr captured to a temp file and includes that output — it warns first and requires an explicit `y` confirmation (default No), since re-running a destructive command is exactly the kind of thing you don't want to do by accident.
- Routing: `$AI_ASSISTANT` override > `claude` under any `*/$WORK_ORG/*` path (your work org, set in `work.zsh`) > `codex` elsewhere. Falls back to whatever's actually installed.
- **Strict work-dir guard**: under a work path, `codex`/`agy` are refused outright (even via an explicit `$AI_ASSISTANT` override) and `claude` is used instead, with a one-line refusal printed to stderr. `Ctrl-X a` also drops `codex`/`agy` from the cycle while inside a work directory.
- The starship prompt shows the active assistant (bold bright-yellow = manual override, plain yellow = auto — see prompt notes below on why it's no longer `dimmed`).

## `zhelp` / `zh` — cheat sheet

Run `zhelp` (or `zh`) for a compact, colorized cheat sheet covering keybindings, AI helpers, custom aliases, prompt segments, and diagnostics — everything above, condensed for a quick console lookup. `zhelp <filter>` (e.g. `zhelp ai`, `zhelp history`) does a case-insensitive grep over it. Lives in `zsh/zhelp.zsh`, hand-curated (not auto-scraped) — there's a maintenance note at the top of that file as a nudge to keep it in sync when bindings/aliases change.

## Kube context routing & guard (`kube.zsh`)

- **Per-directory `KUBECONFIG` binding**: a `chpwd` hook points non-work shells at a standalone homelab kubeconfig (`~/.kube/homelab.yaml`, current-context `$HOMELAB_CTX`) and work shells (`*/$WORK_ORG/*`) at `~/.kube/config` (where the enterprise CLI writes creds — current-context left exactly as it was set). Env-based only: nothing ever mutates `~/.kube/config`, and the hook backs off inside kubie subshells. `kubie ctx <ctx>` remains the tool for explicit ad-hoc switches.
- **Destructive-verb guard**: `kubectl delete` / `drain` / `cordon` on **any** context except homelab prints context + kubeconfig + namespace + command and demands a hardware-key confirmation (YubiKey present + typed context name; upgrade path to a touch-verified GPG signature is marked TODO in `kube.zsh` pending on-card key enrollment). No y/N, no bypass flag: scripts/CI never load the wrapper (interactive-only), and inside an interactive shell a guarded verb can't run unattended. Tested in `tests/kube_guard.bats`.

## Identity guards (git + gh)

- **git**: global `core.hooksPath` pre-commit/pre-push hooks block commits/pushes whose `user.email` doesn't match the tree (work tree `*/$WORK_ORG/*` → `$WORK_GITCONFIG` email, `sergeybataev` → personal). Repos outside both trees stop and prompt once for an explicit identity (written as a local override) instead of silently defaulting to personal. Both hooks chain to each repo's own `.git/hooks/*`. Tested in `tests/identity_hooks.bats`.
- **gh**: a wrapper in `ai.zsh` auto-runs `gh auth switch` to match the cwd's tree and prints a one-line notice on every flip; if the account still mismatches, write ops (`pr create`, `repo edit`, mutating `api` calls, …) are refused. Tested in `tests/gh_wrapper.bats`.

## Workspaces (`ws`)

`ws` is an fzf picker that builds ghostty layouts on demand via the AppleScript API (ghostty 1.3+; there's no native session save/restore, so layouts are recreated fresh each launch): **work** = 1 window, 3 tabs × 2 vertical panes at the `$WORK_ORG/$WORK_REPO` root; **homelab** = a sub-menu of `k8s-watchers` (node/kerr/rook-ceph watchers + agent + investigation panes, each auto-entering `kubie ctx $HOMELAB_CTX`), `agents-2`, `agents-4`, and `just-terminal`, all at the homelab root. Pane sizing is best-effort (ghostty splits ~equally).

## Theme (ghostty)

`ghostty/config` (base settings) + `ghostty/theme.conf` (16-slot ANSI palette on a deep blue-black `#0e1420` ground, accents brightened to survive the 0.5-opacity translucent background) are symlinked to `~/.config/ghostty/`. starship/fzf/bat reference ANSI slot names and inherit the palette for free; SSH boxes inherit it over the wire, so nothing is installed remotely.

## Prompt segments (starship)

- `[ $WORK_LABEL ]` — a filled rust-red (`#c05a5a`) box leading the prompt only under `*/$WORK_ORG/*`; personal trees show nothing. This is the work-identity tell (kept deliberately distinct from the bright `#ff7a85` dangerous-context red).
- `☸ <context> (<namespace>)` — always on when a context resolves; three severity tiers by context name: `*prod*` = bold bright red `#ff7a85`, `*stag*` = bold amber `#f2d08a`, everything else = bold bright-blue. Color = severity of the target; the delete/drain/cordon guard stays armed on all non-homelab contexts regardless of tier.
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
