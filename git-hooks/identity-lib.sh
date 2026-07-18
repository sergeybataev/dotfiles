# identity-lib.sh — shared logic for the global git identity-guard hooks.
# Sourced by pre-commit and pre-push in this directory (core.hooksPath points
# here, so $(dirname "$0") resolves to this directory at hook time).
#
# Work-tree specifics come from the untracked ~/.zsh/work.zsh (WORK_ORG, and
# WORK_GITCONFIG — the path to your work user.email/name file). See
# zsh/work.zsh.example. WORK_GITCONFIG defaults to ~/.gitconfig-work.
[ -f "$HOME/.zsh/work.zsh" ] && . "$HOME/.zsh/work.zsh"
: "${WORK_GITCONFIG:=$HOME/.gitconfig-work}"

# idguard_expected_email <repo-top> — print the expected user.email for the
# tree the repo lives in; print nothing for an unknown tree.
idguard_expected_email() {
  case "$1" in
    */"$WORK_ORG"/*|*/"$WORK_ORG")
      [ -n "$WORK_ORG" ] && git config -f "$WORK_GITCONFIG" user.email 2>/dev/null
      ;;
    */sergeybataev/*|*/sergeybataev)
      git config -f "$HOME/.gitconfig-personal" user.email 2>/dev/null
      ;;
  esac
}

idguard_die() {
  printf 'identity guard: %s\n' "$1" >&2
  shift
  for line in "$@"; do
    printf '  %s\n' "$line" >&2
  done
  exit 1
}
