FROM ubuntu:22.04
ENV LANG=en_US.UTF-8
# add metadata, must be done after the squashing
# first tell systemd that it is in docker (it will check for the container env)
# https://systemd.io/CONTAINER_INTERFACE/
ENV container docker
# systemd exits on SIGRTMIN+3, not SIGTERM (which re-executes it)
# https://bugzilla.redhat.com/show_bug.cgi?id=1201657
STOPSIGNAL SIGRTMIN+3
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt update && \
    apt install -y --no-install-recommends \
        ca-certificates curl gnupg gnupg2 && \
    rm -rf /var/lib/apt/lists/* && \
    apt clean
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt update && \
    apt install -y --no-install-recommends \
        systemd && \
        find /lib/systemd/system/sysinit.target.wants/ -name "systemd-tmpfiles-setup.service" -delete && \
        rm -f /lib/systemd/system/multi-user.target.wants/* && \
        rm -f /etc/systemd/system/*.wants/* && \
        rm -f /lib/systemd/system/local-fs.target.wants/* && \
        rm -f /lib/systemd/system/sockets.target.wants/*udev* && \
        rm -f /lib/systemd/system/sockets.target.wants/*initctl* && \
        rm -f /lib/systemd/system/basic.target.wants/* && \
        echo "ReadKMsg=no" >> /etc/systemd/journald.conf && \
        ln -s "$(which systemd)" /sbin/init && \
    rm -rf /var/lib/apt/lists/* && \
    apt clean
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt update && \
    apt install -y --no-install-recommends \
        apparmor \
        build-essential \
        dnsutils \
        file \
        git \
        git-lfs \
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
    rm -rf /var/lib/apt/lists/* && \
    apt clean
ENV PATH=${PATH}:/usr/libexec/docker/cli-plugins
RUN export DEBIAN_FRONTEND=noninteractive && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
         "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" > /etc/apt/sources.list.d/docker.list && \
    apt update && \
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin && \
    rm -rf /var/lib/apt/lists/* && \
    apt clean
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt update && \
    apt install -y --no-install-recommends \
    openssh-server && \
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
RUN locale-gen en_US.UTF-8 ja_JP.UTF-8
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy && \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
RUN groupadd devbox -g 1000 && \
    useradd devbox -s /usr/bin/zsh -g 1000 -G docker
COPY sudoers.d/devbox /etc/sudoers.d/devbox
COPY bin/ /usr/local/bin/
ENTRYPOINT ["/sbin/init"]