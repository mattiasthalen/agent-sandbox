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
