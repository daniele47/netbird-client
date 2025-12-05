FROM docker.io/netbirdio/netbird

# install needed package
RUN apk update && apk upgrade && apk fix
RUN apk add --no-cache openssh autossh neovim git bash-completion lsd zoxide bat
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config && \
    echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'ChallengeResponseAuthentication no' >> /etc/ssh/sshd_config && \
    ssh-keygen -A

# put files in place
COPY ./bashrc /root/.bashrc
COPY ./gitconfig /root/.gitconfig
COPY ./nvim /root/.config/nvim
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# change init command
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
