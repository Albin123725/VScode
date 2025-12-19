FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_PRIORITY=critical
ENV TZ=Etc/UTC

# Configure keyboard to US English BEFORE any apt-get installs
RUN echo "keyboard-configuration keyboard-configuration/layoutcode string us" > /tmp/keyboard-configuration.preseed && \
    echo "keyboard-configuration keyboard-configuration/variantcode string" >> /tmp/keyboard-configuration.preseed && \
    echo "keyboard-configuration keyboard-configuration/unsupported_config_options boolean true" >> /tmp/keyboard-configuration.preseed && \
    debconf-set-selections /tmp/keyboard-configuration.preseed

# Update and install essentials with auto-confirm
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # Basic tools
    curl wget git nano vim tmux htop \
    build-essential software-properties-common \
    net-tools iputils-ping dnsutils \
    # Programming languages
    python3 python3-pip python3-venv \
    nodejs npm \
    openjdk-17-jdk \
    golang-go \
    # Browser automation
    chromium-browser chromium-chromedriver \
    unzip zip \
    # For RDP backup (optional)
    xfce4 xfce4-goodies \
    # File management
    rclone \
    # Monitoring
    netcat socat \
    # Fix timezone and locales
    tzdata locales \
    && rm -rf /var/lib/apt/lists/*

# Set timezone and locale to US English
RUN ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install code-server (latest)
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Install cloudflared
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared; \
    elif [ "$ARCH" = "aarch64" ]; then \
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O /usr/local/bin/cloudflared; \
    fi && \
    chmod +x /usr/local/bin/cloudflared

# Create user with password 'coder' (change later)
RUN useradd -m -s /bin/bash coder && \
    echo "coder:coder" | chpasswd && \
    mkdir -p /home/coder/workspace && \
    mkdir -p /home/coder/.config/code-server && \
    mkdir -p /home/coder/scripts && \
    mkdir -p /home/coder/logs && \
    chown -R coder:coder /home/coder

# Copy configs
COPY config.yaml /home/coder/.config/code-server/
COPY startup.sh /home/coder/scripts/
COPY health-server.py /home/coder/scripts/

# Set permissions
RUN chmod +x /home/coder/scripts/* && \
    chown -R coder:coder /home/coder

# VS Code extensions to pre-install
USER coder
WORKDIR /home/coder/workspace

# Install Python extensions
RUN code-server --install-extension ms-python.python \
    --install-extension ms-python.vscode-pylance \
    --install-extension formulahendry.code-runner \
    --install-extension eamodio.gitlens \
    --install-extension yzhang.markdown-all-in-one

# Switch back to root for CMD
USER root

EXPOSE 8080 3000 8081
WORKDIR /home/coder

CMD ["/bin/bash", "/home/coder/scripts/startup.sh"]
