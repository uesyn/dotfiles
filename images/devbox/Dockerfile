FROM debian:bookworm
ENV USERNAME=devbox
ENV USER_UID=1000
ENV USER_GID=$USER_UID
ENV LANG=en_US.UTF-8

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt update && \
    apt install -y --no-install-recommends \
        software-properties-common \
        apt-transport-https \
        apt-utils \
        gnupg2 \
        curl \
        ca-certificates \
        apparmor \
        build-essential \
        dnsutils \
        docker.io \
        git \
        git-lfs \
        iproute2 \
        iputils-ping \
        jq \
        less \
        locales \
        lsb-release \
        lsof \
        man-db \
        manpages \
        manpages-dev \
        netcat-openbsd \
        net-tools \
        openssh-client \
        procps \
        psmisc \
        rsync \
        supervisor \
        sudo \
        time \
        tini \
        tzdata \
        unzip \
        vim \
        wget \
        zsh \
        zip \
        zstd && \
    apt autoremove -y && \
    apt clean

RUN update-alternatives --set iptables /usr/sbin/iptables-legacy && \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

RUN groupadd --gid $USER_GID $USERNAME && \
    useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -G docker -m $USERNAME && \
    echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && locale-gen && \
    chsh -s /usr/bin/zsh ${USERNAME}

COPY bootstrap /usr/local/share/bootstrap
COPY docker-init /usr/local/bin/docker-init
COPY entrypoint /usr/local/share/entrypoint
COPY supervisor/conf.d /etc/supervisor/conf.d
USER ${USERNAME}
ENTRYPOINT ["tini"]
CMD ["/usr/local/share/entrypoint"]