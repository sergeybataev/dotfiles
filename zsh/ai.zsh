# ai.zsh — opt-in AI helpers with per-cwd assistant routing
#
# Work-tree specifics (WORK_ORG, WORK_GH_USER) come from the untracked
# ~/.zsh/work.zsh — see zsh/work.zsh.example. Self-sourced so this module keeps
# working when installed standalone.
[[ -f "$HOME/.zsh/work.zsh" ]] && source "$HOME/.zsh/work.zsh"
#
# Binaries checked at write-time on this machine (all present):
#   claude -> ~/.local/bin/claude   (one-shot: `claude -p "<prompt>"`)
#   codex  -> ~/.local/bin/codex    (one-shot: `codex exec "<prompt>"`)
#   agy    -> ~/.local/bin/agy      (one-shot: `agy -p "<prompt>"`, -p is an alias for --print)
#
# Routing only ever considers assistants that actually exist on PATH.

# ---------------------------------------------------------------------------
# 1. Assistant routing
# ---------------------------------------------------------------------------

# _ai_available_assistants: space-separated list of assistant binaries found on PATH,
# in preference order (claude, codex, agy).
_ai_available_assistants() {
  local a
  for a in claude codex agy; do
    (( $+commands[$a] )) && print -n -- "$a "
  done
}

# _ai_in_workdir: true (0) if $PWD is under a work directory (any path
# containing /$WORK_ORG/). WORK_ORG comes from the untracked ~/.zsh/work.zsh
# (see zsh/work.zsh.example); unset -> never a work directory.
_ai_in_workdir() {
  [[ -n "$WORK_ORG" && "$PWD" == */${WORK_ORG}/* ]]
}

# _ai_assistant: echo the name of the currently-active assistant.
#   1. $AI_ASSISTANT session override, if set, available, and not blocked by
#      the work-dir guard below.
#   2. cwd under a work tree (any path containing /$WORK_ORG/) -> claude (work
#      dirs must use claude only — HARD guard, codex/agy are refused even if
#      explicitly selected via $AI_ASSISTANT).
#   3. otherwise -> codex (personal default), falling back to whatever exists.
_ai_assistant() {
  local available="$(_ai_available_assistants)"
  [[ -z "$available" ]] && { echo "none"; return 1; }

  if _ai_in_workdir; then
    if [[ -n "$AI_ASSISTANT" && "$AI_ASSISTANT" != "claude" ]]; then
      echo "work directory: claude only (refusing $AI_ASSISTANT)" >&2
    fi
    if [[ "$available" == *"claude "* ]]; then
      echo "claude"
      return 0
    fi
    echo "none"
    return 1
  fi

  if [[ -n "$AI_ASSISTANT" ]]; then
    if [[ "$available" == *"$AI_ASSISTANT "* ]]; then
      echo "$AI_ASSISTANT"
      return 0
    fi
    # override set but binary missing — fall through to cwd default
  fi

  if [[ "$available" == *"codex "* ]]; then
    echo "codex"
  elif [[ "$available" == *"claude "* ]]; then
    echo "claude"
  elif [[ "$available" == *"agy "* ]]; then
    echo "agy"
  else
    echo "none"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# 2. ai-switch widget + Ctrl-X a binding — cycle AI_ASSISTANT
# ---------------------------------------------------------------------------

ai-switch() {
  local order=(auto claude codex agy)
  if _ai_in_workdir; then
    # work directories only ever use claude — don't offer codex/agy in the cycle
    order=(auto claude)
  fi
  local cur="${AI_ASSISTANT:-auto}"
  local i next
  for (( i = 1; i <= ${#order[@]}; i++ )); do
    if [[ "${order[$i]}" == "$cur" ]]; then
      next="${order[$(( i % ${#order[@]} + 1 ))]}"
      break
    fi
  done
  [[ -z "$next" ]] && next="auto"

  if [[ "$next" == "auto" ]]; then
    unset AI_ASSISTANT
  else
    export AI_ASSISTANT="$next"
  fi

  if (( ${+functions[zle]} )) || [[ -n "$WIDGET" ]]; then
    zle -M "ai assistant: $next"
  else
    echo "ai assistant: $next"
  fi
}

zle -N ai-switch
bindkey '^Xa' ai-switch

# ---------------------------------------------------------------------------
# 3. ai <question> — one-shot prompt to the active assistant
# ---------------------------------------------------------------------------

ai() {
  if [[ $# -eq 0 ]]; then
    echo "usage: ai <question>" >&2
    return 1
  fi
  local assistant="$(_ai_assistant)"
  case "$assistant" in
    claude)
      claude -p "$*"
      ;;
    codex)
      codex exec "$*"
      ;;
    agy)
      # TODO: verify agy's one-shot flag if this stops working; -p/--print
      # is documented as "run a single prompt non-interactively and print
      # the response" per `agy --help` as of writing.
      agy -p "$*"
      ;;
    *)
      echo "ai: no AI assistant binary found on PATH (looked for claude, codex, agy)" >&2
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# 4. aix <task> — ask for a shell command only, print (do not execute)
# ---------------------------------------------------------------------------

aix() {
  if [[ $# -eq 0 ]]; then
    echo "usage: aix <task>" >&2
    return 1
  fi
  local assistant="$(_ai_assistant)"
  local prompt="Output ONLY a shell command that accomplishes the following task. No prose, no explanation, no markdown code fences — just the raw command on its own line: $*"
  case "$assistant" in
    claude)
      claude -p "$prompt"
      ;;
    codex)
      codex exec "$prompt"
      ;;
    agy)
      agy -p "$prompt"
      ;;
    *)
      echo "aix: no AI assistant binary found on PATH (looked for claude, codex, agy)" >&2
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# 5. wtf — explain the last failed command
# ---------------------------------------------------------------------------

# Capture the exit status of every command before anything else (e.g. prompt
# rendering) can clobber $?.
_ai_last_status=0
_ai_precmd_capture_status() {
  _ai_last_status=$?
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _ai_precmd_capture_status

wtf() {
  local rerun=0
  if [[ "$1" == "-r" ]]; then
    rerun=1
    shift
  fi

  if [[ "$_ai_last_status" -eq 0 ]]; then
    echo "wtf: last command exited 0 (no failure to explain)" >&2
    return 1
  fi

  local last_cmd
  last_cmd="$(fc -ln -1)"
  local assistant
  assistant="$(_ai_assistant)"
  local prompt="This shell command exited with status $_ai_last_status: \`$last_cmd\`. Why did it fail, and how do I fix it?"
  local output_block=""

  if [[ "$rerun" -eq 1 ]]; then
    echo "wtf -r: this will RE-RUN the last command:" >&2
    echo "  $last_cmd" >&2
    local reply
    read -r "reply?Re-execute it now to capture output? [y/N] "
    if [[ "$reply" != [yY] && "$reply" != [yY][eE][sS] ]]; then
      echo "wtf: aborted, not re-running." >&2
      return 1
    fi
    local tmpfile
    tmpfile="$(mktemp "${TMPDIR:-/tmp}/wtf-rerun.XXXXXX")"
    eval "$last_cmd" >"$tmpfile" 2>&1
    local rerun_status=$?
    output_block=$'\n\nre-run output (exit status '"$rerun_status"$'):\n'"$(cat "$tmpfile")"
    rm -f "$tmpfile"
  elif [[ -n "$TMUX" ]]; then
    local pane_output
    pane_output="$(tmux capture-pane -p -S -50 2>/dev/null)"
    if [[ -n "$pane_output" ]]; then
      output_block=$'\n\nterminal output (may include unrelated lines):\n'"$pane_output"
    fi
  else
    echo "tip: run inside tmux or use wtf -r to include output" >&2
  fi

  prompt="${prompt}${output_block}"

  case "$assistant" in
    claude)
      claude -p "$prompt"
      ;;
    codex)
      codex exec "$prompt"
      ;;
    agy)
      agy -p "$prompt"
      ;;
    *)
      echo "wtf: no AI assistant binary found on PATH (looked for claude, codex, agy)" >&2
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# 6. ai-fix-buffer widget bound to Ctrl-X Ctrl-A — fix/complete the typed
#    (not yet executed) command line using the active assistant.
# ---------------------------------------------------------------------------

ai-fix-buffer() {
  if [[ -z "$BUFFER" ]]; then
    zle -M "ai-fix-buffer: buffer is empty"
    return
  fi
  local assistant="$(_ai_assistant)"
  if [[ "$assistant" == "none" ]]; then
    zle -M "ai-fix-buffer: no AI assistant binary found on PATH"
    return
  fi

  zle -M "thinking..."

  local prompt="Fix or complete this shell command. Output ONLY the corrected command, no prose, no explanation, no markdown: $BUFFER"
  local result
  case "$assistant" in
    claude)
      result="$(claude -p "$prompt" 2>/dev/null)"
      ;;
    codex)
      result="$(codex exec "$prompt" 2>/dev/null)"
      ;;
    agy)
      result="$(agy -p "$prompt" 2>/dev/null)"
      ;;
  esac

  if [[ -z "$result" ]]; then
    zle -M "ai-fix-buffer: assistant returned nothing"
    return
  fi

  BUFFER="$result"
  CURSOR=${#BUFFER}
  zle -M "ai-fix-buffer: done"
}

zle -N ai-fix-buffer
bindkey '^X^A' ai-fix-buffer

# ---------------------------------------------------------------------------
# 7. gh — directory-aware account switching + wrong-account write guard
# ---------------------------------------------------------------------------
# gh's active account is global per host, not per-directory. This wrapper
# auto-runs `gh auth switch` to match the cwd's tree (announcing every flip so
# it's never silent) and refuses write operations (pr create, etc.) when the
# active account still doesn't match — belt-and-suspenders for the case where
# the switch failed. Caveat: only interactive invocations are governed; a
# background/agent gh call still mutates global state — the announce line is
# what makes that observable.

# _gh_expected_account: the gh account the cwd's tree expects, empty if the
# cwd is outside both known trees (unknown trees are not governed).
_gh_expected_account() {
  if [[ -n "$WORK_ORG" && "$PWD" == */${WORK_ORG}/* ]]; then
    print -n "$WORK_GH_USER"
    return
  fi
  case "$PWD" in
    */sergeybataev/*) print -n "sergeybataev" ;;
  esac
}

# _gh_active_account: currently-active gh account for github.com, read
# locally from hosts.yml (no network round-trip on every gh call).
_gh_active_account() {
  awk '$1 == "user:" { print $2; exit }' "$HOME/.config/gh/hosts.yml" 2>/dev/null
}

# _gh_is_write_op <gh-args...> — 0 iff the invocation writes to GitHub.
_gh_is_write_op() {
  local cmd="" action="" a
  for a in "$@"; do
    [[ "$a" == -* ]] && continue
    if [[ -z "$cmd" ]]; then
      cmd="$a"
      continue
    fi
    action="$a"
    break
  done
  case "$cmd" in
    pr|issue|repo|release|gist)
      case "$action" in
        list|view|status|diff|checks|download|clone) return 1 ;;
        *) return 0 ;;
      esac
      ;;
    api)
      for a in "$@"; do
        case "$a" in
          -X|--method|-X*|--method=*|-f|-F|--field|--field=*|--raw-field|--input|--input=*) return 0 ;;
        esac
      done
      return 1
      ;;
  esac
  return 1
}

gh() {
  local expected active
  expected="$(_gh_expected_account)"
  if [[ -n "$expected" ]]; then
    active="$(_gh_active_account)"
    if [[ -n "$active" && "$active" != "$expected" ]]; then
      if command gh auth switch --hostname github.com --user "$expected" >/dev/null 2>&1; then
        print -u2 "gh: switched active account $active → $expected (for ${PWD/#$HOME/~})"
        active="$expected"
      fi
    fi
    if [[ "$active" != "$expected" ]] && _gh_is_write_op "$@"; then
      print -u2 "gh: BLOCKED write op — active account '$active' ≠ '$expected' expected for this tree"
      print -u2 "gh: fix with: gh auth switch --user $expected"
      return 1
    fi
  fi
  command gh "$@"
}
