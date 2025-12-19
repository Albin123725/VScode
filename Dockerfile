FROM ubuntu:22.04

# Update and install essentials
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
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
    && rm -rf /var/lib/apt/lists/*

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
    --install-extension yzhang.markdown-all-in-one \
    --install-extension oderwat.indent-rainbow \
    --install-extension CoenraadS.bracket-pair-colorizer

# Switch back to root for CMD
USER root

EXPOSE 8080 3000
WORKDIR /home/coder

CMD ["/bin/bash", "/home/coder/scripts/startup.sh"]
