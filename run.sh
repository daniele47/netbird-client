#!/bin/bash

set -euo pipefail
trap 'echo "SCRIPT FAILURE: line $LINENO, exit code: $?, command: $BASH_COMMAND"' ERR

# variables
IMAGE_URL="ghcr.io/daniele47/netbird-client:latest"
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
TWEAKS_DIR="$SCRIPT_DIR/.tweaks"
SETUP_KEY_FILE="$TWEAKS_DIR/setup_key"
HOSTNAME_FILE="$TWEAKS_DIR/hostname"
SSH_CONF_DIR="$TWEAKS_DIR/ssh"
DATA_DIR="$TWEAKS_DIR/data"

# create directories and files
mkdir -p "$TWEAKS_DIR" "$SSH_CONF_DIR" "$DATA_DIR"
touch "$SETUP_KEY_FILE" "$HOSTNAME_FILE"

# various checks
if [[ ! -s "$SETUP_KEY_FILE" ]]; then echo 'setup_key file is empty'; exit 1; fi
if [[ ! -s "$HOSTNAME_FILE" ]]; then echo 'hostname file is empty'; exit 1; fi

# run container
podman run --rm -it \
    --cap-add NET_ADMIN \
    --cap-add SYS_ADMIN \
    --cap-add NET_RAW \
    --device /dev/net/tun \
    -e NB_SETUP_KEY="$(cat "$SETUP_KEY_FILE")" \
    -e NB_HOSTNAME="$(cat "$HOSTNAME_FILE")" \
    --hostname "$(cat "$HOSTNAME_FILE")" \
    -v "$SSH_CONF_DIR:/root/.ssh" \
    -v "$DATA_DIR:/root/data/" \
    -w /root \
    --security-opt label=type:container_runtime_t \
    "$IMAGE_URL" || true
