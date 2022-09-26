FROM debian:11
ENV USERNAME=uesyn
ENV USER_UID=1000
ENV USER_GID=$USER_UID
ENV LANG=en_US.UTF-8
ENV DEVBOX=y
ADD common-debian.sh /tmp/scripts/common-debian.sh
ADD sshd-debian.sh /tmp/scripts/sshd-debian.sh
ADD docker-in-docker-debian.sh /tmp/scripts/docker-in-docker-debian.sh
RUN apt-get update && \
    apt install -y curl git && \
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bullseye.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null && \
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bullseye.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list && \
    apt-get update
RUN chmod 755 /tmp/scripts/*
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get -y install build-essential tailscale && \
    bash /tmp/scripts/common-debian.sh "true" "${USERNAME}" "${USER_UID}" "${USER_GID}" "true" "false" "false" && \
    bash /tmp/scripts/docker-in-docker-debian.sh "true" "${USERNAME}" "true" && \
    bash /tmp/scripts/sshd-debian.sh && \
    apt-get autoremove -y && apt-get clean -y && \
    chsh -s /usr/bin/zsh ${USERNAME}
COPY tailscale-init.sh /usr/local/share
COPY entrypoint /usr/local/share
USER ${USERNAME}
ENTRYPOINT [ "/usr/local/share/docker-init.sh", "/usr/local/share/ssh-init.sh", "/usr/local/share/tailscale-init.sh" ]
CMD [ "/usr/local/share/entrypoint" ]