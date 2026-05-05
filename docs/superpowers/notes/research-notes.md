# agent-sandbox research notes

Findings from Phase 0. Used by Phase 2 (image) and Phase 5 (entrypoint).

## Pi install method

`npm install -g @mariozechner/pi-coding-agent`

Binary name: `pi`. From <https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent>.

## Pi config and discovery paths

- **AGENTS.md locations** (all concatenated): `~/.pi/agent/AGENTS.md` (global), parent dirs walked up from cwd, the cwd itself.
- **models.json**: `~/.pi/agent/models.json`.
- **Skills directories**: `~/.pi/agent/skills/`, `~/.agents/skills/`, `.pi/skills/`, `.agents/skills/`.

### models.json schema for Ollama

Pi talks to Ollama through Ollama's OpenAI-compatible API at `/v1`, not the native API.

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

`apiKey` is required by Pi but Ollama ignores the value.

## sbx CLI surface

**The actual sbx CLI is more constrained than the spec assumed.** Findings from <https://docs.docker.com/ai/sandboxes/> and <https://docs.docker.com/ai/sandboxes/customize/templates/>:

### Custom templates

- Templates extend a base image: `FROM docker/sandbox-templates:<variant>`. Variants: `claude-code`, `codex`, `copilot`, `cursor-agent`, `shell`.
- For Pi (a non-built-in agent), the right base is `shell` — gives a generic shell-based sandbox.
- Built with regular `docker build -t <registry>/<name>:<tag> --push .` (must be pushed to a registry — Docker Hub, ghcr.io, etc.). There is no `sbx build`.
- Used with `sbx run --template <registry>/<name>:<tag> <agent-type>`, where agent-type matches the base variant (`shell` here).

### What's NOT in sbx

These flags from our plan **do not exist**:

- ❌ `--image` (use `--template <registry-image>` instead)
- ❌ `--mount` (workspace is auto-mounted from cwd)
- ❌ `--env` for arbitrary env vars (open issue: <https://github.com/docker/sbx-releases/issues/7>)
- ❌ `--policy` (network policy is global)

### Network policy

Global, managed via `sbx policy`:

- `sbx policy ls` — list current allowlist
- `sbx policy allow network <host>` — add a host
- The default policy is chosen at `sbx login` (Open / Balanced / Locked Down). Balanced allows common dev sites by default (npm, PyPI, GitHub, container registries).

There is no per-run policy file. To allow the host's LAN IP:11434 each time it changes, `sbx-up` must run `sbx policy allow network <new-ip>:11434`.

### Per-run state and persistence

Per-workspace state behavior is auto-keyed to the workspace path; not researched in detail but matches the spec's assumption.

### The big constraint: no env var injection

There is no documented way to pass `LAN_IP=<ip>` as an env var into a sbx run. Workarounds:

- **A. Write a runtime file into a known workspace location** (e.g. `${PWD}/.sbx/runtime.env`) before launch, have the entrypoint source it on boot. Visible to the project workspace.
- **B. Write LAN_IP into a per-workspace state file via `sbx`'s persistence layer** before launch. Cleaner but requires invoking something inside the VM during launch, which sbx doesn't expose pre-shell.
- **C. Use a stable hostname** that resolves to the LAN IP from inside the VM. Whether sbx provides such a hostname is undocumented.
- **D. Bake the LAN IP into the template at build time** — broken because IP changes.

## Ollama model tag

Not yet looked up. The likely tag based on the user's brief is `qwen3:35b-a3b` or similar — the user said `Qwen3.6-35B-A3B`. Confirm at impl time on `ollama.com/library`.

## Base image choice

The image must extend `docker/sandbox-templates:shell`. No choice between debian/ubuntu — that's whatever the upstream sandbox-templates use. Our Dockerfile starts:

```dockerfile
FROM docker/sandbox-templates:shell
USER root
RUN apt-get update && apt-get install -y nodejs npm git ripgrep jq curl gettext-base \
    && rm -rf /var/lib/apt/lists/*
RUN npm install -g @mariozechner/pi-coding-agent
USER agent  # or whatever the upstream user is
```

Whether `nodejs` from apt is recent enough for Pi, and what user the shell template runs as, both need confirmation at impl time.

## Critical design changes the plan needs

The spec/plan was written assuming `sbx run --image X --policy Y --mount Z --env K=V`. Actual sbx is:

1. **No `sbx build`** → use `docker build --push <registry>/<image>:<tag>`. Requires a registry account. `make setup` needs `docker login` flow.
2. **No `--image`** → use `--template <registry>/<image>:<tag>`.
3. **No `--mount`** → workspace auto-mounted from cwd.
4. **No `--policy`** → run `sbx policy allow network <ip>:11434` per `sbx-up` (global state).
5. **No `--env`** → no env var injection. Need a different way to pass LAN_IP into the VM.

This is a meaningful redesign of `bin/sbx-up` and `image/Dockerfile`, and changes the user-facing setup flow (registry account required).
