FROM docker.io/netbirdio/netbird

# install needed package
RUN apk update && apk upgrade && apk fix
RUN apk add openssh neovim git bash-completion

# put files in place
COPY ./bashrc /root/.bashrc
COPY ./gitconfig /root/.gitconfig
COPY ./nvim /root/.config/nvim

# change init command
ENTRYPOINT /bin/bash -c "/usr/local/bin/netbird-entrypoint.sh &>/dev/null & /bin/bash"
