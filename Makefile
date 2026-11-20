.PHONY: login build push

IMAGE := ghcr.io/fhassis/devcontainer
TAG ?= latest

# Docker login to ghcr.io with the GitHub CLI's token. Once per machine:
#   winget install --id GitHub.cli -e          (Windows; on Linux, your package manager)
#   gh auth login                              (GitHub.com, SSH, browser)
#   gh auth refresh -s write:packages,read:packages
login:
	gh auth token | docker login ghcr.io -u fhassis --password-stdin

# --pull refreshes the debian base image.
build:
	docker build --pull -t $(IMAGE):$(TAG) src

push:
	docker push $(IMAGE):$(TAG)
