# AGENTS.md

Instructions for AI coding agents editing this repository.

## What this is

Personal dotfiles: a zsh setup built on **starship** (prompt), **mise** (tool versions), **atuin** (history), plus **fzf** / **fzf-tab** / **zoxide** / **zsh-autosuggestions** / **fast-syntax-highlighting** / **zsh-history-substring-search**, a small opt-in `ai.zsh` (per-directory AI CLI routing + a gh account guard), a per-directory `KUBECONFIG` binding with a `kubectl` destructive-verb guard, git identity-guard hooks, and a ghostty theme/workspace launcher.

## Golden rule: never hardcode work/identity strings

**This repo is PUBLIC and was history-scrubbed once already.** All employer/org/real-identity specifics are **parameterized** as environment variables sourced from an **untracked** `zsh/work.zsh` (gitignored; the runtime copy lives at `~/.zsh/work.zsh`). Real values live ONLY in that file — never in tracked files.

- Never write a literal org name, private repo name, work email, work username, enterprise kube context, or similar into any tracked file. Reference the variables instead.
- Placeholder variables (see `zsh/work.zsh.example`): `WORK_ORG`, `WORK_REPO`, `WORK_GH_USER`, `WORK_LABEL`, `HOMELAB`, `HOMELAB_CTX`, `WORK_GITCONFIG`, `GOPRIVATE`.
- Modules read these vars: `zsh/.zshrc` sources `~/.zsh/work.zsh` early, and `zsh/kube.zsh`, `zsh/ai.zsh`, `zsh/zhelp.zsh`, `bin/ws`, and `git-hooks/*` self-source it (guarded) so they work standalone. `starship/starship.toml` reads the exported vars from the shell env. Everything must degrade cleanly (feature disabled) when `WORK_ORG` is unset.
- The only personal identifier intentionally present is the GitHub username `sergeybataev` (public repo owner). Do not add others.

## Repo layout

- `zsh/` — `.zshrc`, `ai.zsh`, `kube.zsh`, `zhelp.zsh`, `work.zsh.example` (template; real `work.zsh` is gitignored)
- `git-hooks/` — `pre-commit`, `pre-push`, `identity-lib.sh` (global `core.hooksPath` identity guards)
- `bin/` — `ws` (ghostty workspace launcher)
- `starship/` — `starship.toml`
- `ghostty/` — `config`, `theme.conf`
- `mise/` — `config.toml` (pinned tools), `org-example.mise.toml` (template)
- `atuin/` — `config.toml`
- `tests/` — bats tests (`gh_wrapper.bats`, `identity_hooks.bats`, `kube_guard.bats`)
- `install.sh` — idempotent bootstrap (symlinks configs, installs tools/plugins, sets hooks)

## Testing

Run `bats tests/` (bats is pinned in `mise/config.toml`). All tests must stay green — any change to `ai.zsh`, `kube.zsh`, or `git-hooks/*` should be validated against the suite. Tests inject generic placeholder values via env (`WORK_ORG`, `WORK_GH_USER`, `WORK_GITCONFIG`); keep them free of real identifiers too.

## Mirror discipline

This repo mirrors the user's live dotfiles (some `~` paths are symlinks into it). Keep the sanitization intact: edits must preserve the "parameterized, no hardcoded work strings" invariant, and must not break the live shell (the work vars resolve real values only from the untracked `~/.zsh/work.zsh`).

## Do NOT commit

Secrets, tokens, real emails, org names, private repo names, or any employer-identifying string. If you need a concrete value to make something work, put it in `~/.zsh/work.zsh` (untracked) and reference the variable in tracked files.
