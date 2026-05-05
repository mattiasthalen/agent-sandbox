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
    && rm -rf /var/lib/apt/lists/*

# Node 20 from NodeSource (Pi requires a recent Node; Debian's apt is often too old).
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# mise
RUN curl -fsSL https://mise.run | sh \
    && mv /root/.local/bin/mise /usr/local/bin/mise

# uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mv /root/.local/bin/uv /root/.local/bin/uvx /usr/local/bin/

# gh
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Pi (the agent)
RUN npm install -g @mariozechner/pi-coding-agent

# obra/superpowers skill collection
RUN git clone --depth 1 https://github.com/obra/superpowers.git /etc/agent-sandbox/superpowers

# Baked-in agent config and bootstrap script
COPY AGENTS.md /etc/agent-sandbox/AGENTS.md
COPY models.json /etc/agent-sandbox/models.json.tmpl
COPY setup.sh /etc/agent-sandbox/setup.sh
RUN chmod +x /etc/agent-sandbox/setup.sh \
    && printf '#!/usr/bin/env bash\nsource /etc/agent-sandbox/setup.sh\n' \
       > /etc/profile.d/agent-sandbox.sh \
    && chmod +x /etc/profile.d/agent-sandbox.sh

# Pi config lives in $HOME/.pi/agent. The shell template's user is `agent`
# (uid 1000) per docker/sandbox-templates conventions; confirm with
# `docker run --rm docker/sandbox-templates:shell id` if the build fails.
USER agent
RUN mkdir -p /home/agent/.pi/agent \
    && ln -s /etc/agent-sandbox/AGENTS.md /home/agent/.pi/agent/AGENTS.md \
    && ln -s /etc/agent-sandbox/superpowers /home/agent/.pi/agent/skills

USER root
