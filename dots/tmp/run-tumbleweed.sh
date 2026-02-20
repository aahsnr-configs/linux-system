#!/bin/bash

# Define the official openSUSE Tumbleweed image location
IMAGE="registry.opensuse.org/opensuse/tumbleweed"

# 1. Pull the latest version of the image to ensure you have recent updates
echo "Fetching the latest openSUSE Tumbleweed image..."
podman pull opensuse/tumbleweed:latest

# 2. Run the container
# -i: Keeps STDIN open (interactive)
# -t: Allocates a pseudo-TTY (so you get a command prompt)
# --rm: Automatically removes the container when you exit (keeps your disk clean)
# --name: Gives the container a friendly name
# bash -c "...": Runs a command to refresh repositories immediately, then opens a shell
echo "Starting container... (Running 'zypper ref' automatically)"
podman run -it --rm \
  --name tumbleweed_zypper \
  "$IMAGE" \
  bash -c "zypper ref && exec bash"
