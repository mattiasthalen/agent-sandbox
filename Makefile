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
