#!/usr/bin/env bats

@test "shared mise default supports Pi and shell startup activates mise" {
  run grep -Fx 'node = "24.14.0"' "$BATS_TEST_DIRNAME/../mise/config.toml"
  [ "$status" -eq 0 ]
  run grep -F 'mise activate zsh' "$BATS_TEST_DIRNAME/../zsh/.zshrc"
  [ "$status" -eq 0 ]
}
