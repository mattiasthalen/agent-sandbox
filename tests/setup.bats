#!/usr/bin/env bats

# setup.sh has a SBX_SETUP_DONE guard that returns early when set, plus a
# `return 0` if LAN_IP is unset. Sourcing it here (with neither set) goes
# through the file: it sets SBX_SETUP_DONE=1, defines run_hash_gated, then
# bails on the LAN_IP check before doing anything else. Function definitions
# remain in scope.

setup() {
  # shellcheck disable=SC1091
  source "${BATS_TEST_DIRNAME}/../image/setup.sh"
  WORKDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$WORKDIR"
  unset SBX_SETUP_DONE
}

@test "run_hash_gated runs when source exists and no prior hash" {
  echo "tools = []" > "$WORKDIR/source.toml"
  : > "$WORKDIR/marker"
  run_hash_gated "$WORKDIR/source.toml" "$WORKDIR/hash" "test" \
    "echo ran > $WORKDIR/marker"
  [ "$(cat "$WORKDIR/marker")" = "ran" ]
  [ -s "$WORKDIR/hash" ]
}

@test "run_hash_gated skips when hash matches" {
  echo "tools = []" > "$WORKDIR/source.toml"
  echo "$(sha256sum "$WORKDIR/source.toml" | cut -c1-16)" > "$WORKDIR/hash"
  : > "$WORKDIR/marker"
  run_hash_gated "$WORKDIR/source.toml" "$WORKDIR/hash" "test" \
    "echo ran > $WORKDIR/marker"
  [ ! -s "$WORKDIR/marker" ]
}

@test "run_hash_gated re-runs when source changes" {
  echo "v1" > "$WORKDIR/source.toml"
  echo "$(sha256sum "$WORKDIR/source.toml" | cut -c1-16)" > "$WORKDIR/hash"
  echo "v2" > "$WORKDIR/source.toml"
  : > "$WORKDIR/marker"
  run_hash_gated "$WORKDIR/source.toml" "$WORKDIR/hash" "test" \
    "echo ran > $WORKDIR/marker"
  [ "$(cat "$WORKDIR/marker")" = "ran" ]
}

@test "run_hash_gated is no-op when source missing" {
  : > "$WORKDIR/marker"
  run_hash_gated "$WORKDIR/missing.toml" "$WORKDIR/hash" "test" \
    "echo ran > $WORKDIR/marker"
  [ ! -s "$WORKDIR/marker" ]
  [ ! -e "$WORKDIR/hash" ]
}
