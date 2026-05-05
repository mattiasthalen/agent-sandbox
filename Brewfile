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
