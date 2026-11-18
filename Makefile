.PHONY: image-build image-push

IMAGE := registry.gitlab.com/fhassis/devcontainer
TAG ?= latest

# --pull refreshes the debian base image; cached RUN layers (uv, fnm, rustup,
# Claude Code) only move when an earlier layer changes.
image-build:
	docker build --pull -t $(IMAGE):$(TAG) src

image-push:
	docker push $(IMAGE):$(TAG)
