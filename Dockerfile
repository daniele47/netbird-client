FROM docker.io/netbirdio/netbird

# install needed package
RUN apk update && apk upgrade && apk fix
RUN apk add --no-cache openssh neovim bash-completion tini

# change init command
ENTRYPOINT ["/bin/sh", "-c", "/usr/local/bin/netbird-entrypoint.sh > /dev/null & exec \"$@\"", "--"]
CMD [ "/bin/bash" ]
