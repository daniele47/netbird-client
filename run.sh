#!/bin/bash

set -euo pipefail
trap 'echo "SCRIPT FAILURE: line $LINENO, exit code: $?, command: $BASH_COMMAND"' ERR

# variables
IMAGE_URL="ghcr.io/daniele47/netbird-client:latest"
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
SCRIPT_HASH="$(sha256sum "$SCRIPT_PATH" | cut -d' ' -f1)"
TWEAKS_DIR="$SCRIPT_DIR/.tweaks"
SETUP_KEY_FILE="$TWEAKS_DIR/setup_key"
HOSTNAME_FILE="$TWEAKS_DIR/hostname"
SSH_CONF_DIR="$TWEAKS_DIR/ssh"

# utility functions
function clr_msg(){
    case "$1" in
        error) echo -e "\e[1;31mERROR: ${@:2}\e[m";;
        err_exit) "$FUNCNAME" error "${@:2}"; exit 1 ;;
        warning) echo -e "\e[1;33mWARNING: ${@:2}\e[m" ;;
        verbose) if "$VERBOSE"; then echo -e "\e[1;34mVERBOSE: ${@:2}\e[m"; fi ;;
        help) echo -e "\e[1;37m${@:2}\e[m" ;;
        *) "$FUNCNAME" err_exit "INVALID CLG_MSG PARAMETER: '$1'" ;;
    esac
}
function list_containers(){
    podman ps -a -q --filter "ancestor=$IMAGE_URL" --filter "label=script=netbird-client" --format "{{.ID}}"
}

# parse flags
END=false SERVE=false RESTART=false VERBOSE=false HELP=false
invalid_flags=false
declare -A unknow_options invalid_combos
while getopts ":servh" opt; do
    case $opt in
        s) SERVE=true ;;
        e) END=true ;;
        r) RESTART=true ;;
        v) VERBOSE=true ;;
        h) HELP=true ;;
        *)
            if [[ "${unknow_options["$OPTARG"]:-0}" == 0 ]]; then
                clr_msg error "unknown option -$OPTARG";
                invalid_flags=true
                unknow_options["$OPTARG"]=1
            fi
            ;;
    esac
done
while read -r VAR1 VAR2 FLAG1 FLAG2; do
    if "${!VAR1}" && "${!VAR2}" && [[ "${invalid_combos["$FLAG1-$FLAG2"]:-0}" == 0 ]]; then
        clr_msg error "-$FLAG1 and -$FLAG2 cannot be used togheter";
        invalid_flags=true
        invalid_combos["$FLAG1-$FLAG2"]=1
    fi
done <<EOF
SERVE END s e
SERVE HELP s h
END RESTART e r
END HELP e h
RESTART HELP r h
EOF
if "$invalid_flags"; then exit 1; fi

# show help message if necessary
if "$HELP"; then
    clr_msg help 'script to spun up a single netbird container, which is then shared

    configurable files:
    .tweaks/
    ├── ssh/        ---> mounted to /root/.ssh
    ├── hostname    ---> specifies container hostname to netbird
    └── setup_key   ---> specified setup key to access netbird vpn network

    option flags:
    -s [  rv ]      ---> serve container non interactively in the background
    -e [   v ]      ---> end container managed by the script
    -r [s  v ]      ---> restart container managed by the script
    -v [ser h]      ---> verbose output
    -h [   v ]      ---> help message
    '
    exit 0;
fi

# create directories and files
mkdir -p "$TWEAKS_DIR" "$SSH_CONF_DIR"
touch "$SETUP_KEY_FILE" "$HOSTNAME_FILE"

# various checks
if [[ ! -s "$SETUP_KEY_FILE" ]]; then clr_msg err_exit 'setup_key file is empty'; fi
if [[ ! -s "$HOSTNAME_FILE" ]]; then clr_msg err_exit 'hostname file is empty'; fi

# run container and launch if necessary
if "$END" || "$RESTART"; then
    list_containers | while read -r line; do
        output="$(podman rm -f "$line")"
        clr_msg verbose "removed container '$output'"
    done
    if "$END"; then exit; fi
elif [[ "$(list_containers | wc -l)" -gt 1 ]]; then
    clr_msg err_exit "there are multiple containers running"
elif [[ "$(list_containers | wc -l)" -eq 1 ]]; then
    container="$(list_containers | head -1)"
    container_hash="$(podman inspect "$container" --format '{{ index .Config.Labels "script_hash" }}')"
    if [[ "$SCRIPT_HASH" != "$container_hash" ]]; then
        clr_msg err_exit "script hash and container hash do not match. restart the container"
    fi
fi
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
    -w /root \
    -v "$SSH_CONF_DIR:/root/.ssh" \
    "$IMAGE_URL" tini sleep infinity)"
    clr_msg verbose "launched new countainer '$output'"
fi

# set container in running state and launch if necessary
container="$(list_containers | head -1)"
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
    *) clr_msg err_exit "not managed container state '$container_state'" ;;
esac
if ! "$SERVE"; then podman exec -it "$container" bash; fi
