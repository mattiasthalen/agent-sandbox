# agent-sandbox — design

A small personal repo that sets up Pi running in a Docker Sandbox (sbx) microVM, talking to a Qwen model served by Ollama on the host. Solo use, M5 Pro Mac, 64 GB RAM, macOS 26.2+.

## Goals and constraints

- One model: Qwen3.6-35B-A3B served by Ollama, MLX backend, on the host.
- One agent: Pi (from `obra/superpowers`), running inside an sbx microVM.
- microVMs cannot access Metal GPU, so Ollama must run on the host.
- Loopback from the microVM to the host is unreliable. Ollama binds to the host's LAN IP; the VM's network policy allowlists that IP.
- The VM is the safety boundary. Pi runs YOLO inside it.
- Per-workspace sandbox state persists automatically across `sbx-up` invocations (handled by `sbx`, not by us).
- Personal infra. Simplicity over completeness.

## Repo layout

```
agent-sandbox/
├── Makefile                    # `make setup` is the only target
├── Brewfile                    # ollama, sbx, mise, gh, jq, uv
├── image/
│   ├── Dockerfile              # base sandbox image
│   ├── AGENTS.md               # baked-in: tells Pi about host Ollama, YOLO context
│   ├── models.json             # baked-in template: ${LAN_IP} placeholder
│   └── entrypoint.sh           # first-boot detection, mise install, postCreate
├── bin/
│   └── sbx-up                  # symlinked into ~/.local/bin by `make setup`
├── policy/
│   └── network.tmpl            # ${LAN_IP} substituted on every sbx-up
└── docs/
    └── superpowers/specs/      # this design
```

Two intentional simplifications:

- `bin/sbx-up` is a symlink, not a copy. Edit it in the repo, changes apply immediately.
- Everything is bash. If a piece grows past ~50 lines of bash, that's a signal to revisit, not a license to add Python.

## `make setup` end to end

One target. Idempotent. Run once after `git clone`, re-run after editing `Brewfile` or `image/Dockerfile`.

1. **`brew bundle --file=Brewfile`** — installs ollama, sbx, mise, gh, jq, uv on the host.
2. **`sbx build -t agent-sandbox image/`** — produces the base image with Pi, superpowers, mise, uv, gh, jq, ripgrep, git, plus the baked-in `AGENTS.md` and `models.json` template.
3. **Set up host config dirs** — `mkdir -p ~/.config/agent-sandbox ~/.cache/agent-sandbox`, copy `policy/network.tmpl` to `~/.config/agent-sandbox/`. Template only; LAN IP is substituted at `sbx-up` time.
4. **Install `sbx-up`** — `mkdir -p ~/.local/bin && ln -sf "$PWD/bin/sbx-up" ~/.local/bin/sbx-up`.
5. **PATH check**:
   - If `~/.local/bin` is on `$PATH`, print `✓ sbx-up installed`.
   - Otherwise, print the exact line to add to the shell rc and exit 0. `make setup` does not edit user dotfiles.

What `make setup` deliberately does **not** do:

- Does not pull the Qwen model. That's `sbx-up`'s lazy job.
- Does not start Ollama. Lazy start.
- Does not install Pi on the host. Pi only lives in the image.
- No `make clean`, `make test`, `make rebuild`. To rebuild the image: `sbx-up --rebuild` or `sbx build -t agent-sandbox image/` directly.

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
   - If 200, skip. (This means a user-managed Ollama works fine — no `pgrep`, no PID file.)
   - Otherwise: `OLLAMA_HOST=$LAN_IP:11434 nohup ollama serve > ~/.cache/agent-sandbox/ollama.log 2>&1 &`. Poll `/api/tags` every 0.5s for up to 15s.
   - On poll failure: print last ~20 lines of `ollama.log`, exit 1. No retries.

3. **Ensure model present.**
   - `ollama list | grep -q '^qwen3.6:35b-a3b'` (exact tag confirmed at impl time).
   - If absent: `ollama pull qwen3.6:35b-a3b`. Tell the user it's a one-time ~22 GB pull.

4. **Generate per-invocation network policy.**
   - `sed "s|\${LAN_IP}|$LAN_IP|g" ~/.config/agent-sandbox/network.tmpl > ~/.cache/agent-sandbox/network-current.json`.
   - Regenerated every invocation. Network changes (Wi-Fi, dock, hotspot) handled for free, no watcher.

5. **Optional `--rebuild`.**
   - Resolves the repo from the symlink target of `which sbx-up`, runs `sbx build -t agent-sandbox $REPO/image/`.

6. **Launch sandbox.**
   - `sbx run --image agent-sandbox --policy ~/.cache/agent-sandbox/network-current.json --mount $PWD:/workspace --env LAN_IP=$LAN_IP ...`.
   - Drops the user into a shell in the VM. `$PWD` (host) → `/workspace` (VM). `pi` is on `$PATH`.

What `sbx-up` deliberately does **not** include:

- No config file (no `~/.config/agent-sandbox/config.toml`). Model tag, port, paths are hardcoded constants at the top of the script.
- No Ollama warmup request. First Pi prompt eats the load latency.
- No daemon, no PID file, no `sbx-down`, no `sbx-status`.
- No retry on Ollama startup. One try, 15 s, fail clean.
- No multi-model support. One model, hardcoded.

## Image vs. runtime layering

**Image (built once, shared across all projects):**

```
image/Dockerfile installs:
  - base: debian-slim or ubuntu-minimal (decided at impl)
  - git, ripgrep, jq, gh, curl, ca-certificates
  - mise, uv
  - Pi (install method — npm / release tarball / pipx — decided at impl)
  - obra/superpowers (cloned to a known path)
  - bash, zsh

Files copied in:
  - image/AGENTS.md         → wherever Pi reads it (path TBD at impl)
  - image/models.json       → template, ${LAN_IP} placeholder
  - image/entrypoint.sh     → /usr/local/bin/sandbox-entrypoint
```

The image's `AGENTS.md` is generic, not project-specific. It tells Pi:

- Model is at `http://${LAN_IP}:11434`.
- This is a YOLO microVM with no permission gates.
- Network is restricted to the model endpoint and a small allowlist of package registries.

**Runtime injection (every `sbx-up`):**

```
$PWD          →  /workspace          (your repo, read-write)
LAN_IP env    →  passed by sbx run   (consumed by entrypoint to render models.json)
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

**`entrypoint.sh` runs on every `sbx-up`:**

1. Render `models.json` from template using `LAN_IP` env var (or set Pi's env directly if Pi supports `PI_MODEL_ENDPOINT` — to be confirmed at impl).
2. **Project toolchain (hash-gated):**
   ```
   if [ -f /workspace/mise.toml ]; then
     NEW=$(sha256sum /workspace/mise.toml | cut -c1-16)
     OLD=$(cat ~/.sandbox/mise.hash 2>/dev/null)
     if [ "$NEW" != "$OLD" ]; then
       cd /workspace && mise install
       echo "$NEW" > ~/.sandbox/mise.hash
     fi
   fi
   ```
3. **Project setup (hash-gated):**
   ```
   if [ -f /workspace/.sbx/postCreate.sh ]; then
     NEW=$(sha256sum /workspace/.sbx/postCreate.sh | cut -c1-16)
     OLD=$(cat ~/.sandbox/postcreate.hash 2>/dev/null)
     if [ "$NEW" != "$OLD" ]; then
       bash /workspace/.sbx/postCreate.sh
       echo "$NEW" > ~/.sandbox/postcreate.hash
     fi
   fi
   ```
4. `exec` the user's shell at `/workspace`.

Hash-gating means the install/setup re-runs when the source file changes, not blindly every boot. Contract: `postCreate.sh` must be idempotent (most install commands are; `git clone` is the usual hazard).

What's deliberately **not** in the image:

- Anything project-specific (workspace's job).
- Pre-pulled models or large data (image stays small, fast to rebuild).
- A bunch of pre-installed language toolchains (Node 20, Python 3.12, Go, Rust). `mise` installs those per project on demand.
- Editor configs and dotfiles. Use `.sbx/postCreate.sh` if you want them.

## Ollama host binding

Three pieces have to agree on the same `LAN_IP`. `sbx-up` is the conductor.

```
                    sbx-up (host)
                        │
        ┌───────────────┼───────────────┐
        │               │               │
   1. binds Ollama  2. writes        3. passes as
      to LAN_IP        network          env var
                       policy           into VM
        │               │               │
        ▼               ▼               ▼
   ollama serve    network-current   Pi reads $LAN_IP
   on LAN_IP:11434      .json        from env, writes
                   allows LAN_IP     into models.json
                   :11434 outbound   at boot
```

**Piece 1: Ollama binding.** `OLLAMA_HOST=$LAN_IP:11434 ollama serve`. Env var only, no config edits.

**Piece 2: Network policy template.** `policy/network.tmpl` contains a default-deny policy with allow rules for:

- `${LAN_IP}:11434` (the model)
- `registry.npmjs.org:443`
- `pypi.org:443`, `files.pythonhosted.org:443`
- `github.com:443`, `objects.githubusercontent.com:443`
- `ghcr.io:443`

Exact format depends on `sbx`. The template uses `${LAN_IP}` as a literal placeholder; `sbx-up` substitutes via `sed` on every invocation. Allowlist will be iterated as real failures surface (e.g. `mise` may need additional hosts for specific runtimes).

**Piece 3: Pi wiring inside the VM.** `sbx-up` passes `LAN_IP` to the VM as an env var. `entrypoint.sh` either renders `models.json` from a baked-in template using `envsubst`, or sets `PI_MODEL_ENDPOINT=http://$LAN_IP:11434` directly — depending on what Pi expects. The image stays portable (no LAN IP baked in); the VM gets the current IP every boot.

**Network change handling.** The user moves the laptop frequently. LAN IP changes between locations. Discover-and-regenerate on every `sbx-up` is the entire mechanism — no watcher, no caching, no diff detection. The cost is a few `ipconfig` calls and one `sed`; the benefit is "I took my laptop to a hotel" is a non-event.

**Deliberate non-features:**

- No TLS on Ollama. HTTP on the LAN.
- No auth on Ollama. The VM's network policy is the gate; on the LAN, anyone on your Wi-Fi could hit Ollama, but they could already hit your laptop generally — not a new attack surface.
- No fallback model. If Qwen is unavailable, `sbx-up` fails at step 3.

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

## Open questions deferred to implementation

These don't change the design but need answers to write code:

- **Pi install method**: npm, release tarball, pipx, cargo. Check `obra/superpowers` README at impl time.
- **Pi config and discovery paths**: where Pi reads `AGENTS.md`, where it reads `models.json` (or whether it uses env vars like `PI_MODEL_ENDPOINT`), where it discovers skills from `obra/superpowers`. Determines a handful of `COPY` destinations in the Dockerfile and whether `entrypoint.sh` does `envsubst` or `export`.
- **Exact `sbx` command surface**: `sbx build` flags, `sbx run` flags, the policy file format and location convention. Read `sbx --help` and its docs at impl time.
- **Exact Ollama tag for the model**: confirm `qwen3.6:35b-a3b` is the actual tag in the Ollama registry.
- **Base image**: `debian:slim` vs `ubuntu:minimal`. Pick whichever makes Pi's install simplest.
- **Network policy allowlist**: starting set above is a guess. Iterate as failures surface.
