.PHONY: image-build image-push

IMAGE := registry.gitlab.com/fhassis/devcontainer
TAG ?= latest

# --pull refreshes the base images (bun, uv, rust); cached RUN layers (glab,
# Claude Code) only move when an earlier layer changes.
image-build:
	docker build --pull -t $(IMAGE):$(TAG) src

image-push:
	docker push $(IMAGE):$(TAG)
