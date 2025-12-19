FROM ubuntu:22.04

# AGGRESSIVE non-interactive settings
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true
ENV DEBIAN_PRIORITY=critical
ENV TZ=Etc/UTC

# Pre-seed ALL debconf questions
RUN echo 'tzdata tzdata/Areas select Etc' | debconf-set-selections && \
    echo 'tzdata tzdata/Zones/Etc select UTC' | debconf-set-selections && \
    echo 'keyboard-configuration keyboard-configuration/layout select English (US)' | debconf-set-selections && \
    echo 'keyboard-configuration keyboard-configuration/variant select English (US)' | debconf-set-selections && \
    echo 'locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8' | debconf-set-selections && \
    echo 'locales locales/default_environment_locale select en_US.UTF-8' | debconf-set-selections

# Update and install with forced defaults
RUN apt-get update && \
    apt-get -y --no-install-recommends install \
    keyboard-configuration \
    && apt-get -y --no-install-recommends install \
    curl wget git nano vim tmux htop \
    build-essential software-properties-common \
    net-tools iputils-ping dnsutils \
    python3 python3-pip python3-venv \
    nodejs npm \
    openjdk-17-jdk \
    golang-go \
    chromium-browser chromium-chromedriver \
    unzip zip \
    xfce4 xfce4-goodies \
    rclone \
    netcat socat \
    tzdata locales \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Create user
RUN useradd -m -s /bin/bash coder && \
    echo "coder:coder" | chpasswd && \
    mkdir -p /home/coder/workspace && \
    mkdir -p /home/coder/.config/code-server && \
    mkdir -p /home/coder/scripts && \
    mkdir -p /home/coder/logs && \
    mkdir -p /home/coder/.cookies && \
    chown -R coder:coder /home/coder

# Switch to coder user for code-server installation
USER coder
WORKDIR /home/coder

# Install code-server as coder user
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Install VS Code extensions as coder user
RUN code-server --install-extension ms-python.python && \
    code-server --install-extension ms-python.vscode-pylance && \
    code-server --install-extension formulahendry.code-runner && \
    code-server --install-extension eamodio.gitlens && \
    code-server --install-extension yzhang.markdown-all-in-one

# Install cloudflared as coder user
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared; \
    elif [ "$ARCH" = "aarch64" ]; then \
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O /usr/local/bin/cloudflared; \
    fi && \
    chmod +x /usr/local/bin/cloudflared

# Copy configs as coder user
COPY --chown=coder:coder config.yaml /home/coder/.config/code-server/
COPY --chown=coder:coder scripts/ /home/coder/scripts/

# Set permissions
RUN chmod +x /home/coder/scripts/*

# Switch back to root for startup
USER root

EXPOSE 8080 3000 8081
WORKDIR /home/coder

CMD ["/bin/bash", "/home/coder/scripts/startup.sh"]
