# agent-sandbox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a small personal repo that lets `sbx-up` (run from any project on the host Mac) drop the user into an sbx microVM where Pi can talk to Qwen served by host Ollama.

**Architecture:** Two layers. Host: `make setup` installs deps via Homebrew, builds the sandbox image, and symlinks `sbx-up` into `~/.local/bin`. `sbx-up` discovers the host's LAN IP, ensures Ollama is running and bound to it, generates a per-invocation network policy, and launches `sbx run` with the workspace mounted and `LAN_IP` injected as an env var. Image: pre-baked Pi + superpowers + tools; entrypoint renders `models.json` from the env var on every boot and hash-gates `mise install` and an optional `.sbx/postCreate.sh`.

**Tech Stack:** bash, make, Homebrew, sbx, Ollama, Docker (for the image), bats-core (for unit tests), mise.

**Source spec:** `docs/superpowers/specs/2026-05-05-agent-sandbox-design.md`

---

## Phase 0: Resolve open questions

The spec lists open questions that block several later tasks. Resolve them here, capture answers in a notes file, then proceed. Don't implement anything in this phase — just produce documentation.

### Task 0.1: Create research notes scaffold

**Files:**
- Create: `docs/superpowers/notes/research-notes.md`

- [ ] **Step 1: Create the notes file with empty sections**

```markdown
# agent-sandbox research notes

Findings from Phase 0. Used by Phase 2 (image) and Phase 5 (entrypoint).

## Pi install method
TBD

## Pi config and discovery paths
- AGENTS.md location:
- models.json location (or env var name):
- superpowers skills discovery path:

## sbx CLI surface
- `sbx build` flags actually used:
- `sbx run` flags actually used:
- Policy file format and `--policy` flag name:
- Workspace mount flag name:
- Env var injection flag name:
- How per-workspace state persistence is keyed (auto / explicit flag):

## Ollama model tag
- Exact tag for Qwen3.6-35B-A3B in the Ollama registry:
- Approximate download size:

## Base image choice
- Selected: debian:slim or ubuntu:minimal
- Reason:
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/notes/research-notes.md
git commit -m "docs: scaffold Phase 0 research notes"
```

### Task 0.2: Resolve Pi install method and config paths

**Files:**
- Modify: `docs/superpowers/notes/research-notes.md`

- [ ] **Step 1: Read `obra/superpowers` README and any install docs on GitHub**

Look for: how Pi is installed (npm? release tarball? pipx? cargo?), what env vars or config files Pi reads to configure its model endpoint, where Pi looks for an `AGENTS.md`, and where Pi discovers skills.

- [ ] **Step 2: Fill in the "Pi install method" and "Pi config and discovery paths" sections** with concrete answers

Example shape (replace with real findings):

```markdown
## Pi install method
`npm install -g @obra/pi` (verified from README @ <commit-sha>)

## Pi config and discovery paths
- AGENTS.md location: `~/.config/pi/AGENTS.md` (per docs)
- models.json location: reads `PI_MODEL_ENDPOINT` env var if set, else `~/.config/pi/models.json`
- superpowers skills discovery path: `~/.config/pi/skills/`
```

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/notes/research-notes.md
git commit -m "docs: resolve Pi install and config research"
```

### Task 0.3: Resolve sbx CLI surface

**Files:**
- Modify: `docs/superpowers/notes/research-notes.md`

- [ ] **Step 1: Run `sbx --help`, `sbx build --help`, `sbx run --help`**

If `sbx` isn't installed yet on this machine, read its docs / repo README on the web instead. Do not install it as part of this task — that's Phase 1.

- [ ] **Step 2: Fill in the "sbx CLI surface" section** with the actual flag names

What we need to know:
- The flag for naming/tagging an image at build (`-t`? `--tag`? `--name`?).
- The flag for passing a network policy file at run (`--policy`? `--network-policy`?).
- The flag for mounting a host directory into the VM (`--mount`? `--volume`? `-v`?).
- The flag for injecting env vars (`--env`? `-e`?).
- Whether per-workspace state is keyed automatically off the mount path or requires an explicit `--workspace-key` flag.
- The expected policy file format (JSON? YAML? TOML?).

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/notes/research-notes.md
git commit -m "docs: resolve sbx CLI surface research"
```

### Task 0.4: Resolve Ollama model tag and base image choice

**Files:**
- Modify: `docs/superpowers/notes/research-notes.md`

- [ ] **Step 1: Look up the Qwen3.6-35B-A3B tag on `ollama.com/library`**

Find the canonical tag string the user will pass to `ollama pull`. Note the approximate download size.

- [ ] **Step 2: Pick a base image for the sandbox**

Pick `debian:bookworm-slim` or `ubuntu:24.04` based on which makes the Pi install (from Task 0.2) simplest. If Pi is `npm install -g`, both work; pick the smaller one (`debian:bookworm-slim`). If Pi needs a specific glibc or system package only easily available on one, document why.

- [ ] **Step 3: Fill in the "Ollama model tag" and "Base image choice" sections**

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/notes/research-notes.md
git commit -m "docs: resolve model tag and base image research"
```

---

## Phase 1: Host setup (Brewfile + Makefile + sbx-up stub)

End state of this phase: `make setup` runs cleanly on a fresh Mac, `which sbx-up` returns the symlink in `~/.local/bin/`, and running `sbx-up` prints a "not yet implemented" message and exits 0.

### Task 1.1: Write the Brewfile

**Files:**
- Create: `Brewfile`

- [ ] **Step 1: Write the Brewfile**

```ruby
# agent-sandbox host dependencies.
# `make setup` runs `brew bundle` against this file.

brew "ollama"
brew "sbx"
brew "mise"
brew "gh"
brew "jq"
brew "uv"

# Test framework for the sbx-up bash logic.
brew "bats-core"
```

- [ ] **Step 2: Verify it parses**

Run: `brew bundle check --file=Brewfile || true`
Expected: either reports missing items (most will be missing on a fresh checkout) or "all dependencies are satisfied". Either is fine — we just want no syntax errors.

- [ ] **Step 3: Commit**

```bash
git add Brewfile
git commit -m "feat: add Brewfile for host dependencies"
```

### Task 1.2: Write the sbx-up stub

**Files:**
- Create: `bin/sbx-up`

- [ ] **Step 1: Write the stub**

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "sbx-up: not yet implemented (Phase 1 stub)" >&2
exit 0
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x bin/sbx-up`

- [ ] **Step 3: Verify it runs**

Run: `./bin/sbx-up`
Expected stderr: `sbx-up: not yet implemented (Phase 1 stub)`
Expected exit code: 0

- [ ] **Step 4: Commit**

```bash
git add bin/sbx-up
git commit -m "feat: add sbx-up stub"
```

### Task 1.3: Write the Makefile

**Files:**
- Create: `Makefile`

- [ ] **Step 1: Write the Makefile**

```make
.PHONY: setup

REPO := $(shell pwd)
LOCAL_BIN := $(HOME)/.local/bin
CONFIG_DIR := $(HOME)/.config/agent-sandbox
CACHE_DIR := $(HOME)/.cache/agent-sandbox

setup:
	@echo "==> brew bundle"
	brew bundle --file=$(REPO)/Brewfile

	@echo "==> sbx build"
	sbx build -t agent-sandbox $(REPO)/image/

	@echo "==> host config dirs"
	mkdir -p $(CONFIG_DIR) $(CACHE_DIR)
	cp $(REPO)/policy/network.tmpl $(CONFIG_DIR)/network.tmpl

	@echo "==> install sbx-up symlink"
	mkdir -p $(LOCAL_BIN)
	ln -sf $(REPO)/bin/sbx-up $(LOCAL_BIN)/sbx-up

	@echo
	@if echo "$$PATH" | tr ':' '\n' | grep -qx "$(LOCAL_BIN)"; then \
		echo "✓ sbx-up installed at $(LOCAL_BIN)/sbx-up"; \
	else \
		echo "sbx-up installed at $(LOCAL_BIN)/sbx-up"; \
		echo "Add this to your shell rc to put it on PATH:"; \
		echo "  export PATH=\"$$HOME/.local/bin:$$PATH\""; \
	fi
```

Note: the `sbx build` and `cp policy/network.tmpl` lines reference files that don't exist yet (Phases 2 and 4). That's deliberate — `make setup` is the integration point. We'll add the missing pieces in later phases. The stub `sbx-up` is enough to verify the symlink + PATH check work.

- [ ] **Step 2: Temporarily comment out the steps that depend on later phases**

Edit the Makefile to comment out `brew bundle` (depends on tools being present), `sbx build` (no Dockerfile yet), and the `cp policy/network.tmpl` line (no template yet):

```make
setup:
	# @echo "==> brew bundle"
	# brew bundle --file=$(REPO)/Brewfile

	# @echo "==> sbx build"
	# sbx build -t agent-sandbox $(REPO)/image/

	@echo "==> host config dirs"
	mkdir -p $(CONFIG_DIR) $(CACHE_DIR)
	# cp $(REPO)/policy/network.tmpl $(CONFIG_DIR)/network.tmpl

	@echo "==> install sbx-up symlink"
	mkdir -p $(LOCAL_BIN)
	ln -sf $(REPO)/bin/sbx-up $(LOCAL_BIN)/sbx-up

	@echo
	@if echo "$$PATH" | tr ':' '\n' | grep -qx "$(LOCAL_BIN)"; then \
		echo "✓ sbx-up installed at $(LOCAL_BIN)/sbx-up"; \
	else \
		echo "sbx-up installed at $(LOCAL_BIN)/sbx-up"; \
		echo "Add this to your shell rc to put it on PATH:"; \
		echo "  export PATH=\"$$HOME/.local/bin:$$PATH\""; \
	fi
```

We'll un-comment these lines in the phase that adds each dependency.

- [ ] **Step 3: Run setup**

Run: `make setup`
Expected: creates `~/.config/agent-sandbox/`, `~/.cache/agent-sandbox/`, `~/.local/bin/sbx-up` (symlink to repo). Prints either `✓ sbx-up installed` or the PATH-add hint.

- [ ] **Step 4: Verify symlink and PATH**

Run: `ls -la ~/.local/bin/sbx-up`
Expected: `~/.local/bin/sbx-up -> <repo>/bin/sbx-up`

If `~/.local/bin` is on PATH:
Run: `sbx-up`
Expected stderr: `sbx-up: not yet implemented (Phase 1 stub)`

If not on PATH, add the printed line to your shell rc, open a new shell, then verify.

- [ ] **Step 5: Verify idempotency**

Run: `make setup` a second time
Expected: same output, no errors, `ln -sf` overwrites cleanly.

- [ ] **Step 6: Commit**

```bash
git add Makefile
git commit -m "feat: add Makefile setup target with sbx-up symlink and PATH check"
```

### Task 1.4: Re-enable brew bundle in Makefile

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Un-comment the `brew bundle` lines**

Change:
```make
	# @echo "==> brew bundle"
	# brew bundle --file=$(REPO)/Brewfile
```
to:
```make
	@echo "==> brew bundle"
	brew bundle --file=$(REPO)/Brewfile
```

- [ ] **Step 2: Run setup**

Run: `make setup`
Expected: `brew bundle` runs, installs anything from `Brewfile` not yet present (ollama, sbx, mise, gh, jq, uv, bats-core). Subsequent runs are fast no-ops.

- [ ] **Step 3: Verify all tools present**

Run: `which ollama sbx mise gh jq uv bats`
Expected: a path printed for each.

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "feat: enable brew bundle in make setup"
```

---

## Phase 2: Sandbox image

End state: `sbx build -t agent-sandbox image/` succeeds. `sbx run --image agent-sandbox -- bash -c 'pi --version && mise --version && uv --version && git --version && rg --version'` prints versions for all tools.

Tasks in this phase use the answers from Phase 0 (Pi install method, base image, AGENTS.md path, models.json path).

### Task 2.1: Write minimal Dockerfile (base + system tools)

**Files:**
- Create: `image/Dockerfile`

- [ ] **Step 1: Write the Dockerfile**

Use the base image chosen in Task 0.4. This example uses `debian:bookworm-slim`; substitute if you chose differently.

```dockerfile
# syntax=docker/dockerfile:1.6
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      gnupg \
      jq \
      ripgrep \
      bash \
      zsh \
      gettext-base \
    && rm -rf /var/lib/apt/lists/*
```

`gettext-base` is for `envsubst`, used later in the entrypoint.

- [ ] **Step 2: Verify it builds**

Run: `sbx build -t agent-sandbox image/` (use the actual `sbx build` flags from Task 0.3 if they differ from `-t`)
Expected: image builds successfully.

- [ ] **Step 3: Verify tools present**

Run: `sbx run --image agent-sandbox -- bash -c 'git --version && rg --version && jq --version'` (use actual `sbx run` flags from Task 0.3)
Expected: versions print for git, rg, jq. Exit 0.

- [ ] **Step 4: Commit**

```bash
git add image/Dockerfile
git commit -m "feat: add minimal sandbox image with base tooling"
```

### Task 2.2: Add mise and uv to image

**Files:**
- Modify: `image/Dockerfile`

- [ ] **Step 1: Add mise and uv install steps**

Append to the Dockerfile after the apt-get block:

```dockerfile
# mise (per https://mise.jdx.dev install instructions)
RUN curl -fsSL https://mise.run | sh \
    && mv /root/.local/bin/mise /usr/local/bin/mise

# uv (per https://docs.astral.sh/uv install instructions)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mv /root/.local/bin/uv /root/.local/bin/uvx /usr/local/bin/
```

If the install scripts above have moved or changed at impl time, use the canonical install command from each tool's current docs.

- [ ] **Step 2: Rebuild image**

Run: `sbx build -t agent-sandbox image/`
Expected: builds successfully.

- [ ] **Step 3: Verify mise and uv present**

Run: `sbx run --image agent-sandbox -- bash -c 'mise --version && uv --version'`
Expected: both versions print.

- [ ] **Step 4: Commit**

```bash
git add image/Dockerfile
git commit -m "feat: install mise and uv in sandbox image"
```

### Task 2.3: Add gh CLI to image

**Files:**
- Modify: `image/Dockerfile`

- [ ] **Step 1: Add gh install step**

Append (use the official gh apt repo install):

```dockerfile
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*
```

- [ ] **Step 2: Rebuild and verify**

Run: `sbx build -t agent-sandbox image/`
Run: `sbx run --image agent-sandbox -- gh --version`
Expected: gh version prints.

- [ ] **Step 3: Commit**

```bash
git add image/Dockerfile
git commit -m "feat: install gh CLI in sandbox image"
```

### Task 2.4: Add Pi to image

**Files:**
- Modify: `image/Dockerfile`

- [ ] **Step 1: Add Pi install step using the method from Task 0.2**

Use the verified install command from `docs/superpowers/notes/research-notes.md`. Example shapes:

If Pi is npm-based:
```dockerfile
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @obra/pi
```

If Pi is a release tarball:
```dockerfile
RUN curl -fsSL -o /tmp/pi.tar.gz https://github.com/obra/pi/releases/latest/download/pi-linux-x86_64.tar.gz \
    && tar -xzf /tmp/pi.tar.gz -C /usr/local/bin pi \
    && rm /tmp/pi.tar.gz \
    && chmod +x /usr/local/bin/pi
```

If Pi is pipx-based:
```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends pipx \
    && rm -rf /var/lib/apt/lists/* \
    && PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install obra-pi
```

Use the actual install command from your research notes.

- [ ] **Step 2: Rebuild and verify**

Run: `sbx build -t agent-sandbox image/`
Run: `sbx run --image agent-sandbox -- pi --version` (or `pi --help` if `--version` is unsupported)
Expected: prints version or help text. Exit 0.

- [ ] **Step 3: Commit**

```bash
git add image/Dockerfile
git commit -m "feat: install Pi in sandbox image"
```

### Task 2.5: Add superpowers skills to image

**Files:**
- Modify: `image/Dockerfile`

- [ ] **Step 1: Clone obra/superpowers into the path Pi expects**

Use the path from Task 0.2's research. Example assumes Pi reads from `~/.config/pi/skills/`:

```dockerfile
RUN git clone --depth 1 https://github.com/obra/superpowers.git /etc/agent-sandbox/superpowers \
    && mkdir -p /root/.config/pi \
    && ln -s /etc/agent-sandbox/superpowers /root/.config/pi/skills
```

Adjust the link target to match the path Pi actually expects, per your notes.

- [ ] **Step 2: Rebuild and verify**

Run: `sbx build -t agent-sandbox image/`
Run: `sbx run --image agent-sandbox -- bash -c 'ls /root/.config/pi/skills/ | head -5'`
Expected: lists some directories from `obra/superpowers` (e.g. `brainstorming`, `writing-plans`).

- [ ] **Step 3: Commit**

```bash
git add image/Dockerfile
git commit -m "feat: clone obra/superpowers into image"
```

### Task 2.6: Bake AGENTS.md and models.json template into image

**Files:**
- Create: `image/AGENTS.md`
- Create: `image/models.json`
- Modify: `image/Dockerfile`

- [ ] **Step 1: Write `image/AGENTS.md`**

```markdown
# Agent context

You are running inside an sbx microVM on the user's Mac.

## Model

Your model is served by Ollama on the host at `http://${LAN_IP}:11434`.
The exact model tag is configured in `models.json`. The host is reached over
the LAN (loopback inside the VM does not route to the host), so `${LAN_IP}` is
the host's current Wi-Fi or Ethernet IP, regenerated on every sandbox launch.

## Sandbox semantics

- This VM is the safety boundary. You may run any shell command without asking
  the user for permission. You will not damage the host.
- `/workspace` is the user's project, mounted read-write from the host. Edits
  there modify the user's real files.
- The rest of the filesystem is per-workspace persistent state. Anything you
  install or write outside `/workspace` survives across `sbx-up` invocations
  for this project, but is isolated from other projects.

## Network

Outbound network is restricted by policy. Allowed:
- The model endpoint (`${LAN_IP}:11434`)
- A small allowlist of package registries (npm, PyPI, GitHub, ghcr.io)

Other hosts will refuse the connection. If you need a host added, ask the user
to update `policy/network.tmpl` in the agent-sandbox repo.
```

- [ ] **Step 2: Write `image/models.json`**

The exact shape depends on Pi's config schema (Task 0.2). If Pi reads `models.json`, write the template using `${LAN_IP}` as a literal placeholder for `envsubst`:

```json
{
  "default": "qwen3.6",
  "models": {
    "qwen3.6": {
      "provider": "ollama",
      "endpoint": "http://${LAN_IP}:11434",
      "model": "qwen3.6:35b-a3b"
    }
  }
}
```

Replace the `model` value with the exact tag from your Task 0.4 research. Adjust the schema if Pi expects a different shape.

If your Task 0.2 research shows Pi reads `PI_MODEL_ENDPOINT` instead of a JSON file, skip writing `models.json` — the env var path is simpler. Document this decision in the notes file and proceed with that approach in subsequent tasks.

- [ ] **Step 3: Add COPY directives to Dockerfile**

Append to `image/Dockerfile`. Adjust target paths to match Pi's expectations from Task 0.2.

```dockerfile
COPY AGENTS.md /root/.config/pi/AGENTS.md
COPY models.json /etc/agent-sandbox/models.json.tmpl
```

(The `.tmpl` suffix is intentional — the entrypoint will `envsubst` it into `~/.config/pi/models.json` at boot.)

- [ ] **Step 4: Rebuild and verify**

Run: `sbx build -t agent-sandbox image/`
Run: `sbx run --image agent-sandbox -- bash -c 'cat /root/.config/pi/AGENTS.md | head -3 && cat /etc/agent-sandbox/models.json.tmpl'`
Expected: prints first lines of AGENTS.md and the full models.json.tmpl content (still containing `${LAN_IP}` placeholder).

- [ ] **Step 5: Commit**

```bash
git add image/AGENTS.md image/models.json image/Dockerfile
git commit -m "feat: bake AGENTS.md and models.json template into image"
```

### Task 2.7: Re-enable sbx build in Makefile

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Un-comment the `sbx build` lines**

Change:
```make
	# @echo "==> sbx build"
	# sbx build -t agent-sandbox $(REPO)/image/
```
to:
```make
	@echo "==> sbx build"
	sbx build -t agent-sandbox $(REPO)/image/
```

- [ ] **Step 2: Verify**

Run: `make setup`
Expected: brew bundle is a no-op, sbx build is fast (cached layers), config dirs exist, symlink in place.

- [ ] **Step 3: Commit**

```bash
git add Makefile
git commit -m "feat: enable sbx build in make setup"
```

---

## Phase 3: sbx-up — Ollama and LAN IP

End state: running `sbx-up` (still without the `sbx run` invocation at the end) discovers the LAN IP, ensures Ollama is up on it, and ensures the model is pulled. Bats tests cover the pure functions.

### Task 3.1: Restructure sbx-up into testable functions

**Files:**
- Modify: `bin/sbx-up`

- [ ] **Step 1: Replace the stub with the function skeleton**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Constants. Edit here if you ever need to change them.
MODEL_TAG="qwen3.6:35b-a3b"   # confirm exact tag from research-notes.md
OLLAMA_PORT=11434
CONFIG_DIR="${HOME}/.config/agent-sandbox"
CACHE_DIR="${HOME}/.cache/agent-sandbox"

discover_lan_ip() {
  local ip
  ip=$(ipconfig getifaddr en0 2>/dev/null || true)
  [[ -z "$ip" ]] && ip=$(ipconfig getifaddr en1 2>/dev/null || true)
  [[ -z "$ip" ]] && return 1
  echo "$ip"
}

ollama_is_up() {
  local ip="$1"
  curl -fsS --max-time 1 "http://${ip}:${OLLAMA_PORT}/api/tags" >/dev/null 2>&1
}

start_ollama() {
  local ip="$1"
  mkdir -p "$CACHE_DIR"
  OLLAMA_HOST="${ip}:${OLLAMA_PORT}" nohup ollama serve \
    > "${CACHE_DIR}/ollama.log" 2>&1 &
  for _ in $(seq 1 30); do
    ollama_is_up "$ip" && return 0
    sleep 0.5
  done
  return 1
}

ensure_model() {
  if ollama list | awk 'NR>1 {print $1}' | grep -qx "$MODEL_TAG"; then
    return 0
  fi
  echo "First run — pulling $MODEL_TAG (large download, ~22GB)…" >&2
  ollama pull "$MODEL_TAG"
}

main() {
  local ip
  ip=$(discover_lan_ip) || {
    echo "No LAN IP on en0/en1. On VPN? Cable unplugged?" >&2
    exit 1
  }
  echo "LAN_IP=$ip" >&2

  if ! ollama_is_up "$ip"; then
    start_ollama "$ip" || {
      echo "Ollama failed to start. Last log lines:" >&2
      tail -n 20 "${CACHE_DIR}/ollama.log" >&2
      exit 1
    }
  fi

  ensure_model

  echo "OK so far (sandbox launch added in Phase 4)" >&2
}

# Allow sourcing for tests without running main.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
```

- [ ] **Step 2: Verify it parses**

Run: `bash -n bin/sbx-up`
Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
git add bin/sbx-up
git commit -m "feat: restructure sbx-up into testable functions"
```

### Task 3.2: Write bats test for discover_lan_ip

**Files:**
- Create: `tests/sbx-up.bats`

- [ ] **Step 1: Write the failing test**

```bash
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
```

- [ ] **Step 2: Run tests, verify they fail in a meaningful way**

Run: `bats tests/sbx-up.bats`
Expected: tests run. They may pass on macOS where `ipconfig` exists (the function override may not take effect because `set -e` in the sourced script stops execution). If they fail, that's fine — we have a working test harness.

If the script fails to source because `main "$@"` runs with no args: confirm the `BASH_SOURCE`-vs-`$0` guard at the bottom is working. Bats sources the script, so `BASH_SOURCE[0]` differs from `$0` (which is bats), so `main` should not run.

- [ ] **Step 3: Commit**

```bash
git add tests/sbx-up.bats
git commit -m "test: add bats tests for discover_lan_ip"
```

### Task 3.3: Test ollama_is_up

**Files:**
- Modify: `tests/sbx-up.bats`

- [ ] **Step 1: Append tests for ollama_is_up**

```bash
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
```

- [ ] **Step 2: Run tests**

Run: `bats tests/sbx-up.bats`
Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add tests/sbx-up.bats
git commit -m "test: add bats tests for ollama_is_up"
```

### Task 3.4: Manual end-to-end verification of Ollama startup

This is a manual smoke test, not a bats test, because `ollama serve` is a real external process.

- [ ] **Step 1: Make sure no stray Ollama is running**

Run: `pkill -f "ollama serve" || true`

- [ ] **Step 2: Run sbx-up via the symlink**

Run: `sbx-up`
Expected stderr lines (in order):
```
LAN_IP=<your.lan.ip>
First run — pulling qwen3.6:35b-a3b … (only on first run)
OK so far (sandbox launch added in Phase 4)
```
On subsequent runs, the "First run" line is absent.

- [ ] **Step 3: Verify Ollama is reachable from the host**

Run: `curl -s http://$(ipconfig getifaddr en0):11434/api/tags | jq '.'`
Expected: JSON listing models. The qwen tag should be present after the first pull.

- [ ] **Step 4: Verify ollama.log contains startup output**

Run: `tail -n 5 ~/.cache/agent-sandbox/ollama.log`
Expected: Ollama startup logs.

- [ ] **Step 5: Re-run sbx-up to verify idempotency**

Run: `sbx-up`
Expected: skips the "First run" pull and Ollama startup (probe finds it already up).

No commit for this task — it's pure verification, no code changes.

---

## Phase 4: Network policy and sandbox launch

End state: `sbx-up` writes a per-invocation network policy with the current LAN IP, then `exec`s `sbx run` with the workspace mounted and `LAN_IP` env injected. Inside the VM, the model endpoint is reachable; an out-of-allowlist host like `example.com` is denied.

### Task 4.1: Write network policy template

**Files:**
- Create: `policy/network.tmpl`

- [ ] **Step 1: Write the template**

The exact format depends on Task 0.3 research. Example assumes JSON, default-deny:

```json
{
  "default": "deny",
  "allow": [
    { "host": "${LAN_IP}", "port": 11434, "proto": "tcp" },
    { "host": "registry.npmjs.org", "port": 443 },
    { "host": "pypi.org", "port": 443 },
    { "host": "files.pythonhosted.org", "port": 443 },
    { "host": "github.com", "port": 443 },
    { "host": "objects.githubusercontent.com", "port": 443 },
    { "host": "ghcr.io", "port": 443 },
    { "host": "api.github.com", "port": 443 }
  ]
}
```

If `sbx`'s policy format is different (YAML, TOML, a flat allowlist file), adjust the structure accordingly using the format from your notes.

- [ ] **Step 2: Verify the template is valid for whatever format sbx expects**

If JSON: `jq . policy/network.tmpl` (after substituting the placeholder for a fake IP, since `${LAN_IP}` isn't valid JSON):
```bash
sed 's/${LAN_IP}/0.0.0.0/' policy/network.tmpl | jq .
```
Expected: pretty-printed JSON, exit 0.

- [ ] **Step 3: Commit**

```bash
git add policy/network.tmpl
git commit -m "feat: add network policy template"
```

### Task 4.2: Re-enable policy copy in Makefile and run setup

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Un-comment the cp line**

Change:
```make
	# cp $(REPO)/policy/network.tmpl $(CONFIG_DIR)/network.tmpl
```
to:
```make
	cp $(REPO)/policy/network.tmpl $(CONFIG_DIR)/network.tmpl
```

- [ ] **Step 2: Run setup**

Run: `make setup`
Expected: copies the template to `~/.config/agent-sandbox/network.tmpl`.

- [ ] **Step 3: Verify**

Run: `cat ~/.config/agent-sandbox/network.tmpl`
Expected: matches the repo file.

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "feat: enable policy template copy in make setup"
```

### Task 4.3: Add generate_policy function to sbx-up with test

**Files:**
- Modify: `bin/sbx-up`
- Modify: `tests/sbx-up.bats`

- [ ] **Step 1: Add the function to sbx-up**

Insert after `ensure_model`:

```bash
generate_policy() {
  local ip="$1" template="$2" out="$3"
  sed "s|\${LAN_IP}|${ip}|g" "$template" > "$out"
}
```

- [ ] **Step 2: Append a test**

Append to `tests/sbx-up.bats`:

```bash
@test "generate_policy substitutes LAN_IP placeholder" {
  local tmpdir; tmpdir=$(mktemp -d)
  printf '{"host": "${LAN_IP}", "port": 11434}\n' > "$tmpdir/in.tmpl"

  generate_policy "192.168.1.50" "$tmpdir/in.tmpl" "$tmpdir/out.json"
  run cat "$tmpdir/out.json"
  [ "$status" -eq 0 ]
  [ "$output" = '{"host": "192.168.1.50", "port": 11434}' ]

  rm -rf "$tmpdir"
}
```

- [ ] **Step 3: Run tests**

Run: `bats tests/sbx-up.bats`
Expected: all tests pass, including the new one.

- [ ] **Step 4: Commit**

```bash
git add bin/sbx-up tests/sbx-up.bats
git commit -m "feat: add generate_policy function with test"
```

### Task 4.4: Wire generate_policy and sbx run into main()

**Files:**
- Modify: `bin/sbx-up`

- [ ] **Step 1: Replace the placeholder in main()**

Change the bottom of `main()` from:
```bash
  ensure_model

  echo "OK so far (sandbox launch added in Phase 4)" >&2
}
```
to:
```bash
  ensure_model

  local policy="${CACHE_DIR}/network-current.json"
  generate_policy "$ip" "${CONFIG_DIR}/network.tmpl" "$policy"

  if [[ "${1:-}" == "--rebuild" ]]; then
    local repo
    repo=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")
    sbx build -t agent-sandbox "${repo}/image/"
    shift
  fi

  exec sbx run \
    --image agent-sandbox \
    --policy "$policy" \
    --mount "$PWD:/workspace" \
    --env "LAN_IP=$ip"
}
```

Adjust the `sbx run` flags to match the actual flag names from Task 0.3. If `sbx` uses `-v` instead of `--mount`, swap. If env injection is `-e` instead of `--env`, swap.

- [ ] **Step 2: Verify it parses**

Run: `bash -n bin/sbx-up`
Expected: no output.

- [ ] **Step 3: Run sbx-up from a test directory**

```bash
cd /tmp && mkdir -p sbx-test && cd sbx-test
sbx-up
```
Expected: drops you into a shell inside the VM. `pwd` returns `/workspace`. `echo $LAN_IP` returns your host's LAN IP. `pi --version` prints Pi's version.

- [ ] **Step 4: Verify the model endpoint is reachable from inside the VM**

Inside the VM:
```bash
curl -s "http://$LAN_IP:11434/api/tags" | head -c 200
```
Expected: JSON model list output.

- [ ] **Step 5: Verify network policy denies non-allowlisted hosts**

Inside the VM:
```bash
curl -fsS --max-time 3 https://example.com >/dev/null && echo ALLOWED || echo DENIED
```
Expected: `DENIED` (or a connection failure exit code).

- [ ] **Step 6: Exit the sandbox**

Inside the VM: `exit`
Expected: returns to host shell. State is persisted by sbx; no cleanup needed.

- [ ] **Step 7: Commit**

```bash
git add bin/sbx-up
git commit -m "feat: wire policy generation and sbx run into sbx-up"
```

### Task 4.5: Add --rebuild smoke test

- [ ] **Step 1: Make a trivial change to image/Dockerfile**

Add a comment line at the end of `image/Dockerfile`:
```dockerfile
# rebuild marker
```

- [ ] **Step 2: Run sbx-up --rebuild**

Run: `sbx-up --rebuild`
Expected: runs `sbx build` first (visible output), then launches sandbox as normal.

- [ ] **Step 3: Revert the Dockerfile change**

Run: `git checkout image/Dockerfile`

No commit needed — this was a verification, not a code change.

---

## Phase 5: Entrypoint first-boot logic

End state: every `sbx-up` re-renders `models.json` from the env var. If `/workspace/mise.toml` exists, `mise install` runs the first time and any time the file changes (hash-gated). Same for `/workspace/.sbx/postCreate.sh`.

### Task 5.1: Write entrypoint skeleton with envsubst

**Files:**
- Create: `image/entrypoint.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${HOME}/.sandbox"

main() {
  mkdir -p "$STATE_DIR"

  # Render models.json from template using LAN_IP injected by sbx run.
  if [[ -f /etc/agent-sandbox/models.json.tmpl ]]; then
    : "${LAN_IP:?LAN_IP env var not set; sbx-up should pass it}"
    mkdir -p "${HOME}/.config/pi"
    envsubst < /etc/agent-sandbox/models.json.tmpl > "${HOME}/.config/pi/models.json"
  fi

  cd /workspace 2>/dev/null || cd "$HOME"
  exec "${SHELL:-/bin/bash}" -l
}

# Allow sourcing for tests without running main.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
```

If your Task 0.2 research showed Pi reads `PI_MODEL_ENDPOINT` env var instead, replace the `envsubst` block with:

```bash
export PI_MODEL_ENDPOINT="http://${LAN_IP}:11434"
```

and skip writing `models.json`.

- [ ] **Step 2: Make it executable**

Run: `chmod +x image/entrypoint.sh`

- [ ] **Step 3: Commit**

```bash
git add image/entrypoint.sh
git commit -m "feat: add entrypoint with models.json rendering"
```

### Task 5.2: Wire entrypoint into Dockerfile

**Files:**
- Modify: `image/Dockerfile`

- [ ] **Step 1: Append COPY and ENTRYPOINT**

```dockerfile
COPY entrypoint.sh /usr/local/bin/sandbox-entrypoint
RUN chmod +x /usr/local/bin/sandbox-entrypoint

ENTRYPOINT ["/usr/local/bin/sandbox-entrypoint"]
```

Note: `ENTRYPOINT` may interact with `sbx run`'s default behavior. If `sbx run` ignores the image's ENTRYPOINT in favor of its own, you may need to invoke the entrypoint via `sbx run --image agent-sandbox -- /usr/local/bin/sandbox-entrypoint`. Check your Task 0.3 research notes; adjust the `exec sbx run` line in `bin/sbx-up` if needed.

- [ ] **Step 2: Rebuild image**

Run: `sbx build -t agent-sandbox image/`
Expected: builds successfully.

- [ ] **Step 3: Run sbx-up from a test dir, verify models.json is rendered**

```bash
cd /tmp/sbx-test && sbx-up
```
Inside the VM:
```bash
cat ~/.config/pi/models.json
```
Expected: JSON content with `${LAN_IP}` substituted with your actual IP.

Exit the VM.

- [ ] **Step 4: Commit**

```bash
git add image/Dockerfile
git commit -m "feat: wire entrypoint into image"
```

### Task 5.3: Add hash-gated mise install to entrypoint

**Files:**
- Modify: `image/entrypoint.sh`

- [ ] **Step 1: Insert the hash-gated mise block inside `main()`, before the `cd /workspace` / `exec` lines**

```bash
  # Hash-gated `mise install` for /workspace/mise.toml.
  if [[ -f /workspace/mise.toml ]]; then
    new_hash=$(sha256sum /workspace/mise.toml | cut -c1-16)
    old_hash=$(cat "${STATE_DIR}/mise.hash" 2>/dev/null || true)
    if [[ "$new_hash" != "$old_hash" ]]; then
      echo "==> mise.toml changed (or first run); installing toolchain" >&2
      (cd /workspace && mise install)
      echo "$new_hash" > "${STATE_DIR}/mise.hash"
    fi
  fi
```

- [ ] **Step 2: Rebuild image**

Run: `sbx build -t agent-sandbox image/`

- [ ] **Step 3: Verify on a project without mise.toml**

```bash
cd /tmp/sbx-test && sbx-up
```
Inside the VM: shouldn't see the "mise.toml changed" line. Exit.

- [ ] **Step 4: Verify on a project with mise.toml**

```bash
cd /tmp && mkdir -p sbx-mise-test && cd sbx-mise-test
cat > mise.toml <<'EOF'
[tools]
node = "20"
EOF
sbx-up
```
Inside the VM: should see "==> mise.toml changed (or first run); installing toolchain" and `mise install` output. Verify Node 20 is installed:
```bash
node --version
```
Expected: `v20.x.x`.

Exit, run `sbx-up` again. Should NOT see the install line (hash matches).

- [ ] **Step 5: Edit mise.toml, verify re-run**

On the host:
```bash
cat > /tmp/sbx-mise-test/mise.toml <<'EOF'
[tools]
node = "22"
EOF
cd /tmp/sbx-mise-test && sbx-up
```
Inside the VM: should see install line. `node --version` reports `v22.x.x`. Exit.

- [ ] **Step 6: Commit**

```bash
git add image/entrypoint.sh
git commit -m "feat: hash-gated mise install in entrypoint"
```

### Task 5.4: Add hash-gated postCreate.sh to entrypoint

**Files:**
- Modify: `image/entrypoint.sh`

- [ ] **Step 1: Insert the postCreate block inside `main()`, after the mise block**

```bash
  # Hash-gated /workspace/.sbx/postCreate.sh.
  if [[ -f /workspace/.sbx/postCreate.sh ]]; then
    new_hash=$(sha256sum /workspace/.sbx/postCreate.sh | cut -c1-16)
    old_hash=$(cat "${STATE_DIR}/postcreate.hash" 2>/dev/null || true)
    if [[ "$new_hash" != "$old_hash" ]]; then
      echo "==> .sbx/postCreate.sh changed (or first run); running" >&2
      bash /workspace/.sbx/postCreate.sh
      echo "$new_hash" > "${STATE_DIR}/postcreate.hash"
    fi
  fi
```

- [ ] **Step 2: Rebuild image**

Run: `sbx build -t agent-sandbox image/`

- [ ] **Step 3: Verify with a sample postCreate.sh**

On the host:
```bash
mkdir -p /tmp/sbx-mise-test/.sbx
cat > /tmp/sbx-mise-test/.sbx/postCreate.sh <<'EOF'
#!/usr/bin/env bash
echo "postCreate ran at $(date)" >> ~/.postcreate.log
EOF
chmod +x /tmp/sbx-mise-test/.sbx/postCreate.sh
cd /tmp/sbx-mise-test && sbx-up
```
Inside the VM:
```bash
cat ~/.postcreate.log
```
Expected: one line with a timestamp. Exit, run `sbx-up` again — should NOT re-run (hash matches), `~/.postcreate.log` still has one line.

- [ ] **Step 4: Edit postCreate.sh, verify re-run**

```bash
echo '# bumped' >> /tmp/sbx-mise-test/.sbx/postCreate.sh
cd /tmp/sbx-mise-test && sbx-up
```
Inside the VM: `cat ~/.postcreate.log` now has two lines.

- [ ] **Step 5: Commit**

```bash
git add image/entrypoint.sh
git commit -m "feat: hash-gated postCreate.sh in entrypoint"
```

### Task 5.5: Add bats tests for entrypoint hash logic

**Files:**
- Create: `tests/entrypoint.bats`

- [ ] **Step 1: Refactor entrypoint.sh to extract `run_hash_gated`**

Replace the two duplicated blocks inside `main()` with a single helper. Define this function at file scope (above `main()`) so it's available when the script is sourced for testing:

```bash
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
```

Replace the two inline blocks inside `main()` with:

```bash
  run_hash_gated /workspace/mise.toml \
    "${STATE_DIR}/mise.hash" "mise.toml" \
    '(cd /workspace && mise install)'

  run_hash_gated /workspace/.sbx/postCreate.sh \
    "${STATE_DIR}/postcreate.hash" ".sbx/postCreate.sh" \
    'bash /workspace/.sbx/postCreate.sh'
```

The `BASH_SOURCE` guard added in Task 5.1 already ensures sourcing for tests doesn't run `main()`, so the `run_hash_gated` function is exposed cleanly.

- [ ] **Step 2: Write the bats file**

```bash
#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/../image/entrypoint.sh"
  WORKDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$WORKDIR"
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
```

- [ ] **Step 3: Run tests**

Run: `bats tests/entrypoint.bats`
Expected: all 4 tests pass.

- [ ] **Step 4: Commit**

```bash
git add image/entrypoint.sh tests/entrypoint.bats
git commit -m "test: refactor entrypoint to expose run_hash_gated and add tests"
```

---

## Phase 6: End-to-end verification and README

End state: a real run of Pi inside the sandbox successfully gets a response from Qwen via the host Ollama. README documents the basic usage.

### Task 6.1: End-to-end smoke test

This is a manual verification, no code changes.

- [ ] **Step 1: Reset to a clean state**

Run on the host:
```bash
pkill -f "ollama serve" || true
rm -rf /tmp/sbx-e2e
mkdir -p /tmp/sbx-e2e
cd /tmp/sbx-e2e
git init -q
echo "# test repo" > README.md
git add README.md && git commit -q -m "init"
```

- [ ] **Step 2: Launch sbx-up**

Run: `sbx-up`
Expected: discovers LAN IP, starts Ollama (logs go to `~/.cache/agent-sandbox/ollama.log`), confirms model present, generates network policy, drops you into a shell at `/workspace`.

- [ ] **Step 3: Verify Pi can reach the model**

Inside the VM:
```bash
curl -fsS "http://$LAN_IP:11434/api/tags" | jq '.models[].name'
```
Expected: includes the qwen tag.

- [ ] **Step 4: Run a Pi prompt**

Inside the VM:
```bash
echo "Say 'hello from sbx' and nothing else." | pi
```
(Adjust the invocation to match Pi's actual CLI surface from your notes — may be `pi prompt`, `pi run`, or a flag like `pi -p`.)

Expected: Pi responds with text containing "hello from sbx" or similar. The response comes from Qwen via host Ollama.

- [ ] **Step 5: Verify state persistence**

Inside the VM:
```bash
echo "test marker $(date)" > ~/.persistence-check
exit
```

Run `sbx-up` from `/tmp/sbx-e2e` again. Inside the VM:
```bash
cat ~/.persistence-check
```
Expected: the timestamp from the previous run.

- [ ] **Step 6: Verify cross-workspace isolation**

```bash
exit
mkdir -p /tmp/sbx-other && cd /tmp/sbx-other && sbx-up
```
Inside the VM:
```bash
ls ~/.persistence-check 2>&1 || echo "isolated"
```
Expected: `isolated` (file from the other workspace's state is not visible).

Exit. No commit — this was verification.

### Task 6.2: Write the README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write a minimal README**

```markdown
# agent-sandbox

Personal infra: Pi running in an sbx microVM, talking to Qwen served by host Ollama.

## Setup (once)

```
make setup
```

Installs host deps via Homebrew, builds the sandbox image, drops a network policy template in `~/.config/agent-sandbox/`, and symlinks `sbx-up` into `~/.local/bin/`. If `~/.local/bin` isn't on your `PATH`, the printed instructions tell you how to add it.

## Daily use

From any project directory on the host:

```
sbx-up
```

This:
1. Discovers your current LAN IP.
2. Starts Ollama bound to it (if not already running).
3. Pulls the Qwen model on first run.
4. Generates a per-invocation network policy.
5. Drops you into a shell inside the sandbox, with the project mounted at `/workspace` and `pi` on `$PATH`.

Use `sbx-up --rebuild` to rebuild the image (e.g. after editing `image/Dockerfile`).

## Per-project setup

- `mise.toml` at the workspace root: toolchain installed automatically on first boot. Re-runs on edit.
- `.sbx/postCreate.sh` at the workspace root: runs once per workspace, re-runs on edit. Make it idempotent.

## Files of interest

- `bin/sbx-up` — the launcher.
- `image/Dockerfile` — the sandbox image.
- `image/entrypoint.sh` — first-boot logic inside the VM.
- `policy/network.tmpl` — outbound network allowlist (default-deny).

See `docs/superpowers/specs/2026-05-05-agent-sandbox-design.md` for the full design.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README"
```

### Task 6.3: Final sanity sweep

- [ ] **Step 1: Run all bats tests**

Run: `bats tests/`
Expected: all tests pass.

- [ ] **Step 2: Run shellcheck on all bash**

Run: `shellcheck bin/sbx-up image/entrypoint.sh`
(Install via `brew install shellcheck` if not already present.)
Expected: no errors. Warnings are OK; address obvious ones, ignore stylistic ones.

- [ ] **Step 3: Verify make setup is fully idempotent on a clean checkout**

```bash
cd $(mktemp -d) && git clone <this-repo> agent-sandbox && cd agent-sandbox && make setup
```
Expected: completes cleanly, all steps run.

- [ ] **Step 4: Verify final tree**

Run: `git ls-files | sort`
Expected files include:
```
Brewfile
LICENSE
Makefile
README.md
bin/sbx-up
docs/superpowers/notes/research-notes.md
docs/superpowers/plans/2026-05-05-agent-sandbox.md
docs/superpowers/specs/2026-05-05-agent-sandbox-design.md
image/AGENTS.md
image/Dockerfile
image/entrypoint.sh
image/models.json
policy/network.tmpl
tests/entrypoint.bats
tests/sbx-up.bats
```

No commit — this is verification only.

---

## Self-review notes (for the engineer)

- Phase 0 outputs feed Phases 2 and 5. Don't skip it; the placeholders below ("if Pi is npm…", "if Pi reads env var…") collapse into one concrete answer once research is done.
- Tasks that say "adjust the flag if your sbx differs" mean exactly that — `sbx`'s flag surface is one of the open questions. Read your notes; don't guess from this plan.
- Each phase ends in a verifiable state. If a verification step fails, do not move to the next phase. Diagnose first.
- The `--rebuild` flag is a bonus convenience. If it's a pain to wire, drop it and tell the user to run `sbx build -t agent-sandbox image/` directly.
