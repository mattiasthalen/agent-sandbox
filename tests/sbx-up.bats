#!/usr/bin/env bats

setup() {
  # shellcheck disable=SC1091
  source "${BATS_TEST_DIRNAME}/../bin/sbx-up"
}

@test "discover_lan_ip returns en0 IP when present" {
  ipconfig() {
    case "$1 $2" in
      "getifaddr en0") echo "192.168.1.50" ;;
      *) return 1 ;;
    esac
  }
  export -f ipconfig

  run discover_lan_ip
  [ "$status" -eq 0 ]
  [ "$output" = "192.168.1.50" ]
}

@test "discover_lan_ip falls back to en1 when en0 is empty" {
  ipconfig() {
    case "$1 $2" in
      "getifaddr en0") return 1 ;;
      "getifaddr en1") echo "10.0.0.23" ;;
      *) return 1 ;;
    esac
  }
  export -f ipconfig

  run discover_lan_ip
  [ "$status" -eq 0 ]
  [ "$output" = "10.0.0.23" ]
}

@test "discover_lan_ip fails when both en0 and en1 are empty" {
  ipconfig() { return 1; }
  export -f ipconfig

  run discover_lan_ip
  [ "$status" -ne 0 ]
}

@test "ollama_is_up returns 0 when curl succeeds" {
  curl() { return 0; }
  export -f curl

  run ollama_is_up "192.168.1.50"
  [ "$status" -eq 0 ]
}

@test "ollama_is_up returns nonzero when curl fails" {
  curl() { return 7; }
  export -f curl

  run ollama_is_up "192.168.1.50"
  [ "$status" -ne 0 ]
}

@test "write_runtime_env creates .sbx/runtime.env with LAN_IP" {
  local tmpdir; tmpdir=$(mktemp -d)
  write_runtime_env "192.168.1.50" "$tmpdir"
  run cat "$tmpdir/.sbx/runtime.env"
  [ "$status" -eq 0 ]
  [ "$output" = "LAN_IP=192.168.1.50" ]
  rm -rf "$tmpdir"
}
