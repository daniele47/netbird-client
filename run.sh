#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
TWEAKS_DIR="$SCRIPT_DIR/.tweaks"
SETUP_KEY_FILE="$TWEAKS_DIR/setup_key"
BASHINIT_FILE="$TWEAKS_DIR/bash_init"
MOUNT_DIR_FILE="$TWEAKS_DIR/mount_dir"
SSH_CONF_DIR="$TWEAKS_DIR/ssh"

# checks files exist
[[ "$#" -gt 1 ]] && echo 'too many parameters passed' && exit 1
mkdir -p "$TWEAKS_DIR" "$SSH_CONF_DIR"
touch "$SETUP_KEY_FILE" "$BASHINIT_FILE" "$MOUNT_DIR_FILE"
! [[ -s "$SETUP_KEY_FILE" ]] && echo 'setup_key file is empty' && exit 1
if [[ -s "$MOUNT_DIR_FILE" ]]; then
    MOUNT_DIR="$(realpath "$(cat "$MOUNT_DIR_FILE")")"
    MOUNT_DIR="${1:-$MOUNT_DIR}"
    MOUNT_DIR_DIR="$(dirname "$MOUNT_DIR")"
    if [ ! -d "$MOUNT_DIR" ] || [ ! -w "$MOUNT_DIR" ] || [ ! -O "$MOUNT_DIR" ]; then
        echo "invalid mount dir: $MOUNT_DIR"
        exit 1
    fi
    if [ ! -d "$MOUNT_DIR_DIR" ] || [ ! -w "$MOUNT_DIR_DIR" ] || [ ! -O "$MOUNT_DIR_DIR" ]; then
        echo "invalid mount dir: $MOUNT_DIR"
        exit 1
    fi
fi 

# mount bash init if it exists
volumes=( -v "$BASHINIT_FILE:/root/.bash_init" -v "$SSH_CONF_DIR:/root/.ssh")
[[ -n "$MOUNT_DIR" ]] && volumes+=( -v "$MOUNT_DIR:/data" -w /data )

podman run --root "/tmp/podman-scripted-$(id -u)" --rm -it \
    --cap-add NET_ADMIN \
    --cap-add SYS_ADMIN \
    --cap-add NET_RAW \
    --device /dev/net/tun \
    -e NB_SETUP_KEY="$(cat "$SETUP_KEY_FILE")" \
    --security-opt label=type:container_runtime_t \
    -w /root \
    "${volumes[@]}" \
    ghcr.io/daniele47/netbird bash
