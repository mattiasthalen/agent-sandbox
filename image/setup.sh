#!/usr/bin/env bash
# Sourced from /etc/profile.d/agent-sandbox.sh on every shell startup.
# DO NOT add `set -e` here — we're sourced, not executed; an error must not
# kill the user's interactive shell.

if [[ -n "${SBX_SETUP_DONE:-}" ]]; then
  return 0
fi
export SBX_SETUP_DONE=1

STATE_DIR="${HOME}/.sandbox"
mkdir -p "$STATE_DIR"

# Generic hash-gated runner. Re-runs `runner` only when `source` content
# changes since the last successful run.
run_hash_gated() {
  local source="$1" hash_file="$2" label="$3" runner="$4"
  if [[ ! -f "$source" ]]; then return 0; fi
  local new_hash old_hash
  new_hash=$(sha256sum "$source" | cut -c1-16)
  old_hash=$(cat "$hash_file" 2>/dev/null || true)
  if [[ "$new_hash" != "$old_hash" ]]; then
    echo "==> $label changed (or first run); running" >&2
    eval "$runner"
    echo "$new_hash" > "$hash_file"
  fi
}

# Load LAN_IP from workspace runtime file written by host's sbx-up.
if [[ -f /workspace/.sbx/runtime.env ]]; then
  set -a
  # shellcheck disable=SC1091
  . /workspace/.sbx/runtime.env
  set +a
fi

if [[ -z "${LAN_IP:-}" ]]; then
  echo "agent-sandbox: LAN_IP not set; Pi cannot reach the model." >&2
  echo "agent-sandbox: did sbx-up write /workspace/.sbx/runtime.env?" >&2
  return 0
fi

# Render Pi's models.json with the current LAN_IP.
if [[ -f /etc/agent-sandbox/models.json.tmpl ]]; then
  mkdir -p "${HOME}/.pi/agent"
  envsubst < /etc/agent-sandbox/models.json.tmpl > "${HOME}/.pi/agent/models.json"
fi

# Hash-gated mise install for the workspace's mise.toml.
run_hash_gated /workspace/mise.toml \
  "${STATE_DIR}/mise.hash" "mise.toml" \
  '(cd /workspace && mise install)'

# Hash-gated postCreate for the workspace's .sbx/postCreate.sh.
run_hash_gated /workspace/.sbx/postCreate.sh \
  "${STATE_DIR}/postcreate.hash" ".sbx/postCreate.sh" \
  'bash /workspace/.sbx/postCreate.sh'
