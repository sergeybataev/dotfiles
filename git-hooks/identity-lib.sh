# identity-lib.sh — shared logic for the global git identity-guard hooks.
# Sourced by pre-commit and pre-push in this directory (core.hooksPath points
# here, so $(dirname "$0") resolves to this directory at hook time).

# idguard_expected_email <repo-top> — print the expected user.email for the
# tree the repo lives in; print nothing for an unknown tree.
idguard_expected_email() {
  case "$1" in
    */ExampleOrg/*|*/ExampleOrg)
      git config -f "$HOME/.gitconfig-work" user.email 2>/dev/null
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
