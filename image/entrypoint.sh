#!/bin/bash

/usr/sbin/sshd
/usr/local/bin/netbird-entrypoint.sh &>/dev/null &

exec "$@"
