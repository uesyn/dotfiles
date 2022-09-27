FROM debian:11
ENV USERNAME=uesyn
ENV USER_UID=1000
ENV USER_GID=$USER_UID
ENV LANG=en_US.UTF-8
ADD common-debian.sh /tmp/scripts/common-debian.sh
ADD docker-in-docker-debian.sh /tmp/scripts/docker-in-docker-debian.sh
RUN chmod 755 /tmp/scripts/*
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get -y install build-essential && \
    bash /tmp/scripts/common-debian.sh "true" "${USERNAME}" "${USER_UID}" "${USER_GID}" "true" "false" "false" && \
    bash /tmp/scripts/docker-in-docker-debian.sh "true" "${USERNAME}" "true" && \
    apt-get autoremove -y && apt-get clean -y && \
    chsh -s /usr/bin/zsh ${USERNAME}
COPY entrypoint /usr/local/share
USER ${USERNAME}
ENTRYPOINT [ "/usr/local/share/docker-init.sh" ]
CMD [ "/usr/local/share/entrypoint" ]