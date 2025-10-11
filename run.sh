#!/bin/bash

SETUP_KEY_FILE="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.setup_key"
BASHINIT_FILE="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.bash_init"
MOUNT_DIR_FILE="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.mount_dir"

# check for setup key file
[[ ! -f "$SETUP_KEY_FILE" ]] && echo "File '.setup_key' is missing! create it, and write netbird setup key in it!" && exit 1
if [[ -f "$MOUNT_DIR_FILE" ]]; then
    MOUNT_DIR="$(realpath "$(cat "$MOUNT_DIR_FILE")")"
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
volumes=()
[[ -n "$MOUNT_DIR" ]] && volumes+=( -v "$MOUNT_DIR:/data" )
[[ -f "$BASHINIT_FILE" ]] && volumes+=( -v "$BASHINIT_FILE:/root/.bash_init" )

podman run --rm -it \
    --cap-add NET_ADMIN \
    --cap-add SYS_ADMIN \
    --cap-add NET_RAW \
    --device /dev/net/tun \
    -e NB_SETUP_KEY="$(cat "$SETUP_KEY_FILE")" \
    --security-opt label=type:container_runtime_t \
    "${volumes[@]}" \
    ghcr.io/daniele47/netbird bash
