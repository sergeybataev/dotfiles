# ai.zsh — opt-in AI helpers with per-cwd assistant routing
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

# _ai_assistant: echo the name of the currently-active assistant.
#   1. $AI_ASSISTANT session override, if set and available.
#   2. cwd under ~/go/src/github.com/ExampleOrg (or any path containing
#      /ExampleOrg/) -> claude (work dirs must use claude only).
#   3. otherwise -> codex (personal default), falling back to whatever exists.
_ai_assistant() {
  local available="$(_ai_available_assistants)"
  [[ -z "$available" ]] && { echo "none"; return 1; }

  if [[ -n "$AI_ASSISTANT" ]]; then
    if [[ "$available" == *"$AI_ASSISTANT "* ]]; then
      echo "$AI_ASSISTANT"
      return 0
    fi
    # override set but binary missing — fall through to cwd default
  fi

  if [[ "$PWD" == */ExampleOrg/* ]]; then
    if [[ "$available" == *"claude "* ]]; then
      echo "claude"
      return 0
    fi
    echo "none"
    return 1
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
  if [[ "$_ai_last_status" -eq 0 ]]; then
    echo "wtf: last command exited 0 (no failure to explain)" >&2
    return 1
  fi
  local last_cmd
  last_cmd="$(fc -ln -1)"
  local assistant="$(_ai_assistant)"
  local prompt="This shell command exited with status $_ai_last_status: \`$last_cmd\`. Why did it fail, and how do I fix it?"
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
