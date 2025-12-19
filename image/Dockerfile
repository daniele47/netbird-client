FROM docker.io/netbirdio/netbird

# install needed package
RUN apk update && apk upgrade && apk fix
RUN apk add --no-cache neovim git bash-completion zoxide bat tini

# put files in place
COPY ./bashrc /root/.bashrc
COPY ./gitconfig /root/.gitconfig
COPY ./nvim /root/.config/nvim
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# change init command
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
