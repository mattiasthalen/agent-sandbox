# agent-sandbox — design

A small personal repo that sets up Pi running in a Docker Sandbox (sbx) microVM, talking to a Qwen model served by Ollama on the host. Solo use, M5 Pro Mac, 64 GB RAM, macOS 26.2+.

> **Revision history**
> - 2026-05-05 v1: initial design.
> - 2026-05-05 v2: Phase 0 research surfaced that sbx has no `--image`/`--mount`/`--env`/`--policy` run flags and uses a registry-mediated template flow. Spec rewritten to match actual sbx semantics: build image with `docker build --push localhost:5000/...`, network policy is global via `sbx policy allow`, LAN_IP injected via a workspace `.sbx/runtime.env` file. Pi install/config paths confirmed.

## Goals and constraints

- One model: Qwen3.6-35B-A3B served by Ollama, MLX backend, on the host.
- One agent: Pi (`@mariozechner/pi-coding-agent`), running inside an sbx microVM. Pi consumes `obra/superpowers` skills.
- microVMs cannot access Metal GPU, so Ollama must run on the host.
- Loopback from the microVM to the host is unreliable. Ollama binds to the host's LAN IP; the sandbox's network policy allowlists that IP.
- The VM is the safety boundary. Pi runs YOLO inside it.
- Per-workspace sandbox state persists automatically across `sbx-up` invocations (handled by `sbx`, not by us).
- **No remote container registry.** A local Docker registry runs on `localhost:5000` to satisfy sbx's template-pull mechanism.
- Personal infra. Simplicity over completeness.

## Repo layout

```
agent-sandbox/
├── Makefile                    # `make setup` is the only target
├── Brewfile                    # ollama, sbx, mise, gh, jq, uv, bats-core, docker
├── image/
│   ├── Dockerfile              # FROM docker/sandbox-templates:shell
│   ├── AGENTS.md               # baked-in: tells Pi about host Ollama, YOLO context
│   ├── models.json             # baked-in template: ${LAN_IP} placeholder
│   └── setup.sh                # sourced from /etc/profile.d, does first-boot logic
├── bin/
│   └── sbx-up                  # symlinked into ~/.local/bin by `make setup`
├── tests/
│   ├── sbx-up.bats             # tests for sbx-up's pure functions
│   └── setup.bats              # tests for the in-VM setup.sh hash logic
└── docs/
    └── superpowers/specs/      # this design
```

Notes:

- `bin/sbx-up` is a symlink, not a copy. Edit it in the repo, changes apply immediately.
- No `policy/network.tmpl` directory — sbx's network policy is global (managed via `sbx policy allow`), not a per-run file.
- `image/setup.sh` is sourced from a profile.d entry inside the image, not used as the Dockerfile ENTRYPOINT (sbx's `shell` template owns that).
- Everything is bash. If a piece grows past ~50 lines of bash, that's a signal to revisit, not a license to add Python.

## `make setup` end to end

One target. Idempotent. Run once after `git clone`, re-run after editing `Brewfile` or `image/Dockerfile`.

1. **`brew bundle --file=Brewfile`** — installs ollama, sbx, mise, gh, jq, uv, bats-core, docker on the host. (Docker Desktop or colima must be available for `docker build`.)
2. **Ensure local registry is running** — `docker run -d --restart=always -p 127.0.0.1:5000:5000 --name agent-sandbox-registry registry:2`. Idempotent: skip if a container with that name already exists.
3. **Build and push the image** — `docker build -t localhost:5000/agent-sandbox:latest --push image/`. Pushes to the local registry container so sbx can pull it.
4. **Set up host config dirs** — `mkdir -p ~/.cache/agent-sandbox`. The cache holds `ollama.log` only.
5. **Install `sbx-up`** — `mkdir -p ~/.local/bin && ln -sf "$PWD/bin/sbx-up" ~/.local/bin/sbx-up`.
6. **PATH check**:
   - If `~/.local/bin` is on `$PATH`, print `✓ sbx-up installed`.
   - Otherwise, print the exact line to add to the shell rc and exit 0. `make setup` does not edit user dotfiles.

What `make setup` deliberately does **not** do:

- Does not pull the Qwen model. That's `sbx-up`'s lazy job.
- Does not start Ollama. Lazy start.
- Does not install Pi on the host. Pi only lives in the image.
- Does not run `sbx login`. The user does that once at install time, separately.
- No `make clean`, `make test`, `make rebuild`. To rebuild the image: `sbx-up --rebuild` or `docker build -t localhost:5000/agent-sandbox:latest --push image/` directly.

## `sbx-up` behavior

Bash script. Invoked from any client repo. No required args. One optional flag.

```
sbx-up [--rebuild]
```

Flow:

1. **Discover host LAN IP.**
   - `LAN_IP=$(ipconfig getifaddr en0)`, fall back to `en1`.
   - If both empty: fail with a clear message ("No LAN IP on en0/en1. On VPN? Cable unplugged?"). Exit 1.

2. **Ensure Ollama running on `$LAN_IP:11434`.**
   - Probe `curl -fsS --max-time 1 http://$LAN_IP:11434/api/tags`.
   - If 200, skip. (A user-managed Ollama works fine — no `pgrep`, no PID file.)
   - Otherwise: `OLLAMA_HOST=$LAN_IP:11434 nohup ollama serve > ~/.cache/agent-sandbox/ollama.log 2>&1 &`. Poll `/api/tags` every 0.5 s for up to 15 s.
   - On poll failure: print last ~20 lines of `ollama.log`, exit 1. No retries.

3. **Ensure model present.**
   - `ollama list | awk 'NR>1 {print $1}' | grep -qx 'qwen3.6:35b-a3b'` (exact tag confirmed at impl time).
   - If absent: `ollama pull qwen3.6:35b-a3b`. Tell the user it's a one-time ~22 GB pull.

4. **Update sbx network policy.**
   - `sbx policy allow network "$LAN_IP:11434"` (or whatever flag form `sbx policy allow` actually takes; idempotent).
   - Old IPs from previous networks accumulate in the global allowlist. Acceptable for personal use; we don't bother cleaning them up.

5. **Write workspace runtime file.**
   - `mkdir -p "$PWD/.sbx" && echo "LAN_IP=$LAN_IP" > "$PWD/.sbx/runtime.env"`.
   - The in-VM setup script reads this on boot. The file is workspace-local because sbx has no env-var injection mechanism (open issue: <https://github.com/docker/sbx-releases/issues/7>).
   - Users should `.gitignore` `.sbx/runtime.env` (or all of `.sbx/`).

6. **Optional `--rebuild`.**
   - Resolves the repo from the symlink target of `which sbx-up`.
   - Runs `docker build -t localhost:5000/agent-sandbox:latest --push "$REPO/image/"`.

7. **Launch sandbox.**
   - `exec sbx run --template localhost:5000/agent-sandbox:latest shell`.
   - sbx auto-mounts the cwd into the VM. Drops the user into a shell. The image's profile.d entry sources `setup.sh`, which renders `models.json` and runs hash-gated mise/postCreate.

What `sbx-up` deliberately does **not** include:

- No config file (no `~/.config/agent-sandbox/config.toml`). Model tag, port, paths are hardcoded constants at the top of the script.
- No Ollama warmup request. First Pi prompt eats the load latency.
- No daemon, no PID file, no `sbx-down`, no `sbx-status`.
- No retry on Ollama startup. One try, 15 s, fail clean.
- No multi-model support. One model, hardcoded.
- No automatic stale-IP cleanup from the sbx policy.

## Image vs. runtime layering

**Image (built once, shared across all projects):**

```
image/Dockerfile (FROM docker/sandbox-templates:shell):
  - apt: nodejs, npm, git, ripgrep, jq, gnupg, curl, ca-certificates, gettext-base
  - mise (curl install)
  - uv (curl install)
  - gh (apt repo)
  - Pi: npm install -g @mariozechner/pi-coding-agent  (binary `pi`)
  - obra/superpowers cloned to /etc/agent-sandbox/superpowers
  - /etc/agent-sandbox/AGENTS.md      (linked into ~/.pi/agent/AGENTS.md)
  - /etc/agent-sandbox/models.json.tmpl  (rendered by setup.sh into ~/.pi/agent/models.json)
  - /etc/agent-sandbox/superpowers    (linked into ~/.pi/agent/skills)
  - /etc/agent-sandbox/setup.sh       (sourced by /etc/profile.d/agent-sandbox.sh)
```

The image's `AGENTS.md` is generic, not project-specific. It tells Pi:

- The model is at `http://${LAN_IP}:11434/v1` (Ollama's OpenAI-compatible endpoint).
- This is a YOLO microVM with no permission gates.
- Network is restricted to the model endpoint plus whatever else is in the global sbx policy.

**Runtime injection (every `sbx-up`):**

```
$PWD                  →  /workspace             (sbx auto-mounts)
$PWD/.sbx/runtime.env →  read by setup.sh       (carries LAN_IP into the VM)
sbx policy            →  globally updated by sbx-up before sandbox launch
```

**Per-workspace persisted state (handled by `sbx`):**

```
$HOME inside the VM persists across sbx-up invocations for this workspace:
  - shell history
  - Pi conversation history
  - mise installs (Node, Python, etc. for this project)
  - any marker files we drop (~/.sandbox/...)
```

Each project gets its own state, keyed by workspace path. Two projects, two separate sandboxes; concurrent use in two terminals is fine.

**`setup.sh` runs on every shell startup inside the VM (sourced from profile.d):**

1. **Idempotency guard:** `if [[ -n "${SBX_SETUP_DONE:-}" ]]; then return; fi; export SBX_SETUP_DONE=1`. Prevents re-running on subshells.
2. **Read runtime env:** `set -a; . /workspace/.sbx/runtime.env; set +a` (warn and return if missing).
3. **Render models.json:** `envsubst < /etc/agent-sandbox/models.json.tmpl > ~/.pi/agent/models.json`.
4. **Hash-gated mise install** for `/workspace/mise.toml` (re-runs only when the file changes).
5. **Hash-gated postCreate** for `/workspace/.sbx/postCreate.sh` (same).

Hash-gating means install/setup re-runs when the source file changes, not blindly every boot. Contract: `postCreate.sh` must be idempotent (most install commands are; `git clone` is the usual hazard).

What's deliberately **not** in the image:

- Anything project-specific (workspace's job).
- Pre-pulled models or large data (image stays small, fast to rebuild).
- A bunch of pre-installed language toolchains (Node 20, Python 3.12, Go, Rust). `mise` installs those per project on demand.
- Editor configs and dotfiles. Use `.sbx/postCreate.sh` if you want them.

## Ollama host binding

Four pieces have to agree on the same `LAN_IP`. `sbx-up` is the conductor.

```
                                sbx-up (host)
                                    │
        ┌─────────────────┬─────────┴─────────┬───────────────┐
        │                 │                   │               │
   1. binds Ollama   2. updates sbx     3. writes        4. exec sbx run
      to LAN_IP         policy with         workspace        shell
                        new LAN_IP          .sbx/runtime.env
        │                 │                   │               │
        ▼                 ▼                   ▼               ▼
   ollama serve     sbx policy allow     /workspace/.sbx/  setup.sh sourced
   on LAN_IP:11434  network LAN_IP       runtime.env       reads runtime.env,
                    :11434              (LAN_IP=...)       envsubst's
                                                           models.json
```

**Piece 1: Ollama binding.** `OLLAMA_HOST=$LAN_IP:11434 ollama serve`. Env var only, no config edits.

**Piece 2: sbx network policy.** Global, edited via `sbx policy allow network <ip>:11434`. Idempotent. Old IPs accumulate but don't break anything; we accept the small allowlist drift.

**Piece 3: Workspace runtime file.** `${PWD}/.sbx/runtime.env` is the bridge between host and VM, since sbx has no env-var injection. Contains a single line: `LAN_IP=<ip>`. Rewritten on every `sbx-up`. Users `.gitignore` it.

**Piece 4: In-VM setup.** `setup.sh` (sourced from profile.d) reads `runtime.env`, then `envsubst < models.json.tmpl > ~/.pi/agent/models.json`. Pi reads `models.json` on its next prompt.

**Network change handling.** The user moves the laptop frequently. LAN IP changes between locations. `sbx-up` runs all four pieces on every invocation, so a new network is just "run sbx-up again."

**Deliberate non-features:**

- No TLS on Ollama. HTTP on the LAN.
- No auth on Ollama. The VM's sbx policy is the gate; on the LAN, anyone on your Wi-Fi could hit Ollama, but they could already hit your laptop generally — not a new attack surface.
- No fallback model. If Qwen is unavailable, `sbx-up` fails at step 3.
- No automatic cleanup of stale LAN IPs from the sbx policy.

## Out of scope (cut to keep this honest)

- No network change watcher daemon.
- No cached LAN IP with diff detection.
- No multi-model support, no model selector flag.
- No retry-with-backoff on Ollama startup.
- No `sbx-down`, `sbx-status`, `sbx-clean`.
- No cross-project shared caches (e.g. one shared npm cache). Breaks isolation, skip.
- No "really only once" `postFirstBoot.sh` hook. YAGNI; add if needed.
- No editor configs or dotfiles in the image.
- No automatic shell rc editing by `make setup`.
- No remote container registry, no Docker Hub / ghcr.io account, no public image.
- No automatic `sbx login`. User does that once.

## Confirmed at Phase 0 research (was: open questions)

- **Pi install method**: `npm install -g @mariozechner/pi-coding-agent`. Binary: `pi`.
- **Pi config and discovery paths**: `~/.pi/agent/AGENTS.md` (global), `~/.pi/agent/models.json`, `~/.pi/agent/skills/` (or `.pi/skills/` etc.). Pi also walks parent directories from cwd looking for AGENTS.md.
- **models.json schema** (Ollama provider):
  ```json
  {
    "providers": {
      "ollama": {
        "baseUrl": "http://${LAN_IP}:11434/v1",
        "api": "openai-completions",
        "apiKey": "ollama",
        "models": [{ "id": "qwen3.6:35b-a3b" }]
      }
    }
  }
  ```
- **sbx CLI surface**:
  - Custom templates: extend `docker/sandbox-templates:shell` via Dockerfile, push to a registry, run with `sbx run --template <registry>/<name>:<tag> shell`.
  - No `--image`, `--mount`, `--env`, `--policy` flags on `sbx run`.
  - Network policy is global, edited via `sbx policy allow network <host>`.
  - Workspace is auto-mounted from cwd.
  - No env-var injection (open issue #7).

## Still deferred to implementation

- **Exact Ollama tag for the model**: confirm `qwen3.6:35b-a3b` is the actual tag at `ollama.com/library`.
- **The user the `shell` template runs as**: probably `agent`, but confirm and use the right `USER` directives in the Dockerfile.
- **Whether `nodejs` from Debian apt is recent enough for Pi**: if not, fall back to NodeSource setup script.
- **Profile.d sourcing for the shell template**: confirm `/etc/profile.d/*.sh` is sourced by the template's default shell. Fallback: append to `/home/agent/.bashrc`.
- **sbx policy allow exact syntax**: `sbx policy allow network <host>:<port>` vs other forms — confirm via `sbx policy allow --help`.
