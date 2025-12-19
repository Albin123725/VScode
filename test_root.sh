#!/bin/bash

echo "=== ROOT ACCESS TEST ==="

# Test 1: Sudo
echo "1. Testing sudo..."
sudo whoami
sudo id
sudo cat /etc/shadow 2>/dev/null && echo "✅ Can read shadow file"

# Test 2: Root user
echo "2. Testing root user..."
su - root -c "whoami" <<< "root123"

# Test 3: Package installation
echo "3. Testing package installation..."
sudo apt update 2>/dev/null && echo "✅ Can update packages"
sudo apt install -y sl 2>/dev/null && echo "✅ Can install packages"

# Test 4: System control
echo "4. Testing system control..."
sudo systemctl status 2>/dev/null && echo "✅ Can control systemd"
sudo netstat -tulpn 2>/dev/null && echo "✅ Can see all network"

# Test 5: File system
echo "5. Testing file system access..."
sudo touch /root/test.txt 2>/dev/null && echo "✅ Can write to root"
sudo rm /root/test.txt 2>/dev/null

# Test 6: Docker
echo "6. Testing Docker..."
sudo docker ps 2>/dev/null && echo "✅ Docker access"

echo ""
echo "=== TEST COMPLETE ==="
