FROM docker:23.0.4 as docker

FROM debian:bookworm
ENV LANG=en_US.UTF-8
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt update && \
    apt install -y --no-install-recommends \
        apparmor \
        build-essential \
        ca-certificates \
        curl \
        dnsutils \
        git \
        git-lfs \
        gnupg2 \
        gosu \
        iproute2 \
        iptables \
        iputils-ping \
        jq \
        less \
        locales \
        lsof \
        man-db \
        manpages \
        net-tools \
        openssh-client \
        procps \
        psmisc \
        sudo \
        time \
        tzdata \
        unzip \
        vim \
        wget \
        zip \
        zsh \
        zstd && \
    apt autoremove -y && \
    apt clean
# https://github.com/pyenv/pyenv/wiki#suggested-build-environment
RUN apt install -y build-essential libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev curl \
        libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev && \
    apt autoremove -y && \
    apt clean
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy && \
      update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && locale-gen
RUN groupadd -g 9999 docker && \
      groupadd devbox -g 1000 && \
      useradd devbox -g 1000 -G docker
COPY sudoers.d/devbox /etc/sudoers.d/devbox
COPY --from=docker /usr/local/bin/docker /usr/local/bin/docker
USER devbox
ENTRYPOINT ["tail", "-f", "/dev/null"]