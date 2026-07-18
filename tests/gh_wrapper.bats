#!/usr/bin/env bats
# Tests for the directory-aware gh wrapper in zsh/ai.zsh. A stub gh binary
# handles `auth switch` (rewriting the sandbox hosts.yml) and logs everything
# else; the sandbox $HOME keeps the real gh state untouched.

AI_ZSH="$BATS_TEST_DIRNAME/../zsh/ai.zsh"

setup() {
  FAKE_HOME="$BATS_TEST_TMPDIR/home"
  STUB_BIN="$BATS_TEST_TMPDIR/bin"
  CALL_LOG="$BATS_TEST_TMPDIR/called.log"
  HOSTS_YML="$FAKE_HOME/.config/gh/hosts.yml"
  mkdir -p "$FAKE_HOME/.config/gh" "$STUB_BIN"
  mkdir -p "$FAKE_HOME/go/src/github.com/ExampleOrg/repo1"
  mkdir -p "$FAKE_HOME/go/src/github.com/sergeybataev/repo2"
  mkdir -p "$FAKE_HOME/elsewhere"

  cat > "$STUB_BIN/gh" <<'EOF'
#!/bin/sh
if [ "$1" = "auth" ] && [ "$2" = "switch" ]; then
  [ -n "$STUB_SWITCH_FAIL" ] && exit 1
  user=""
  while [ $# -gt 0 ]; do
    if [ "$1" = "--user" ]; then user="$2"; shift; fi
    shift
  done
  printf 'github.com:\n    user: %s\n' "$user" > "$HOSTS_YML"
  exit 0
fi
echo "REAL $*" >> "$CALL_LOG"
EOF
  chmod +x "$STUB_BIN/gh"
}

set_active() {
  printf 'github.com:\n    git_protocol: https\n    users:\n        work-gh-user:\n        sergeybataev:\n    user: %s\n' "$1" > "$HOSTS_YML"
}

# run_gh <cwd> <gh-args...> — run the gh wrapper from <cwd> in the sandbox
run_gh() {
  local cwd="$1"
  shift
  run env HOME="$FAKE_HOME" PATH="$STUB_BIN:$PATH" CALL_LOG="$CALL_LOG" \
      HOSTS_YML="$HOSTS_YML" STUB_SWITCH_FAIL="${STUB_SWITCH_FAIL:-}" \
    zsh -c "cd '$cwd' && source '$AI_ZSH' && gh $*"
}

@test "is_write_op: pr create is a write op" {
  run zsh -c "source '$AI_ZSH'; _gh_is_write_op pr create"
  [ "$status" -eq 0 ]
}

@test "is_write_op: pr list is not a write op" {
  run zsh -c "source '$AI_ZSH'; _gh_is_write_op pr list"
  [ "$status" -eq 1 ]
}

@test "is_write_op: api with -X POST is a write op" {
  run zsh -c "source '$AI_ZSH'; _gh_is_write_op api -X POST /repos/x/y/issues"
  [ "$status" -eq 0 ]
}

@test "is_write_op: plain api GET is not a write op" {
  run zsh -c "source '$AI_ZSH'; _gh_is_write_op api /user"
  [ "$status" -eq 1 ]
}

@test "is_write_op: auth switch is not a write op" {
  run zsh -c "source '$AI_ZSH'; _gh_is_write_op auth switch"
  [ "$status" -eq 1 ]
}

@test "wrapper: auto-switches account in a work dir and announces it" {
  set_active sergeybataev
  run_gh "$FAKE_HOME/go/src/github.com/ExampleOrg/repo1" pr list
  [ "$status" -eq 0 ]
  [[ "$output" == *"switched"* ]]
  grep -q "user: work-gh-user" "$HOSTS_YML"
  grep -q "REAL pr list" "$CALL_LOG"
}

@test "wrapper: no switch when account already matches" {
  set_active work-gh-user
  run_gh "$FAKE_HOME/go/src/github.com/ExampleOrg/repo1" pr list
  [ "$status" -eq 0 ]
  [[ "$output" != *"switched"* ]]
  grep -q "REAL pr list" "$CALL_LOG"
}

@test "wrapper: blocks write op when switch fails and account mismatches" {
  set_active sergeybataev
  STUB_SWITCH_FAIL=1
  run_gh "$FAKE_HOME/go/src/github.com/ExampleOrg/repo1" pr create --title x
  [ "$status" -ne 0 ]
  [ ! -f "$CALL_LOG" ]
}

@test "wrapper: allows read op even when switch fails" {
  set_active sergeybataev
  STUB_SWITCH_FAIL=1
  run_gh "$FAKE_HOME/go/src/github.com/ExampleOrg/repo1" pr list
  [ "$status" -eq 0 ]
  grep -q "REAL pr list" "$CALL_LOG"
}

@test "wrapper: personal tree expects sergeybataev" {
  set_active work-gh-user
  run_gh "$FAKE_HOME/go/src/github.com/sergeybataev/repo2" issue list
  [ "$status" -eq 0 ]
  grep -q "user: sergeybataev" "$HOSTS_YML"
}

@test "wrapper: unknown tree passes through without switching" {
  set_active work-gh-user
  run_gh "$FAKE_HOME/elsewhere" pr create --title x
  [ "$status" -eq 0 ]
  grep -q "user: work-gh-user" "$HOSTS_YML"
  grep -q "REAL pr create --title x" "$CALL_LOG"
}
