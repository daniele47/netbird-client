#!/bin/bash

SETUP_KEY_FILE="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.setup_key"

[[ ! -f "$SETUP_KEY_FILE" ]] && echo "File '.setup_key' is missing! create it, and write netbird setup key in it!" && exit 1

podman run -it --rm \
    --cap-add NET_ADMIN \
    --cap-add SYS_ADMIN \
    --cap-add NET_RAW \
    --device /dev/net/tun \
    -e NB_SETUP_KEY="$(cat "$SETUP_KEY_FILE")" \
    ghcr.io/daniele47/netbird bash
