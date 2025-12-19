FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# First, update and install essentials without keyboard-configuration
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
    # Basic tools (without keyboard-configuration for now)
    curl wget git nano vim tmux htop \
    python3 python3-pip python3-venv \
    nodejs npm \
    openjdk-17-jdk \
    # Chrome for automation
    chromium-browser chromium-chromedriver \
    unzip zip \
    # For monitoring
    net-tools iputils-ping \
    # Rclone for Google Drive
    rclone \
    # For terminal
    sudo locales \
    && rm -rf /var/lib/apt/lists/*

# Set locale to avoid warnings
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Now install keyboard-configuration with pre-seeded answers
RUN echo "keyboard-configuration keyboard-configuration/layoutcode string us" > /tmp/debconf.selections && \
    echo "keyboard-configuration keyboard-configuration/variantcode string" >> /tmp/debconf.selections && \
    echo "keyboard-configuration keyboard-configuration/modelcode string pc105" >> /tmp/debconf.selections && \
    echo "keyboard-configuration keyboard-configuration/optionscode string" >> /tmp/debconf.selections && \
    echo "keyboard-configuration keyboard-configuration/store_defaults_in_debconf_db boolean true" >> /tmp/debconf.selections && \
    echo "keyboard-configuration keyboard-configuration/switch select No temporary switch" >> /tmp/debconf.selections && \
    echo "keyboard-configuration keyboard-configuration/unsupported_layout boolean true" >> /tmp/debconf.selections && \
    echo "keyboard-configuration keyboard-configuration/unsupported_config_options boolean true" >> /tmp/debconf.selections && \
    echo "keyboard-configuration keyboard-configuration/ctrl_alt_bksp boolean false" >> /tmp/debconf.selections && \
    echo "keyboard-configuration keyboard-configuration/xkb-keymap select us" >> /tmp/debconf.selections && \
    echo "keyboard-configuration keyboard-configuration/compose select No compose key" >> /tmp/debconf.selections && \
    echo "keyboard-configuration keyboard-configuration/altgr select The default for the keyboard layout" >> /tmp/debconf.selections && \
    echo "keyboard-configuration keyboard-configuration/variant select English (US)" >> /tmp/debconf.selections && \
    echo "keyboard-configuration keyboard-configuration/model select Generic 105-key (Intl) PC" >> /tmp/debconf.selections && \
    echo "keyboard-configuration keyboard-configuration/layout select English (US)" >> /tmp/debconf.selections && \
    echo "keyboard-configuration keyboard-configuration/toggle select No toggling" >> /tmp/debconf.selections && \
    debconf-set-selections /tmp/debconf.selections && \
    apt-get update && \
    apt-get install -y keyboard-configuration && \
    rm -f /tmp/debconf.selections

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Install cloudflared
RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

# Install ChromeDriver (compatible with Chrome version)
RUN CHROME_VERSION=$(chromium-browser --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+') && \
    CHROME_MAJOR=$(echo $CHROME_VERSION | cut -d. -f1) && \
    wget -q "https://storage.googleapis.com/chrome-for-testing-public/$CHROME_VERSION/linux64/chromedriver-linux64.zip" -O /tmp/chromedriver.zip && \
    unzip -o /tmp/chromedriver.zip -d /tmp/ && \
    mv /tmp/chromedriver-linux64/chromedriver /usr/local/bin/ && \
    chmod +x /usr/local/bin/chromedriver && \
    rm -rf /tmp/chromedriver*

# Create user
RUN useradd -m -s /bin/bash coder && \
    echo "coder:coder" | chpasswd && \
    usermod -aG sudo coder && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/coder && \
    mkdir -p /home/coder/{workspace,.config/code-server,scripts,logs,.cookies} && \
    chown -R coder:coder /home/coder

# Copy configs and scripts
COPY config.yaml /home/coder/.config/code-server/
COPY --chown=coder:coder scripts/ /home/coder/scripts/

# Set permissions
RUN chmod +x /home/coder/scripts/*

# Install Python packages
USER coder
WORKDIR /home/coder

RUN pip3 install selenium webdriver-manager schedule requests beautifulsoup4 Pillow psutil

# Install VS Code extensions
RUN code-server --install-extension ms-python.python \
    --install-extension ms-python.vscode-pylance \
    --install-extension formulahendry.code-runner \
    --install-extension eamodio.gitlens \
    --install-extension yzhang.markdown-all-in-one

# Switch back to root for CMD
USER root

# Set timezone (prevents tzdata prompt)
RUN ln -fs /usr/share/zoneinfo/UTC /etc/localtime && \
    echo "UTC" > /etc/timezone

EXPOSE 8080 3000 8081
WORKDIR /home/coder

CMD ["/bin/bash", "/home/coder/scripts/startup.sh"]
