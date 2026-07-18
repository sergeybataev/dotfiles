# zhelp.zsh — self-documenting cheat sheet for this zsh setup.
#
# MAINTENANCE NOTE: this sheet is hand-curated, not auto-scraped from
# keybindings/aliases. Update it whenever you add/change a binding, alias,
# AI command, or prompt segment elsewhere in ~/.zshrc, ~/.zsh/ai.zsh, or
# ~/.config/starship.toml — it will silently drift otherwise.
#
# Usage: `zhelp` (or `zh`) prints the whole sheet. `zhelp <filter>` (or
# `zh <filter>`) does a case-insensitive grep over it, e.g. `zhelp ai`,
# `zhelp history`.

# Work-tree labels (WORK_ORG, WORK_LABEL, WORK_REPO, HOMELAB) come from the
# untracked ~/.zsh/work.zsh — see zsh/work.zsh.example.
[[ -f "$HOME/.zsh/work.zsh" ]] && source "$HOME/.zsh/work.zsh"

zhelp() {
  local filter="$1"
  local -a lines

  # Build the sheet as an array of already-color-escaped lines, then expand
  # %-escapes once via `print -P`, then optionally grep -i on the plain text.
  lines=(
    "%B%F{cyan}Keybindings%f%b"
    "  %F{white}→ / End / Ctrl-E%f    %F{8}accept the full ghost autosuggestion%f"
    "  %F{white}Alt-F / Ctrl-→%f      %F{8}accept one word of the autosuggestion%f"
    "  %F{white}Tab%f                 %F{8}fzf-tab picker instead of the default completion menu%f"
    "  %F{white}↑%f                   %F{8}atuin history search scoped to the current directory (\"what did I run here\")%f"
    "  %F{white}↓%f                   %F{8}history substring search down%f"
    "  %F{white}Ctrl-R%f              %F{8}atuin fuzzy history search (global); inside it Ctrl-R cycles filter, Ctrl-S cycles search mode%f"
    "  %F{white}Ctrl-T%f              %F{8}fzf file finder, inserts path at cursor%f"
    "  %F{white}Alt-C%f               %F{8}fzf cd — fuzzy-pick a directory and cd into it%f"
    "  %F{white}Ctrl-X a%f            %F{8}cycle active AI assistant (auto → claude → codex → agy → auto)%f"
    "  %F{white}Ctrl-X Ctrl-A%f       %F{8}ask the active AI assistant to fix/complete the current command line%f"
    ""
    "%B%F{cyan}AI commands (ai.zsh)%f%b"
    "  %F{white}ai <question>%f       %F{8}one-shot prompt to the active assistant%f"
    "  %F{white}aix <task>%f          %F{8}ask for a shell command only (prints it, doesn't run it)%f"
    "  %F{white}wtf%f                 %F{8}explain why the last command failed%f"
    "  %F{white}  (in tmux)%f         %F{8}also attaches the last ~50 lines of pane scrollback%f"
    "  %F{white}wtf -r%f              %F{8}re-runs the last command (stdout+stderr captured) — asks y/N first%f"
    "  %F{white}strict work-dir rule%f %F{8}under */${WORK_ORG:-<work-org>}/* only claude is used, codex/agy refused%f"
    "  %F{white}🤖 prompt segment%f    %F{8}bold bright-yellow = manual \$AI_ASSISTANT override, plain yellow = auto (cwd default)%f"
    ""
    "%B%F{cyan}Custom commands / aliases%f%b"
    "  %F{white}catt%f                %F{8}bat (or batcat) — syntax-highlighted cat%f"
    "  %F{white}diff%f                %F{8}aliased to difft (difftastic) — structural, syntax-aware diffing%f"
    "  %F{white}k%f                   %F{8}kubectl%f"
    "  %F{white}kerr%f                %F{8}list all pods across namespaces that are NOT Running%f"
    "  %F{white}kubie ctx <ctx>%f     %F{8}explicit kube context switch in an isolated subshell (never edits ~/.kube/config)%f"
    "  %F{white}kubectl guard%f       %F{8}delete/drain/cordon on any non-homelab context needs a hardware-key confirm — no bypass%f"
    "  %F{white}auto KUBECONFIG%f     %F{8}cd into */${WORK_ORG:-<work-org>}/* → ~/.kube/config (enterprise creds); elsewhere → homelab kubeconfig%f"
    "  %F{white}gh (wrapped)%f        %F{8}auto-switches gh account per tree (announced); write ops blocked on wrong account%f"
    "  %F{white}git identity guard%f  %F{8}pre-commit/pre-push block wrong user.email per tree; unknown repos prompt once%f"
    "  %F{white}zshv / zshs%f         %F{8}edit / reload ~/.zshrc%f"
    "  %F{white}tm%f                  %F{8}attach to (or create) a tmux session%f"
    "  %F{white}fixm%f                %F{8}reset terminal mouse-reporting after a dropped ssh session%f"
    "  %F{white}z / zi%f              %F{8}zoxide: jump to a frecent directory / interactive picker%f"
    "  %F{white}ws%f                  %F{8}ghostty workspace launcher (fzf): work = 3 tabs × 2 panes at ${WORK_REPO:-<work-repo>}%f"
    "  %F{white}ws homelab%f          %F{8}sub-menu: k8s-watchers / agents-2 / agents-4 / just-terminal (${HOMELAB:-homelab} dir)%f"
    ""
    "%B%F{cyan}Prompt segments legend%f%b"
    "  %F{white}⚙ <dirname>%f         %F{8}nearest ancestor dir with its own mise.toml/.mise.toml/.tool-versions%f"
    "  %F{white}[ ${WORK_LABEL:-Work} ] box%f        %F{8}rust-red filled box leading the prompt = you're under */${WORK_ORG:-<work-org>}/* (work identity)%f"
    "  %F{white}☸ <ctx> (<ns>)%f      %F{8}current kubectl context (and namespace, if set)%f"
    "  %F{white}☸ color tiers%f       %F{8}*prod* = bright red, *stag* = amber, everything else = blue; guard is armed on ALL non-homelab regardless of color%f"
    "  %F{white}🤖 <assistant>%f      %F{8}active AI assistant — see AI commands above%f"
    "  %F{white}git glyphs%f          %F{8} branch name; ahead/behind + dirty-state markers next to it%f"
    ""
    "%B%F{cyan}Diagnostics%f%b"
    "  %F{white}⚡ zsh ready in N ms%f %F{8}printed at every first prompt — overall startup cost%f"
    "  %F{white}ZSHRC_DEBUG=1%f       %F{8}set before starting a shell for a sorted per-section timing table%f"
    "  %F{white}(rebuilding completion cache...)%f %F{8}printed the first time ever (or after deleting ~/.zcompdump) — one-time full compinit rebuild%f"
    "  %F{white}(completion dump refreshing in background)%f %F{8}ZSHRC_DEBUG-only — daily compinit refresh running silently for future shells%f"
    ""
    "%F{8}Full version, rationale, and install instructions: https://github.com/sergeybataev/dotfiles#readme%f"
  )

  if [[ -n "$filter" ]]; then
    local line
    for line in "${lines[@]}"; do
      # case-insensitive grep on the plain (unexpanded) text
      if [[ "${line:l}" == *"${filter:l}"* ]]; then
        print -P -- "$line"
      fi
    done
  else
    local line
    for line in "${lines[@]}"; do
      print -P -- "$line"
    done
  fi
}

alias zh=zhelp
