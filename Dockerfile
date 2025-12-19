FROM ubuntu:22.04

# ============================================================================
# RUN AS ROOT FROM START
# ============================================================================
USER root
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true
ENV TZ=Etc/UTC

# ============================================================================
# PRE-SEED ALL CONFIGURATIONS
# ============================================================================
RUN echo 'tzdata tzdata/Areas select Etc' | debconf-set-selections && \
    echo 'tzdata tzdata/Zones/Etc select UTC' | debconf-set-selections && \
    echo 'keyboard-configuration keyboard-configuration/layout select English (US)' | debconf-set-selections && \
    echo 'keyboard-configuration keyboard-configuration/variant select English (US)' | debconf-set-selections && \
    echo 'locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8' | debconf-set-selections && \
    echo 'locales locales/default_environment_locale select en_US.UTF-8' | debconf-set-selections

# ============================================================================
# INSTALL EVERYTHING AS ROOT
# ============================================================================
RUN apt-get update && \
    apt-get -y --no-install-recommends install \
    # SYSTEM ADMIN TOOLS
    sudo curl wget git nano vim emacs neovim \
    htop neofetch bashtop btop gotop \
    screen tmux byobu multitail \
    tree ncdu ranger mc \
    # DEVELOPMENT
    python3 python3-pip python3-venv python3-dev \
    python2 python2-dev \
    nodejs npm yarn \
    openjdk-17-jdk openjdk-11-jdk maven gradle \
    golang-go rustc cargo \
    php php-cli php-curl php-mysql \
    ruby ruby-dev perl \
    build-essential cmake make gcc g++ \
    # DESKTOP & RDP
    xfce4 xfce4-goodies xfce4-terminal \
    xrdp xorgxrdp tightvncserver tigervnc-common \
    x11vnc xvfb xserver-xorg-core \
    firefox chromium-browser \
    # NETWORKING
    net-tools iputils-ping dnsutils \
    netcat socat nmap traceroute \
    openssh-client openssh-server \
    wireguard-tools openvpn \
    # FILE MANAGEMENT
    rclone rsync unison \
    unzip zip p7zip-full rar unrar \
    # MONITORING
    dstat iotop iftop nethogs \
    sysstat glances \
    # DATABASES
    mysql-client postgresql-client redis-tools \
    mongodb-clients sqlite3 \
    # CLOUD & CONTAINERS
    docker.io docker-compose podman \
    kubectl helm minikube \
    awscli gcloud azure-cli \
    # SECURITY
    fail2ban ufw knockd \
    hydra john hashcat \
    # MEDIA
    ffmpeg imagemagick graphicsmagick \
    mpv vlc mplayer \
    # OTHER ESSENTIALS
    cron anacron logrotate \
    locales ca-certificates gnupg lsb-release \
    software-properties-common apt-transport-https \
    dialog whiptail \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# ADDITIONAL INSTALLATIONS
# ============================================================================
# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Install cloudflared
RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

# Install ngrok
RUN wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz -O ngrok.tgz && \
    tar -xzf ngrok.tgz -C /usr/local/bin/ && \
    rm ngrok.tgz && \
    chmod +x /usr/local/bin/ngrok

# Install Docker Compose v2
RUN curl -SL https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && mv kubectl /usr/local/bin/

# ============================================================================
# CONFIGURE ROOT ACCESS
# ============================================================================
# Set root password
RUN echo "root:root123" | chpasswd

# Create coder user with FULL sudo
RUN useradd -m -s /bin/bash coder && \
    echo "coder:coder123" | chpasswd && \
    usermod -aG sudo coder && \
    usermod -aG docker coder && \
    usermod -aG root coder && \
    echo "coder ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers.d/coder && \
    chmod 0440 /etc/sudoers.d/coder

# ============================================================================
# SETUP WORKSPACE
# ============================================================================
RUN mkdir -p /home/coder/workspace && \
    mkdir -p /home/coder/.config/code-server && \
    mkdir -p /home/coder/.ssh && \
    mkdir -p /home/coder/.local/share && \
    mkdir -p /home/coder/.cache && \
    chown -R coder:coder /home/coder && \
    chmod 700 /home/coder/.ssh

# ============================================================================
# CONFIGURE SERVICES
# ============================================================================
# Setup SSH
RUN mkdir -p /var/run/sshd && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "X11Forwarding yes" >> /etc/ssh/sshd_config

# Setup RDP
RUN echo "xfce4-session" > /home/coder/.xsession && \
    chown coder:coder /home/coder/.xsession

# ============================================================================
# COPY CONFIGURATION
# ============================================================================
COPY config.yaml /home/coder/.config/code-server/

# ============================================================================
# INSTALL PYTHON PACKAGES
# ============================================================================
USER coder
WORKDIR /home/coder

RUN pip3 install --user \
    selenium webdriver-manager requests beautifulsoup4 \
    numpy pandas matplotlib seaborn scikit-learn \
    flask django fastapi sqlalchemy \
    jupyter notebook ipython \
    ansible fabric paramiko \
    pytest coverage black flake8 \
    pillow opencv-python-headless \
    discord.py tweepy

# ============================================================================
# FINAL SETUP
# ============================================================================
USER root

# Expose all ports
EXPOSE 8080   # VS Code
EXPOSE 3389   # RDP
EXPOSE 5900   # VNC
EXPOSE 5901   # VNC alternate
EXPOSE 22     # SSH
EXPOSE 80     # HTTP
EXPOSE 443    # HTTPS
EXPOSE 3000   # Node.js
EXPOSE 8081   # Health check
EXPOSE 8082   # noVNC

WORKDIR /home/coder

# ============================================================================
# STARTUP COMMAND - ALL SERVICES
# ============================================================================
CMD ["sh", "-c", \
    "service ssh start && \
     xrdp --nodaemon & \
     Xvfb :99 -screen 0 1280x720x24 & \
     sleep 2 && \
     su -c 'code-server --bind-addr 0.0.0.0:8080 --auth none' coder & \
     tail -f /dev/null"]
