#!/bin/bash
LOG_FILE="/home/coder/logs/restart.log"

echo "$(date): Checking Minecraft automation..." >> $LOG_FILE

# Check if automation is running
if ! screen -ls | grep -q "minecraft_automation"; then
    echo "$(date): Minecraft automation not running, restarting..." >> $LOG_FILE
    
    # Kill any leftover processes
    pkill -f chromedriver 2>/dev/null
    pkill -f chrome 2>/dev/null
    pkill -f "python.*colab" 2>/dev/null
    
    # Wait
    sleep 5
    
    # Start automation in screen session
    cd /home/coder/scripts
    screen -dmS minecraft_automation python3 my_colab_automation.py
    
    echo "$(date): Restarted Minecraft automation" >> $LOG_FILE
    echo "$(date): Screen session: $(screen -ls | grep minecraft)" >> $LOG_FILE
else
    echo "$(date): Minecraft automation is running" >> $LOG_FILE
fi
