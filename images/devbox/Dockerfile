FROM docker:dind@sha256:0e94d967b79da9ab21108997e338afd1cf53f8c86642c9b5acbfa286fde5e071 as dind

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
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy && \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && locale-gen
COPY --from=dind /usr/local/bin/docker /usr/local/bin/docker
ENTRYPOINT ["tail", "-f", "/dev/null"]