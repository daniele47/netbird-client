FROM docker.io/netbirdio/netbird

# install needed package
RUN apk add openssh

# change init command
ENTRYPOINT /bin/bash -c "/usr/local/bin/netbird-entrypoint.sh &>/dev/null & /bin/bash"
