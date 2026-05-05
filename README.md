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
