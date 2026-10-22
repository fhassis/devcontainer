.PHONY: build publish

IMAGE := registry.gitlab.com/fhassis/devcontainer
TAG ?= latest

# --pull refreshes the base images (bun, uv, rust); cached RUN layers (glab,
# Claude Code) only move when an earlier layer changes.
build:
	docker build --pull -t $(IMAGE):$(TAG) src

publish: build
	docker push $(IMAGE):$(TAG)
