FROM ubuntu:22.04

# ============================================================================
# SYSTEM CONFIGURATION
# ============================================================================
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

# ============================================================================
# PACKAGE INSTALLATION
# ============================================================================
RUN apt-get update && \
    apt-get -y --no-install-recommends install \
    keyboard-configuration \
    && apt-get -y --no-install-recommends install \
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
    # Desktop environment (optional)
    xfce4 xfce4-goodies \
    # File management
    rclone \
    # Monitoring
    netcat socat \
    # System
    tzdata locales ca-certificates gnupg \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# LOCALE & TIME CONFIGURATION
# ============================================================================
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# ============================================================================
# CODE-SERVER INSTALLATION - PINNED VERSION (FIXED)
# ============================================================================
RUN VERSION="4.24.0" && \
    ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        ARCH_SUFFIX="amd64"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        ARCH_SUFFIX="arm64"; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    # Verified URL pattern for v4.24.0
    wget "https://github.com/coder/code-server/releases/download/v${VERSION}/code-server_${VERSION}_linux_${ARCH_SUFFIX}.tar.gz" -O /tmp/code-server.tar.gz && \
    tar -xzf /tmp/code-server.tar.gz -C /tmp && \
    mv /tmp/code-server_${VERSION}_linux_${ARCH_SUFFIX} /usr/lib/code-server && \
    ln -s /usr/lib/code-server/bin/code-server /usr/local/bin/code-server && \
    rm -f /tmp/code-server.tar.gz && \
    echo "✅ code-server v${VERSION} installed successfully"

# ============================================================================
# CLOUDFLARED INSTALLATION
# ============================================================================
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared; \
    elif [ "$ARCH" = "aarch64" ]; then \
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O /usr/local/bin/cloudflared; \
    fi && \
    chmod +x /usr/local/bin/cloudflared

# ============================================================================
# USER SETUP
# ============================================================================
RUN useradd -m -s /bin/bash coder && \
    echo "coder:coder" | chpasswd && \
    mkdir -p /home/coder/workspace && \
    mkdir -p /home/coder/.config/code-server && \
    mkdir -p /home/coder/scripts && \
    mkdir -p /home/coder/logs && \
    mkdir -p /home/coder/.cookies && \
    mkdir -p /home/coder/.local/share/code-server && \
    chown -R coder:coder /home/coder

# ============================================================================
# COPY CONFIGURATION FILES
# ============================================================================
COPY config.yaml /home/coder/.config/code-server/
COPY scripts/ /home/coder/scripts/

# Set permissions
RUN chmod +x /home/coder/scripts/* && \
    chown -R coder:coder /home/coder

# ============================================================================
# INSTALL PYTHON PACKAGES
# ============================================================================
USER coder
WORKDIR /home/coder/workspace

# Install Python packages for automation
RUN pip3 install --user selenium webdriver-manager schedule requests beautifulsoup4 Pillow

# ============================================================================
# VERIFY INSTALLATION
# ============================================================================
# Test code-server installation (using absolute path)
RUN /usr/local/bin/code-server --version

# Switch back to root for CMD
USER root

EXPOSE 8080 3000 8081
WORKDIR /home/coder

CMD ["/bin/bash", "/home/coder/scripts/startup.sh"]
