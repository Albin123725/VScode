#!/bin/bash
echo "Enabling root access for VS Code terminal..."

# Add coder to sudoers
sudo usermod -aG sudo coder 2>/dev/null || echo "Already in sudo group"

# Create passwordless sudo
echo "coder ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/coder
sudo chmod 0440 /etc/sudoers.d/coder

# Set root password (optional)
echo "root:root123" | sudo chpasswd 2>/dev/null || true
echo "coder:coder" | sudo chpasswd

echo "✅ Root access enabled!"
echo "Commands:"
echo "  sudo apt update"
echo "  sudo apt install [package]"
echo "  sudo su -  (password: root123)"
