#!/bin/bash
echo "=== MINECRAFT AUTOMATION MONITOR ==="
echo "Time: $(date)"
echo ""

# Check processes
echo "🔍 Running processes:"
echo "-------------------"
ps aux | grep -E "(minecraft|colab|chrome|python)" | grep -v grep | head -20

echo ""
echo "📊 System Resources:"
echo "-------------------"
free -h
echo ""
df -h /home/coder

echo ""
echo "📁 Log Files:"
echo "------------"
ls -la /home/coder/logs/*.log 2>/dev/null || echo "No log files found"

echo ""
echo "📈 Recent Minecraft Logs:"
echo "------------------------"
tail -20 /home/coder/logs/minecraft_automation.log 2>/dev/null || echo "Log file not found"

echo ""
echo "🖥️ Screen Sessions:"
echo "-----------------"
screen -ls

echo ""
echo "🌐 Network Connections:"
echo "---------------------"
netstat -tulpn | grep -E "(8080|8081|3000)" | head -10

echo ""
echo "✅ Monitor complete"
