#!/bin/bash

SETUP_KEY_FILE="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.setup_key"
BASHINIT_FILE="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.bash_init"

[[ ! -f "$SETUP_KEY_FILE" ]] && echo "File '.setup_key' is missing! create it, and write netbird setup key in it!" && exit 1

# mount bash init if it exists
bash_init=()
[[ -f "$BASHINIT_FILE" ]] && bash_init+=(--security-opt label=type:container_runtime_t -v "$BASHINIT_FILE:/root/.bash_init")

podman run -it --rm \
    --cap-add NET_ADMIN \
    --cap-add SYS_ADMIN \
    --cap-add NET_RAW \
    --device /dev/net/tun \
    -e NB_SETUP_KEY="$(cat "$SETUP_KEY_FILE")" \
    "${bash_init[@]}" \
    ghcr.io/daniele47/netbird bash
