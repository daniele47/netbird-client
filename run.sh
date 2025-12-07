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
#   STOP            ---> remove all containers managed by the script
#   RESTART         ---> remove all containers managed by the script and then launch a new one
#   VERBOSE         ---> verbose output
#
# parameters:
#   $1              ---> specify mount directory (overrides the one specified in the mount_dir file)

# variables
IMAGE_URL="ghcr.io/daniele47/netbird-client:latest"
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
SCRIPT_HASH="$(sha256sum "$SCRIPT_PATH" | cut -d' ' -f1)"
TWEAKS_DIR="$SCRIPT_DIR/.tweaks"
SETUP_KEY_FILE="$TWEAKS_DIR/setup_key"
HOSTNAME_FILE="$TWEAKS_DIR/hostname"
BASHINIT_FILE="$TWEAKS_DIR/bash_init"
MOUNT_DIR_FILE="$TWEAKS_DIR/mount_dir"
SSH_CONF_DIR="$TWEAKS_DIR/ssh"

# utility functions
function clr_msg(){
    case "$1" in
        error) echo -e "\e[1;31mERROR: ${@:2}\e[m";;
        warning) echo -e "\e[1;33mWARNING: ${@:2}\e[m" ;;
        verbose) [[ -v VERBOSE ]] && echo -e "\e[1;34mVERBOSE: ${@:2}\e[m" ;;
        *) "$FUNCNAME" warning "INVALID CLG_MSG PARAMETER: '$1'" ;;
    esac
}
function list_containers(){
    podman ps -a -q --filter "ancestor=$IMAGE_URL" --filter "label=script=netbird-client" --format "{{.ID}}"
}

# create directories and files
mkdir -p "$TWEAKS_DIR" "$SSH_CONF_DIR"
touch "$SETUP_KEY_FILE" "$HOSTNAME_FILE" "$BASHINIT_FILE" "$MOUNT_DIR_FILE"

# various checks
[[ "$#" -gt 1 ]] && clr_msg error 'too many parameters passed' && exit 1
! [[ -s "$SETUP_KEY_FILE" ]] && clr_msg error 'setup_key file is empty' && exit 1
! [[ -s "$HOSTNAME_FILE" ]] && clr_msg error 'hostname file is empty' && exit 1
[[ -v RESTART && -v STOP ]] && clr_msg error 'RESTART and STOP cannot be used togheter' && exit 1
[[ -v SERVE && -v STOP ]] && clr_msg error 'SERVE and STOP cannot be used togheter' && exit 1

# get and validate mount directory
MOUNT_DIR=""
if [[ -s "$MOUNT_DIR_FILE" ]]; then
    MOUNT_DIR="$(realpath "$(cat "$MOUNT_DIR_FILE")")"
    MOUNT_DIR="${1:-$MOUNT_DIR}"
    MOUNT_DIR_DIR="$(dirname "$MOUNT_DIR")"
    if [ ! -d "$MOUNT_DIR" ] || [ ! -w "$MOUNT_DIR" ] || [ ! -O "$MOUNT_DIR" ]; then
        clr_msg error "invalid mount dir: $MOUNT_DIR"
        exit 1
    fi
    if [ ! -d "$MOUNT_DIR_DIR" ] || [ ! -w "$MOUNT_DIR_DIR" ] || [ ! -O "$MOUNT_DIR_DIR" ]; then
        clr_msg error "invalid mount dir: $MOUNT_DIR"
        exit 1
    fi
fi 

# mount bash init if it exists
volumes=( -v "$BASHINIT_FILE:/root/.bash_init" -v "$SSH_CONF_DIR:/root/.ssh")
if [[ -n "$MOUNT_DIR" ]]; then
    volumes+=( -v "$MOUNT_DIR:/data" -w /data )
    clr_msg verbose "mounting '$MOUNT_DIR' into the container"
fi

# run container and launch if necessary
if [[ -v STOP ]] || [[ -v RESTART ]]; then
    list_containers | while read -r line; do
        output="$(podman rm -f "$line")"
        clr_msg verbose "removing container '$output'"
    done
    [[ -v STOP ]] && exit
fi
[[ "$(list_containers | wc -l)" -gt 1 ]] && clr_msg error 'there are multiple containers running' && exit 1
if [[ "$(list_containers | wc -l)" -eq 0 ]]; then
    output="$(podman run -d \
    --cap-add NET_ADMIN \
    --cap-add SYS_ADMIN \
    --cap-add NET_RAW \
    --device /dev/net/tun \
    --label "script=netbird-client" \
    --label "script_hash=$SCRIPT_HASH" \
    -e NB_SETUP_KEY="$(cat "$SETUP_KEY_FILE")" \
    -e NB_HOSTNAME="$(cat "$HOSTNAME_FILE")" \
    --hostname "$(cat "$HOSTNAME_FILE")" \
    --security-opt label=type:container_runtime_t \
    -w /root \
    "${volumes[@]}" \
    "$IMAGE_URL" tini sleep infinity)"
    clr_msg verbose "launched new countainer '$output'"
fi
container="$(list_containers | head -1)"
container_hash="$(podman inspect "$container" --format '{{ index .Config.Labels "script_hash" }}')"
[[ "$SCRIPT_HASH" != "$container_hash" ]] && clr_msg error "script hash doesn't match container hash. restart the container" && exit 1
container_state="$(podman inspect -f '{{.State.Status}}' "$container")"
case "$container_state" in 
    running) ;;
    exited|created)
            clr_msg verbose "starting container from $container_state state"
            podman start "$container" >/dev/null
            ;;
        paused)
            clr_msg verbose "unpausing container"
            podman unpause "$container" >/dev/null
            ;;
    *) 
        clr_msg error "not managed container state '$container_state'"
        exit 1
        ;;
esac
if [[ ! -v SERVE ]]; then podman exec -it "$container" bash; fi
