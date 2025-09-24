FROM docker.io/netbirdio/netbird

# install needed package
RUN apk add openssh samba rclone

# put files in place
COPY ./bashrc /root/.bashrc

# change init command
ENTRYPOINT /bin/bash -c "/usr/local/bin/netbird-entrypoint.sh &>/dev/null & /bin/bash"
