#!/usr/bin/env bats
# Tests for the kubectl delete/drain/cordon guard in zsh/kube.zsh.
#
# The guard logic is zsh, so every test shells out to `zsh -c` sourcing
# kube.zsh. The real kubectl binary and the YubiKey confirm step are stubbed
# per-test — no cluster, no key, no ~/.kube mutation.

KUBE_ZSH="$BATS_TEST_DIRNAME/../zsh/kube.zsh"

# run_zsh <snippet> — source kube.zsh in a clean zsh and run the snippet.
run_zsh() {
  run zsh -c "source '$KUBE_ZSH'; $1"
}

@test "needs_confirm: delete on enterprise context is guarded" {
  run_zsh '_kube_guard_needs_confirm delete admin.dev.dev.oci'
  [ "$status" -eq 0 ]
}

@test "needs_confirm: drain on enterprise context is guarded" {
  run_zsh '_kube_guard_needs_confirm drain admin.staging.staging.oci'
  [ "$status" -eq 0 ]
}

@test "needs_confirm: cordon on docker-desktop is guarded (blanket non-homelab)" {
  run_zsh '_kube_guard_needs_confirm cordon docker-desktop'
  [ "$status" -eq 0 ]
}

@test "needs_confirm: delete on admin@homelab is NOT guarded" {
  run_zsh '_kube_guard_needs_confirm delete admin@homelab'
  [ "$status" -eq 1 ]
}

@test "needs_confirm: delete on homelab is NOT guarded" {
  run_zsh '_kube_guard_needs_confirm delete homelab'
  [ "$status" -eq 1 ]
}

@test "needs_confirm: get on enterprise context is NOT guarded" {
  run_zsh '_kube_guard_needs_confirm get admin.dev.dev.oci'
  [ "$status" -eq 1 ]
}

@test "needs_confirm: apply on enterprise context is NOT guarded (spec: not apply/scale)" {
  run_zsh '_kube_guard_needs_confirm apply admin.dev.dev.oci'
  [ "$status" -eq 1 ]
}

# --- wrapper behavior ---------------------------------------------------
# A stub kubectl binary sits first in PATH: it answers `config current-context`
# with $STUB_CONTEXT and logs every other invocation to $CALL_LOG.

setup() {
  STUB_BIN="$BATS_TEST_TMPDIR/bin"
  CALL_LOG="$BATS_TEST_TMPDIR/called.log"
  mkdir -p "$STUB_BIN"
  cat > "$STUB_BIN/kubectl" <<'EOF'
#!/bin/sh
if [ "$1" = "config" ] && [ "$2" = "current-context" ]; then
  echo "${STUB_CONTEXT:-none}"
  exit 0
fi
# don't log read-only `config` probes (the guard's namespace lookup) — the
# call log records only commands that would touch the cluster
if [ "$1" = "config" ]; then
  exit 0
fi
echo "REAL $*" >> "$CALL_LOG"
EOF
  chmod +x "$STUB_BIN/kubectl"
}

# run_wrapper <confirm-exit> <context> <kubectl-args...> — invoke the kubectl
# wrapper function with the stub binary active and the confirm step forced to
# succeed (0) or fail (1).
run_wrapper() {
  local confirm="$1" ctx="$2"
  shift 2
  run env PATH="$STUB_BIN:$PATH" CALL_LOG="$CALL_LOG" STUB_CONTEXT="$ctx" \
    zsh -c "source '$KUBE_ZSH'; _kube_guard_confirm() { return $confirm }; kubectl $*"
}

@test "wrapper: get passes through untouched on enterprise context" {
  run_wrapper 1 admin.dev.dev.oci get pods
  [ "$status" -eq 0 ]
  grep -q "REAL get pods" "$CALL_LOG"
}

@test "wrapper: delete on enterprise context is blocked when confirm fails" {
  run_wrapper 1 admin.dev.dev.oci delete pod foo
  [ "$status" -ne 0 ]
  [ ! -f "$CALL_LOG" ]
}

@test "wrapper: delete on enterprise context runs when confirm succeeds" {
  run_wrapper 0 admin.dev.dev.oci delete pod foo
  [ "$status" -eq 0 ]
  grep -q "REAL delete pod foo" "$CALL_LOG"
}

@test "wrapper: delete on homelab passes through without confirm" {
  run_wrapper 1 admin@homelab delete pod foo
  [ "$status" -eq 0 ]
  grep -q "REAL delete pod foo" "$CALL_LOG"
}

@test "wrapper: verb found after value-taking global flags" {
  run_wrapper 1 admin.dev.dev.oci -n kube-system delete pod foo
  [ "$status" -ne 0 ]
  [ ! -f "$CALL_LOG" ]
}

@test "wrapper: explicit --context=homelab overrides guarded current-context" {
  run_wrapper 1 admin.dev.dev.oci --context=admin@homelab delete pod foo
  [ "$status" -eq 0 ]
  grep -q "REAL --context=admin@homelab delete pod foo" "$CALL_LOG"
}

@test "wrapper: explicit --context=prod guards even when current-context is homelab" {
  run_wrapper 1 admin@homelab --context prod-cluster delete pod foo
  [ "$status" -ne 0 ]
  [ ! -f "$CALL_LOG" ]
}
