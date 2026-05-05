# agent-sandbox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a small personal repo that lets `sbx-up` (run from any project on the host Mac) drop the user into an sbx microVM where Pi can talk to Qwen served by host Ollama.

**Architecture:** Two layers. Host: `make setup` installs deps via Homebrew, starts a local Docker registry on `localhost:5000`, builds and pushes the sandbox image, and symlinks `sbx-up` into `~/.local/bin`. `sbx-up` discovers the host's LAN IP, ensures Ollama is bound to it, ensures the qwen model is pulled, allows the LAN IP in the global sbx network policy, writes `${PWD}/.sbx/runtime.env` with the LAN IP, and `exec`s `sbx run --template localhost:5000/agent-sandbox:latest shell`. Image: layered on `docker/sandbox-templates:shell`, pre-baked with Pi + superpowers skills + a `setup.sh` sourced from `/etc/profile.d/` that reads `runtime.env`, renders `models.json`, and runs hash-gated `mise install` and `postCreate.sh`.

**Tech Stack:** bash, make, Homebrew, Docker (registry + image build), sbx, Ollama, bats-core, mise, Pi (npm).

**Source spec:** `docs/superpowers/specs/2026-05-05-agent-sandbox-design.md` (revision v2 — post-Phase 0)

**Phase 0 outputs (already complete):** `docs/superpowers/notes/research-notes.md`

---

## Phase 1: Host setup (Brewfile + Makefile + sbx-up stub)

End state: `make setup` runs cleanly on a fresh Mac, the local Docker registry is running on `localhost:5000`, `which sbx-up` returns the symlink in `~/.local/bin/`, and running `sbx-up` prints a "not yet implemented" message and exits 0.

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

# Docker is needed for `docker build --push localhost:5000/...`. If you
# already have Docker Desktop installed via the .dmg, this brew line is a
# no-op; if you prefer colima, swap to `brew "colima"` plus `brew "docker"`.
brew "docker"
```

- [ ] **Step 2: Verify it parses**

Run: `brew bundle check --file=Brewfile || true`
Expected: either reports missing items or "all dependencies are satisfied". Either is fine — we just want no syntax errors.

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
Expected stderr: `sbx-up: not yet implemented (Phase 1 stub)`. Exit code 0.

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
CACHE_DIR := $(HOME)/.cache/agent-sandbox
REGISTRY_NAME := agent-sandbox-registry
IMAGE := localhost:5000/agent-sandbox:latest

setup:
	@echo "==> brew bundle"
	brew bundle --file=$(REPO)/Brewfile

	@echo "==> local Docker registry"
	@if [ -z "$$(docker ps -aqf name=^$(REGISTRY_NAME)$$)" ]; then \
	  docker run -d --restart=always -p 127.0.0.1:5000:5000 --name $(REGISTRY_NAME) registry:2 ; \
	elif [ -z "$$(docker ps -qf name=^$(REGISTRY_NAME)$$)" ]; then \
	  docker start $(REGISTRY_NAME) ; \
	else \
	  echo "registry already running" ; \
	fi

	@echo "==> docker build --push $(IMAGE)"
	docker build -t $(IMAGE) --push $(REPO)/image/

	@echo "==> host cache dir"
	mkdir -p $(CACHE_DIR)

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

Note: the `docker build --push` step references `image/` which doesn't exist yet. We'll comment that out and re-enable in Phase 2.

- [ ] **Step 2: Temporarily comment out the steps that depend on later phases**

```make
setup:
	# @echo "==> brew bundle"
	# brew bundle --file=$(REPO)/Brewfile

	# @echo "==> local Docker registry"
	# @if [ -z "$$(docker ps -aqf name=^$(REGISTRY_NAME)$$)" ]; then \
	#   docker run -d --restart=always -p 127.0.0.1:5000:5000 --name $(REGISTRY_NAME) registry:2 ; \
	# elif [ -z "$$(docker ps -qf name=^$(REGISTRY_NAME)$$)" ]; then \
	#   docker start $(REGISTRY_NAME) ; \
	# else \
	#   echo "registry already running" ; \
	# fi

	# @echo "==> docker build --push $(IMAGE)"
	# docker build -t $(IMAGE) --push $(REPO)/image/

	@echo "==> host cache dir"
	mkdir -p $(CACHE_DIR)

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

- [ ] **Step 3: Run setup**

Run: `make setup`
Expected: creates `~/.cache/agent-sandbox/`, `~/.local/bin/sbx-up` (symlink). Prints either `✓ sbx-up installed` or the PATH-add hint.

- [ ] **Step 4: Verify symlink**

Run: `ls -la ~/.local/bin/sbx-up`
Expected: `~/.local/bin/sbx-up -> <repo>/bin/sbx-up`.

If `~/.local/bin` is on PATH:
Run: `sbx-up`
Expected stderr: `sbx-up: not yet implemented (Phase 1 stub)`.

- [ ] **Step 5: Verify idempotency**

Run: `make setup` again.
Expected: same output, no errors.

- [ ] **Step 6: Commit**

```bash
git add Makefile
git commit -m "feat: add Makefile setup target"
```

### Task 1.4: Re-enable brew bundle and registry start

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Un-comment `brew bundle` and the registry block**

Replace the four commented sections (`brew bundle` and `local Docker registry`) with their uncommented versions from Task 1.3 Step 1. Leave the `docker build --push` step commented out — that's still Phase 2's job.

- [ ] **Step 2: Run setup**

Run: `make setup`
Expected: `brew bundle` installs anything missing. Local registry container starts on `localhost:5000`.

- [ ] **Step 3: Verify registry**

Run: `curl -fsS http://localhost:5000/v2/_catalog`
Expected: `{"repositories":[]}`.

Run: `docker ps --filter name=agent-sandbox-registry`
Expected: one running container.

- [ ] **Step 4: Verify all tools present**

Run: `which ollama sbx mise gh jq uv bats docker`
Expected: a path printed for each.

- [ ] **Step 5: Commit**

```bash
git add Makefile
git commit -m "feat: enable brew bundle and local Docker registry"
```

---

## Phase 2: Sandbox image

End state: `docker build -t localhost:5000/agent-sandbox:latest --push image/` succeeds. The image extends `docker/sandbox-templates:shell` and pre-installs Pi, mise, uv, gh, ripgrep, jq, plus the baked-in AGENTS.md, models.json template, and setup.sh.

### Task 2.1: Write minimal Dockerfile (base + apt deps)

**Files:**
- Create: `image/Dockerfile`

- [ ] **Step 1: Write the Dockerfile**

```dockerfile
# syntax=docker/dockerfile:1.6
FROM docker/sandbox-templates:shell

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      gnupg \
      jq \
      ripgrep \
      gettext-base \
      nodejs \
      npm \
    && rm -rf /var/lib/apt/lists/*
```

`gettext-base` provides `envsubst` (used by `setup.sh` to render `models.json`).

If `nodejs` from Debian apt is too old for Pi (Pi may need Node 20+), swap to NodeSource:

```dockerfile
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*
```

- [ ] **Step 2: Verify it builds (without push)**

Run: `docker build -t localhost:5000/agent-sandbox:latest image/`
Expected: builds successfully.

- [ ] **Step 3: Smoke-test tools inside the image**

Run: `docker run --rm localhost:5000/agent-sandbox:latest bash -c 'git --version && rg --version && jq --version && envsubst --version'`
Expected: versions print for each. Exit 0.

- [ ] **Step 4: Commit**

```bash
git add image/Dockerfile
git commit -m "feat: minimal sandbox image extending docker/sandbox-templates:shell"
```

### Task 2.2: Add mise and uv

**Files:**
- Modify: `image/Dockerfile`

- [ ] **Step 1: Append mise and uv installs**

```dockerfile
# mise (per https://mise.jdx.dev install instructions)
RUN curl -fsSL https://mise.run | sh \
    && mv /root/.local/bin/mise /usr/local/bin/mise

# uv (per https://docs.astral.sh/uv install instructions)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mv /root/.local/bin/uv /root/.local/bin/uvx /usr/local/bin/
```

If the install scripts have moved or changed at impl time, use the canonical command from each tool's current docs.

- [ ] **Step 2: Rebuild and verify**

Run: `docker build -t localhost:5000/agent-sandbox:latest image/`
Run: `docker run --rm localhost:5000/agent-sandbox:latest bash -c 'mise --version && uv --version'`
Expected: both versions print.

- [ ] **Step 3: Commit**

```bash
git add image/Dockerfile
git commit -m "feat: install mise and uv in image"
```

### Task 2.3: Add gh

**Files:**
- Modify: `image/Dockerfile`

- [ ] **Step 1: Append gh install**

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

Run: `docker build -t localhost:5000/agent-sandbox:latest image/`
Run: `docker run --rm localhost:5000/agent-sandbox:latest gh --version`
Expected: gh version prints.

- [ ] **Step 3: Commit**

```bash
git add image/Dockerfile
git commit -m "feat: install gh CLI in image"
```

### Task 2.4: Install Pi globally

**Files:**
- Modify: `image/Dockerfile`

- [ ] **Step 1: Append Pi install**

```dockerfile
RUN npm install -g @mariozechner/pi-coding-agent
```

- [ ] **Step 2: Rebuild and verify**

Run: `docker build -t localhost:5000/agent-sandbox:latest image/`
Run: `docker run --rm localhost:5000/agent-sandbox:latest pi --help`
Expected: Pi help text. Exit 0.

If `pi --help` fails because Pi insists on a config file or model setup before printing help, try `which pi`:
Run: `docker run --rm localhost:5000/agent-sandbox:latest which pi`
Expected: a path to the binary.

- [ ] **Step 3: Commit**

```bash
git add image/Dockerfile
git commit -m "feat: install Pi (npm: @mariozechner/pi-coding-agent)"
```

### Task 2.5: Clone obra/superpowers

**Files:**
- Modify: `image/Dockerfile`

- [ ] **Step 1: Append the clone**

```dockerfile
RUN git clone --depth 1 https://github.com/obra/superpowers.git /etc/agent-sandbox/superpowers
```

- [ ] **Step 2: Rebuild and verify**

Run: `docker build -t localhost:5000/agent-sandbox:latest image/`
Run: `docker run --rm localhost:5000/agent-sandbox:latest bash -c 'ls /etc/agent-sandbox/superpowers/skills 2>/dev/null | head -5 || ls /etc/agent-sandbox/superpowers | head -5'`
Expected: a list of directories from the superpowers repo.

- [ ] **Step 3: Commit**

```bash
git add image/Dockerfile
git commit -m "feat: clone obra/superpowers into image"
```

### Task 2.6: Write AGENTS.md and models.json template

**Files:**
- Create: `image/AGENTS.md`
- Create: `image/models.json`

- [ ] **Step 1: Write `image/AGENTS.md`**

```markdown
# Agent context

You are running inside an sbx microVM on the user's Mac.

## Model

Your model is served by Ollama on the host at `http://${LAN_IP}:11434/v1`
(Ollama's OpenAI-compatible endpoint; see `~/.pi/agent/models.json`).

The host is reached over the LAN — loopback inside the VM does not route to
the host, so `${LAN_IP}` is the host's current Wi-Fi or Ethernet IP. It's
written to `/workspace/.sbx/runtime.env` by `sbx-up` and rendered into
`models.json` by `setup.sh` on every shell startup.

## Sandbox semantics

- This VM is the safety boundary. You may run any shell command without
  asking the user for permission. You will not damage the host.
- `/workspace` is the user's project, mounted bidirectionally from the host.
  Edits there modify the user's real files.
- The rest of the filesystem is per-workspace persistent state. Anything you
  install or write outside `/workspace` survives across `sbx-up` invocations
  for this project, but is isolated from other projects.

## Network

Outbound network is restricted by the global sbx policy. The model endpoint
(`${LAN_IP}:11434`) is allowed; common dev sites (npm, PyPI, GitHub) are
allowed by sbx's "Balanced" default.

If you need a host added, ask the user to run `sbx policy allow network <host>`
on the Mac.
```

- [ ] **Step 2: Write `image/models.json` (template)**

```json
{
  "providers": {
    "ollama": {
      "baseUrl": "http://${LAN_IP}:11434/v1",
      "api": "openai-completions",
      "apiKey": "ollama",
      "models": [
        { "id": "qwen3.6:35b-a3b" }
      ]
    }
  }
}
```

Replace the model `id` with the exact tag from `docs/superpowers/notes/research-notes.md` once Phase 0's "Ollama model tag" section is filled in. As of writing it's still TBD.

- [ ] **Step 3: Commit**

```bash
git add image/AGENTS.md image/models.json
git commit -m "feat: bake AGENTS.md and models.json template"
```

### Task 2.7: Wire AGENTS.md/models.json into the Dockerfile

**Files:**
- Modify: `image/Dockerfile`

- [ ] **Step 1: Append COPY directives and per-user setup**

```dockerfile
# Baked-in agent config
COPY AGENTS.md /etc/agent-sandbox/AGENTS.md
COPY models.json /etc/agent-sandbox/models.json.tmpl

# Switch to the sandbox-templates default user. Confirm via `id` inside the
# base image: it's typically `agent` (uid 1000). If different, change here.
USER agent

RUN mkdir -p /home/agent/.pi/agent \
    && ln -s /etc/agent-sandbox/AGENTS.md /home/agent/.pi/agent/AGENTS.md \
    && ln -s /etc/agent-sandbox/superpowers /home/agent/.pi/agent/skills

USER root
```

If the base image's user is not `agent`, run `docker run --rm docker/sandbox-templates:shell id` first to find the correct username and uid, and substitute throughout.

- [ ] **Step 2: Rebuild and verify**

Run: `docker build -t localhost:5000/agent-sandbox:latest image/`
Run: `docker run --rm localhost:5000/agent-sandbox:latest bash -c 'cat /etc/agent-sandbox/AGENTS.md | head -3 && cat /etc/agent-sandbox/models.json.tmpl'`
Expected: the AGENTS.md preamble, then the models.json with `${LAN_IP}` placeholder intact.

Run: `docker run --rm --user agent localhost:5000/agent-sandbox:latest bash -c 'readlink /home/agent/.pi/agent/AGENTS.md'`
Expected: `/etc/agent-sandbox/AGENTS.md`.

- [ ] **Step 3: Commit**

```bash
git add image/Dockerfile
git commit -m "feat: bake AGENTS.md, models.json template, skills symlinks into image"
```

### Task 2.8: Write setup.sh and wire it via /etc/profile.d

**Files:**
- Create: `image/setup.sh`
- Modify: `image/Dockerfile`

- [ ] **Step 1: Write a minimal `setup.sh` that just renders models.json**

We'll add hash-gated mise + postCreate in Phase 5. For now just the basics, with a sourceable structure.

```bash
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
```

- [ ] **Step 2: Append to Dockerfile**

```dockerfile
COPY setup.sh /etc/agent-sandbox/setup.sh
RUN chmod +x /etc/agent-sandbox/setup.sh \
    && printf '#!/usr/bin/env bash\nsource /etc/agent-sandbox/setup.sh\n' \
       > /etc/profile.d/agent-sandbox.sh \
    && chmod +x /etc/profile.d/agent-sandbox.sh
```

If the base image uses a non-bash login shell that doesn't read `/etc/profile.d/*.sh`, fall back to appending to `/home/agent/.bashrc`:

```dockerfile
RUN echo 'source /etc/agent-sandbox/setup.sh' >> /home/agent/.bashrc
```

- [ ] **Step 3: Rebuild**

Run: `docker build -t localhost:5000/agent-sandbox:latest image/`
Expected: builds successfully.

- [ ] **Step 4: Smoke-test setup.sh by sourcing it manually**

Run:
```bash
docker run --rm --user agent \
  -e HOME=/home/agent \
  -v /tmp:/workspace \
  localhost:5000/agent-sandbox:latest \
  bash -c 'mkdir -p /workspace/.sbx && echo "LAN_IP=10.0.0.1" > /workspace/.sbx/runtime.env && bash -l -c "cat ~/.pi/agent/models.json"'
```
Expected: `models.json` content with `${LAN_IP}` replaced by `10.0.0.1`. (The `bash -l` triggers profile.d sourcing.)

- [ ] **Step 5: Commit**

```bash
git add image/setup.sh image/Dockerfile
git commit -m "feat: add setup.sh and wire via /etc/profile.d"
```

### Task 2.9: Push to the local registry

**Files:**
- (None — Makefile already has the push step gated by Phase 1.4 commenting)

- [ ] **Step 1: Re-enable `docker build --push` in Makefile**

Replace:
```make
	# @echo "==> docker build --push $(IMAGE)"
	# docker build -t $(IMAGE) --push $(REPO)/image/
```
with:
```make
	@echo "==> docker build --push $(IMAGE)"
	docker build -t $(IMAGE) --push $(REPO)/image/
```

- [ ] **Step 2: Run setup**

Run: `make setup`
Expected: image is pushed to `localhost:5000`.

- [ ] **Step 3: Verify in the registry**

Run: `curl -fsS http://localhost:5000/v2/_catalog`
Expected: `{"repositories":["agent-sandbox"]}`.

Run: `curl -fsS http://localhost:5000/v2/agent-sandbox/tags/list`
Expected: `{"name":"agent-sandbox","tags":["latest"]}`.

- [ ] **Step 4: Verify sbx can pull and run**

Run (this is the first real sbx invocation, so `sbx login` must already be done):
```bash
cd /tmp && mkdir -p sbx-image-test && cd sbx-image-test
sbx run --template localhost:5000/agent-sandbox:latest shell -- bash -c 'pi --help && exit 0'
```
Expected: drops into the VM, prints Pi help, exits. The command-form may differ; if `--` is unsupported, run interactively and verify by hand.

- [ ] **Step 5: Commit**

```bash
git add Makefile
git commit -m "feat: enable docker build --push in make setup"
```

---

## Phase 3: sbx-up — Ollama and LAN IP

End state: `sbx-up` (still without the sbx-policy/sbx-run steps at the end) discovers the LAN IP, ensures Ollama is up on it, and ensures the model is pulled. Bats tests cover the pure functions.

### Task 3.1: Restructure sbx-up into testable functions

**Files:**
- Modify: `bin/sbx-up`

- [ ] **Step 1: Replace the stub**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Constants. Edit here to change them.
MODEL_TAG="qwen3.6:35b-a3b"   # confirm exact tag from research-notes.md
OLLAMA_PORT=11434
IMAGE="localhost:5000/agent-sandbox:latest"
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
  echo "First run — pulling $MODEL_TAG (large download)…" >&2
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

  echo "OK so far (sbx policy + sandbox launch added in Phase 4)" >&2
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

### Task 3.2: Bats tests for discover_lan_ip

**Files:**
- Create: `tests/sbx-up.bats`

- [ ] **Step 1: Write the failing tests**

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

- [ ] **Step 2: Run tests**

Run: `bats tests/sbx-up.bats`
Expected: tests pass.

- [ ] **Step 3: Commit**

```bash
git add tests/sbx-up.bats
git commit -m "test: bats tests for discover_lan_ip"
```

### Task 3.3: Bats tests for ollama_is_up

**Files:**
- Modify: `tests/sbx-up.bats`

- [ ] **Step 1: Append tests**

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
Expected: 5 tests pass.

- [ ] **Step 3: Commit**

```bash
git add tests/sbx-up.bats
git commit -m "test: bats tests for ollama_is_up"
```

### Task 3.4: Manual end-to-end Ollama smoke test (Mac only)

This step requires Ollama on macOS. Skip in non-Mac environments.

- [ ] **Step 1: Reset state**

Run: `pkill -f "ollama serve" || true`

- [ ] **Step 2: Run sbx-up via the symlink**

Run: `sbx-up`
Expected stderr lines:
```
LAN_IP=<your.lan.ip>
First run — pulling qwen3.6:35b-a3b…  (only on first run)
OK so far (sbx policy + sandbox launch added in Phase 4)
```

- [ ] **Step 3: Verify Ollama from the host**

Run: `curl -s http://$(ipconfig getifaddr en0):11434/api/tags | jq '.'`
Expected: JSON listing models, including the qwen tag after the first pull.

- [ ] **Step 4: Verify idempotency**

Run: `sbx-up` again.
Expected: no "First run" line, no Ollama startup. Quick exit.

No commit — verification only.

---

## Phase 4: sbx policy update + sandbox launch

End state: `sbx-up` updates the global sbx policy with the current LAN IP, writes `${PWD}/.sbx/runtime.env`, and `exec`s `sbx run --template localhost:5000/agent-sandbox:latest shell`. Inside the VM, the model endpoint is reachable.

### Task 4.1: Add update_sbx_policy and write_runtime_env to sbx-up

**Files:**
- Modify: `bin/sbx-up`

- [ ] **Step 1: Add the functions before main()**

```bash
update_sbx_policy() {
  local ip="$1"
  # `sbx policy allow network <host>:<port>` — confirm exact form via
  # `sbx policy allow --help`. The command must be idempotent; re-running
  # with the same host should be a no-op.
  sbx policy allow network "${ip}:${OLLAMA_PORT}"
}

write_runtime_env() {
  local ip="$1" workspace="$2"
  mkdir -p "${workspace}/.sbx"
  printf 'LAN_IP=%s\n' "$ip" > "${workspace}/.sbx/runtime.env"
}
```

- [ ] **Step 2: Verify it parses**

Run: `bash -n bin/sbx-up`
Expected: no output.

- [ ] **Step 3: Add a bats test for write_runtime_env**

Append to `tests/sbx-up.bats`:

```bash
@test "write_runtime_env creates .sbx/runtime.env with LAN_IP" {
  local tmpdir; tmpdir=$(mktemp -d)
  write_runtime_env "192.168.1.50" "$tmpdir"
  run cat "$tmpdir/.sbx/runtime.env"
  [ "$status" -eq 0 ]
  [ "$output" = "LAN_IP=192.168.1.50" ]
  rm -rf "$tmpdir"
}
```

- [ ] **Step 4: Run tests**

Run: `bats tests/sbx-up.bats`
Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add bin/sbx-up tests/sbx-up.bats
git commit -m "feat: add update_sbx_policy and write_runtime_env, with test"
```

### Task 4.2: Wire policy update, runtime.env, and sbx run into main()

**Files:**
- Modify: `bin/sbx-up`

- [ ] **Step 1: Replace the placeholder in main()**

Change the bottom of `main()` from:
```bash
  ensure_model

  echo "OK so far (sbx policy + sandbox launch added in Phase 4)" >&2
}
```
to:
```bash
  ensure_model

  update_sbx_policy "$ip"
  write_runtime_env "$ip" "$PWD"

  if [[ "${1:-}" == "--rebuild" ]]; then
    local repo
    repo=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")
    docker build -t "$IMAGE" --push "${repo}/image/"
    shift
  fi

  exec sbx run --template "$IMAGE" shell
}
```

Adjust the `sbx run` invocation if the actual command form differs from what the docs show — e.g. if `shell` is positional vs. needs `--agent shell`.

- [ ] **Step 2: Verify parses**

Run: `bash -n bin/sbx-up`
Expected: no output.

- [ ] **Step 3: Run end-to-end (Mac only)**

```bash
cd /tmp && mkdir -p sbx-test && cd sbx-test
sbx-up
```
Expected: drops into a shell inside the VM. `pwd` returns `/workspace`. `cat /workspace/.sbx/runtime.env` shows `LAN_IP=<ip>`. `cat ~/.pi/agent/models.json` shows the rendered config.

- [ ] **Step 4: Verify model reachability from VM**

Inside the VM:
```bash
curl -s "http://$(grep LAN_IP /workspace/.sbx/runtime.env | cut -d= -f2):11434/api/tags" | head -c 200
```
Expected: JSON model list.

Exit: `exit`.

- [ ] **Step 5: Commit**

```bash
git add bin/sbx-up
git commit -m "feat: wire sbx policy update, runtime.env, and sbx run into sbx-up"
```

### Task 4.3: --rebuild smoke test (Mac only)

- [ ] **Step 1: Add a trivial change**

Append `# rebuild marker\n` to `image/Dockerfile`.

- [ ] **Step 2: Run sbx-up --rebuild**

Run: `sbx-up --rebuild`
Expected: runs `docker build --push` first, then launches sandbox.

- [ ] **Step 3: Revert**

Run: `git checkout image/Dockerfile`

No commit.

---

## Phase 5: setup.sh first-boot logic

End state: `setup.sh` (sourced from profile.d on every shell startup) is idempotent, renders models.json, and runs hash-gated `mise install` and `postCreate.sh` from the workspace.

### Task 5.1: Add hash-gated runner to setup.sh

**Files:**
- Modify: `image/setup.sh`

- [ ] **Step 1: Add `run_hash_gated` and call it twice inside the file**

The existing setup.sh already loads runtime.env and renders models.json. Append (before the file's natural end):

```bash
# Generic hash-gated runner. Re-runs `runner` only when `source` content changes.
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

run_hash_gated /workspace/mise.toml \
  "${STATE_DIR}/mise.hash" "mise.toml" \
  '(cd /workspace && mise install)'

run_hash_gated /workspace/.sbx/postCreate.sh \
  "${STATE_DIR}/postcreate.hash" ".sbx/postCreate.sh" \
  'bash /workspace/.sbx/postCreate.sh'
```

Important: `setup.sh` is sourced (not executed). The `SBX_SETUP_DONE` guard at the top of the file already prevents re-running on every subshell, but `run_hash_gated` itself is also fine to define multiple times.

- [ ] **Step 2: Rebuild image**

Run: `make setup` (which now does `docker build --push`).

- [ ] **Step 3: Smoke test on a project with mise.toml (Mac only)**

```bash
cd /tmp && mkdir -p sbx-mise-test && cd sbx-mise-test
cat > mise.toml <<'EOF'
[tools]
node = "20"
EOF
sbx-up
```
Inside the VM: should see `==> mise.toml changed (or first run); running`, then `mise install` output. Verify:
```bash
node --version   # v20.x.x
```

Exit, run `sbx-up` again. Should not see the install line on second boot.

- [ ] **Step 4: Smoke test edit-triggers-rerun (Mac only)**

```bash
cat > /tmp/sbx-mise-test/mise.toml <<'EOF'
[tools]
node = "22"
EOF
cd /tmp/sbx-mise-test && sbx-up
```
Inside: should see install line; `node --version` reports v22.

- [ ] **Step 5: Smoke test postCreate.sh (Mac only)**

```bash
mkdir -p /tmp/sbx-mise-test/.sbx
cat > /tmp/sbx-mise-test/.sbx/postCreate.sh <<'EOF'
#!/usr/bin/env bash
echo "ran at $(date)" >> ~/.postcreate.log
EOF
chmod +x /tmp/sbx-mise-test/.sbx/postCreate.sh
cd /tmp/sbx-mise-test && sbx-up
```
Inside: `cat ~/.postcreate.log` shows one line. Exit, `sbx-up` again — still one line. Edit the script (e.g. `echo bumped >> /tmp/sbx-mise-test/.sbx/postCreate.sh`), re-run — log now has two lines.

- [ ] **Step 6: Commit**

```bash
git add image/setup.sh
git commit -m "feat: hash-gated mise install and postCreate.sh in setup.sh"
```

### Task 5.2: Bats tests for run_hash_gated

**Files:**
- Create: `tests/setup.bats`

- [ ] **Step 1: Write the tests**

```bash
#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/../image/setup.sh"
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

Note: this depends on `setup.sh` being sourceable without side effects beyond defining functions. `setup.sh` has the `SBX_SETUP_DONE` guard plus a `return 0` if `LAN_IP` isn't set, so sourcing in the bats environment (where neither is set) just exits the `if` blocks early and the function definitions remain. Verify this by hand if tests fail unexpectedly.

- [ ] **Step 2: Run tests**

Run: `bats tests/setup.bats`
Expected: 4 tests pass.

- [ ] **Step 3: Commit**

```bash
git add tests/setup.bats
git commit -m "test: bats tests for run_hash_gated in setup.sh"
```

---

## Phase 6: End-to-end and README

### Task 6.1: End-to-end smoke (Mac only)

This is manual verification. No code changes.

- [ ] **Step 1: Clean state**

```bash
pkill -f "ollama serve" || true
rm -rf /tmp/sbx-e2e
mkdir -p /tmp/sbx-e2e && cd /tmp/sbx-e2e
git init -q && echo "# test" > README.md && git add . && git commit -q -m init
echo ".sbx/runtime.env" > .gitignore && git add .gitignore && git commit -q -m gitignore
```

- [ ] **Step 2: Launch sbx-up**

Run: `sbx-up`
Expected: full flow — LAN IP discovered, Ollama up, model present, sbx policy updated, runtime.env written, sandbox launched.

- [ ] **Step 3: Verify Pi hits the model**

Inside the VM:
```bash
echo "Say 'hello from sbx' and nothing else." | pi
```
(Substitute the actual Pi invocation form — `pi prompt`, `pi run`, etc. — confirmed via `pi --help`.)

Expected: a response that includes "hello from sbx" or similar. The response comes from Qwen via host Ollama.

- [ ] **Step 4: Verify state persistence**

```bash
echo "marker $(date)" > ~/.persistence-check
exit
```

Re-run `sbx-up` from `/tmp/sbx-e2e`. Inside the VM:
```bash
cat ~/.persistence-check
```
Expected: the timestamp from the previous boot.

- [ ] **Step 5: Verify cross-workspace isolation**

```bash
exit
mkdir -p /tmp/sbx-other && cd /tmp/sbx-other && sbx-up
```
Inside: `ls ~/.persistence-check 2>&1 || echo isolated` — expect `isolated`.

Exit. No commit.

### Task 6.2: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write the README**

```markdown
# agent-sandbox

Personal infra: Pi running in an sbx microVM, talking to Qwen served by host Ollama.

## Setup (once)

Pre-requisites: a working Docker (Desktop or colima), and `sbx login` already done.

```
make setup
```

Installs host deps via Homebrew, starts a local Docker registry on `localhost:5000`, builds and pushes the sandbox image, and symlinks `sbx-up` into `~/.local/bin/`. If `~/.local/bin` isn't on `$PATH`, the printed instructions tell you how to add it.

## Daily use

From any project directory:

```
sbx-up
```

What it does:
1. Discovers your current LAN IP.
2. Starts Ollama on the host bound to that IP if not already running.
3. Pulls the Qwen model on first run.
4. Adds `<lan-ip>:11434` to the global sbx network policy.
5. Writes `${PWD}/.sbx/runtime.env` with the LAN IP (the in-VM `setup.sh` reads it).
6. Drops you into a shell inside the sandbox; `pi` is on `$PATH`, project mounted at `/workspace`.

Use `sbx-up --rebuild` after editing `image/Dockerfile`.

**Tip:** add `.sbx/runtime.env` to your project's `.gitignore`.

## Per-project setup

- `mise.toml` at the workspace root — toolchain installed automatically on first boot, re-runs on edit.
- `.sbx/postCreate.sh` at the workspace root — runs once per workspace, re-runs on edit. Make it idempotent.

## Files of interest

- `bin/sbx-up` — the launcher.
- `image/Dockerfile` — extends `docker/sandbox-templates:shell`, pre-installs Pi.
- `image/setup.sh` — sourced via `/etc/profile.d` inside the VM on every shell startup.
- `Makefile` — host setup (`make setup`).

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

- [ ] **Step 2: Shellcheck**

Run: `shellcheck bin/sbx-up image/setup.sh`
Expected: no errors. Address obvious warnings; ignore stylistic ones.

- [ ] **Step 3: Verify file tree**

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
image/models.json
image/setup.sh
tests/setup.bats
tests/sbx-up.bats
```

No commit.

---

## Notes for the engineer

- Phase 0 outputs (`docs/superpowers/notes/research-notes.md`) cover Pi specifics. Refer to it whenever a task says "confirm at impl time."
- `sbx login` is a one-time human action; it's not in `make setup` because it's interactive.
- "Mac only" verification steps require macOS + Docker + sbx + ollama installed. Skip them in CI / Linux dev environments.
- If a verification step fails, do not skip ahead. Diagnose first.
