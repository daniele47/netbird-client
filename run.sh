#!/bin/bash

# script to spun up a single netbird container, which is then shared
#
# configurable files:
#   .tweaks/
#   ├── ssh/        ---> mounted to /root/.ssh
#   ├── bash_init   ---> mounted to /root/.bash_init and called from .bashrc
#   ├── hostname    ---> specifies container hostname to netbird
#   ├── mount_dir   ---> allows mounting a single user directory into the container
#   └── setup_key   ---> specified setup key to access netbird vpn network
#
# environment variables:
#   SERVE           ---> if present run the container non interactively in the background
#
# parameters:
#   $1              ---> specify mount directory (overrides the one specified in the mount_dir file)

# variables
IMAGE_URL="ghcr.io/daniele47/netbird-client:latest"
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
TWEAKS_DIR="$SCRIPT_DIR/.tweaks"
SETUP_KEY_FILE="$TWEAKS_DIR/setup_key"
HOSTNAME_FILE="$TWEAKS_DIR/hostname"
BASHINIT_FILE="$TWEAKS_DIR/bash_init"
MOUNT_DIR_FILE="$TWEAKS_DIR/mount_dir"
SSH_CONF_DIR="$TWEAKS_DIR/ssh"

# create directories and files
mkdir -p "$TWEAKS_DIR" "$SSH_CONF_DIR"
touch "$SETUP_KEY_FILE" "$HOSTNAME_FILE" "$BASHINIT_FILE" "$MOUNT_DIR_FILE"

# various checks
[[ "$#" -gt 1 ]] && echo 'too many parameters passed' && exit 1
! [[ -s "$SETUP_KEY_FILE" ]] && echo 'setup_key file is empty' && exit 1
! [[ -s "$HOSTNAME_FILE" ]] && echo 'hostname file is empty' && exit 1

# get and validate mount directory
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

# make sure a container is running as a daemon, and if needed launch an interactive terminal
if [[ "$(podman ps -q --filter "ancestor=$IMAGE_URL" --format "{{.ID}}" | wc -l)" -eq 0 ]]; then
    podman run --rm -d \
    --cap-add NET_ADMIN \
    --cap-add SYS_ADMIN \
    --cap-add NET_RAW \
    --device /dev/net/tun \
    -e NB_SETUP_KEY="$(cat "$SETUP_KEY_FILE")" \
    -e NB_HOSTNAME="$(cat "$HOSTNAME_FILE")" \
    --hostname "$(cat "$HOSTNAME_FILE")" \
    --security-opt label=type:container_runtime_t \
    -w /root \
    "${volumes[@]}" \
    "$IMAGE_URL" tini sleep infinity
fi
[[ ! -v SERVE ]] && podman exec -it "$(podman ps -q --filter "ancestor=$IMAGE_URL" --format "{{.ID}}" | head -1)" bash

# exit with correct status code
exit 0
