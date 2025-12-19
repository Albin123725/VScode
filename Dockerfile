FROM ubuntu:22.04

# ============================================================================
# ROOT USER FROM START
# ============================================================================
USER root
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# ============================================================================
# BASIC INSTALLATIONS
# ============================================================================
RUN apt-get update && \
    apt-get install -y \
    sudo curl wget git \
    python3 python3-pip \
    htop neofetch vim nano \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# INSTALL CODE-SERVER
# ============================================================================
RUN curl -fsSL https://code-server.dev/install.sh | sh

# ============================================================================
# CREATE USER WITH SUDO
# ============================================================================
RUN useradd -m -s /bin/bash coder && \
    echo "coder:coder123" | chpasswd && \
    usermod -aG sudo coder && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/coder

# ============================================================================
# SETUP WORKSPACE
# ============================================================================
RUN mkdir -p /home/coder/workspace && \
    mkdir -p /home/coder/.config/code-server && \
    chown -R coder:coder /home/coder

# ============================================================================
# COPY CONFIG
# ============================================================================
COPY config.yaml /home/coder/.config/code-server/

# ============================================================================
# INSTALL PYTHON PACKAGES
# ============================================================================
USER coder
WORKDIR /home/coder
RUN pip3 install --user selenium requests

# ============================================================================
# EXPOSE PORTS - NO COMMENTS AFTER NUMBERS
# ============================================================================
USER root
EXPOSE 8080
EXPOSE 3389
EXPOSE 5900
EXPOSE 22
EXPOSE 3000

WORKDIR /home/coder

# ============================================================================
# START COMMAND
# ============================================================================
CMD ["sh", "-c", "su -c 'code-server --bind-addr 0.0.0.0:8080 --auth none' coder"]
