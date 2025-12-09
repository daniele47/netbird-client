#!/bin/bash

# /usr/sbin/sshd # not run by default, to reduce vulnerability surface
/usr/local/bin/netbird-entrypoint.sh &>/dev/null &

exec "$@"
