#!/bin/bash

podman run -it --rm \
    --cap-add NET_ADMIN \
    --cap-add SYS_ADMIN \
    --cap-add NET_RAW \
    --device /dev/net/tun \
    ghcr.io/daniele47/neovim bash
