#!/usr/bin/env bats
# Tests for the global git identity-guard hooks (git-hooks/pre-commit,
# git-hooks/pre-push). Everything runs in a sandbox $HOME with fake identity
# include files — the real ~/.gitconfig* is never touched.

HOOKS_DIR="$BATS_TEST_DIRNAME/../git-hooks"

setup() {
  FAKE_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$FAKE_HOME"
  printf '[user]\n    email = work@example.test\n    name = Work Id\n' > "$FAKE_HOME/.gitconfig-work"
  printf '[user]\n    email = me@personal.test\n    name = Personal Id\n' > "$FAKE_HOME/.gitconfig-personal"

  WORK_REPO_DIR="$FAKE_HOME/go/src/github.com/ExampleOrg/repo1"
  PERS_REPO="$FAKE_HOME/go/src/github.com/sergeybataev/repo2"
  UNKNOWN_REPO="$FAKE_HOME/other/repo3"
  for r in "$WORK_REPO_DIR" "$PERS_REPO" "$UNKNOWN_REPO"; do
    mkdir -p "$r"
    git -C "$r" init -q
  done
}

# run_hook <hook-name> <repo> — run a hook from the repo's directory with the
# sandbox HOME, stdin closed (no tty).
run_hook() {
  local hook="$1" repo="$2"
  run env HOME="$FAKE_HOME" GIT_CONFIG_GLOBAL="$FAKE_HOME/.gitconfig" \
    bash -c "cd '$repo' && '$HOOKS_DIR/$hook' < /dev/null"
}

@test "pre-commit: work repo with matching email passes" {
  git -C "$WORK_REPO_DIR" config user.email work@example.test
  run_hook pre-commit "$WORK_REPO_DIR"
  [ "$status" -eq 0 ]
}

@test "pre-commit: work repo with personal email is blocked" {
  git -C "$WORK_REPO_DIR" config user.email me@personal.test
  run_hook pre-commit "$WORK_REPO_DIR"
  [ "$status" -ne 0 ]
}

@test "pre-commit: personal repo with matching email passes" {
  git -C "$PERS_REPO" config user.email me@personal.test
  run_hook pre-commit "$PERS_REPO"
  [ "$status" -eq 0 ]
}

@test "pre-commit: personal repo with work email is blocked" {
  git -C "$PERS_REPO" config user.email work@example.test
  run_hook pre-commit "$PERS_REPO"
  [ "$status" -ne 0 ]
}

@test "pre-commit: unknown tree with no local identity is blocked" {
  run_hook pre-commit "$UNKNOWN_REPO"
  [ "$status" -ne 0 ]
}

@test "pre-commit: unknown tree with a local identity override passes" {
  git -C "$UNKNOWN_REPO" config user.email whoever@else.test
  run_hook pre-commit "$UNKNOWN_REPO"
  [ "$status" -eq 0 ]
}

@test "pre-commit: chains to the repo's own .git/hooks/pre-commit" {
  git -C "$WORK_REPO_DIR" config user.email work@example.test
  printf '#!/bin/sh\ntouch "%s/chained"\n' "$BATS_TEST_TMPDIR" > "$WORK_REPO_DIR/.git/hooks/pre-commit"
  chmod +x "$WORK_REPO_DIR/.git/hooks/pre-commit"
  run_hook pre-commit "$WORK_REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$BATS_TEST_TMPDIR/chained" ]
}

# --- pre-push -------------------------------------------------------------

# make_commit <repo> <email> — one commit authored/committed as <email>
make_commit() {
  local repo="$1" email="$2"
  echo x >> "$repo/f"
  git -C "$repo" add f
  # --no-verify: the machine's global hooks must not fire while building the
  # fixture — the hook under test is invoked directly by run_prepush
  git -C "$repo" -c user.email="$email" -c user.name=T commit -qm x --no-verify
}

# run_prepush <repo> — run pre-push feeding the standard ref line on stdin
run_prepush() {
  local repo="$1"
  local sha
  sha="$(git -C "$repo" rev-parse HEAD)"
  run env HOME="$FAKE_HOME" GIT_CONFIG_GLOBAL="$FAKE_HOME/.gitconfig" \
    bash -c "cd '$repo' && echo 'refs/heads/main $sha refs/heads/main 0000000000000000000000000000000000000000' | '$HOOKS_DIR/pre-push' origin git@example.com:x/y.git"
}

@test "pre-push: work repo with correctly-authored commits passes" {
  git -C "$WORK_REPO_DIR" config user.email work@example.test
  make_commit "$WORK_REPO_DIR" work@example.test
  run_prepush "$WORK_REPO_DIR"
  [ "$status" -eq 0 ]
}

@test "pre-push: work repo with a personal-authored commit is blocked" {
  git -C "$WORK_REPO_DIR" config user.email work@example.test
  make_commit "$WORK_REPO_DIR" me@personal.test
  run_prepush "$WORK_REPO_DIR"
  [ "$status" -ne 0 ]
}

@test "pre-push: resolved-config mismatch is blocked even with clean commits" {
  git -C "$WORK_REPO_DIR" config user.email me@personal.test
  make_commit "$WORK_REPO_DIR" work@example.test
  run_prepush "$WORK_REPO_DIR"
  [ "$status" -ne 0 ]
}
