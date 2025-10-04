#!/bin/bash
# Script: check_vps.sh
# Show system information for VPS comparison

echo "==================== VPS INFORMATION ===================="

# Hostname & OS
echo "Hostname: $(hostname)"
echo "OS: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d \")"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"

echo "-------------------- CPU --------------------"
echo "CPU Model: $(lscpu | grep 'Model name' | sed 's/Model name:[ \t]*//')"
echo "CPU Cores: $(nproc)"
echo "CPU MHz: $(lscpu | grep 'CPU MHz' | awk '{print $3}' | head -n1)"

echo "-------------------- RAM --------------------"
echo "Total RAM: $(free -h | awk '/Mem:/ {print $2}')"
echo "Available RAM: $(free -h | awk '/Mem:/ {print $7}')"

echo "-------------------- SWAP --------------------"
echo "Total Swap: $(free -h | awk '/Swap:/ {print $2}')"
echo "Used Swap: $(free -h | awk '/Swap:/ {print $3}')"
echo "Free Swap: $(free -h | awk '/Swap:/ {print $4}')"

echo "-------------------- DISK --------------------"
df -h --total | grep total | awk '{print "Total Disk: " $2 ", Used: " $3 ", Available: " $4}'

echo "-------------------- NETWORK --------------------"
echo "Public IP: $(curl -s ifconfig.me)"
echo "Network Interfaces:"
ip -o -4 addr show | awk '{print $2, $4}'

echo "-------------------- NETWORK PORT SPEED --------------------"
for iface in $(ls /sys/class/net | grep -v lo); do
    speed=""
    if command -v ethtool &>/dev/null; then
        speed=$(ethtool $iface 2>/dev/null | grep "Speed:" | awk '{print $2}')
    fi
    if [ -z "$speed" ] && [ -f /sys/class/net/$iface/speed ]; then
        speed=$(cat /sys/class/net/$iface/speed 2>/dev/null)
        [ "$speed" != "-1" ] && speed="${speed}Mb/s" || speed=""
    fi
    if [ -n "$speed" ]; then
        echo "Interface $iface speed: $speed"
    else
        echo "Interface $iface speed: Không xác định (do VPS ảo hóa)"
    fi
done

echo "-------------------- BANDWIDTH SPEED TEST --------------------"
if command -v speedtest &> /dev/null; then
    speedtest --simple
elif command -v speedtest-cli &> /dev/null; then
    speedtest-cli --simple
else
    echo "⚠️ speedtest-cli not installed."
    echo "👉 Cài đặt:"
    echo "   - Debian/Ubuntu: apt update && apt install speedtest-cli -y"
    echo "   - CentOS/RHEL: yum install epel-release -y && yum install speedtest-cli -y"
    echo "   - Hoặc: pip install speedtest-cli"
fi

echo "============================================================"
