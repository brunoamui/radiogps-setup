#!/bin/bash

# RadioGPS System Verification Script
# Checks all components and services

echo "================================================================"
echo "RadioGPS System Verification"
echo "================================================================"
echo ""

# Function to check service status
check_service() {
    local service=$1
    local name=$2
    
    if systemctl is-active --quiet "$service"; then
        echo "✅ $name: ACTIVE"
        return 0
    else
        echo "❌ $name: INACTIVE"
        return 1
    fi
}

# Function to check file/device existence
check_device() {
    local device=$1
    local name=$2
    
    if [ -e "$device" ]; then
        echo "✅ $name: EXISTS ($device)"
        return 0
    else
        echo "❌ $name: NOT FOUND ($device)"
        return 1
    fi
}

# Function to check command availability
check_command() {
    local cmd=$1
    local name=$2
    
    if command -v "$cmd" &> /dev/null; then
        echo "✅ $name: AVAILABLE"
        return 0
    else
        echo "❌ $name: NOT FOUND"
        return 1
    fi
}

# Function to test network connectivity
check_network() {
    if ping -c 1 8.8.8.8 &> /dev/null; then
        echo "✅ Network: CONNECTED"
        return 0
    else
        echo "❌ Network: NO CONNECTION"
        return 1
    fi
}

# System Information
echo "=== System Information ==="
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"')"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Uptime: $(uptime -p)"
echo ""

# Hardware Checks
echo "=== Hardware Checks ==="
check_device "/dev/ttyS0" "UART Device"
check_device "/dev/pps0" "PPS Device" || echo "   (PPS device appears after GPS fix)"
check_device "/dev/video0" "Camera Device" || echo "   (Optional component)"

# Check USB devices
echo ""
echo "USB Devices:"
lsusb | grep -i rtl && echo "✅ RTL-SDR: DETECTED" || echo "❌ RTL-SDR: NOT DETECTED"
echo ""

# Core Services
echo "=== Core Services ==="
check_service "gpsd" "GPS Daemon"
check_service "chrony" "NTP Service"
check_service "readsb" "ADS-B Receiver"
check_service "log2ram" "Log2Ram Service"
check_service "cockpit.socket" "Cockpit Web Interface"
echo ""

# Optional Services
echo "=== Optional Services ==="
check_service "gps-logger" "GPS Logger" || echo "   (Optional service)"
check_service "temperature-monitor" "Temperature Monitor" || echo "   (Check crontab for temperature logging)"
echo ""

# Software Checks
echo "=== Software Availability ==="
check_command "gpsd" "GPSD"
check_command "chronyd" "Chrony"
check_command "readsb" "ReadSB"
check_command "ppstest" "PPS Tools"
check_command "cgps" "GPS Clients"
echo ""

# Network and Connectivity
echo "=== Network Status ==="
check_network
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo ""

# GPS Status
echo "=== GPS Status ==="
if systemctl is-active --quiet gpsd; then
    GPS_FIX=$(timeout 5s gpspipe -w -n 1 2>/dev/null | jq -r 'select(.class=="TPV") | .mode' 2>/dev/null)
    if [ "$GPS_FIX" = "3" ]; then
        echo "✅ GPS Fix: 3D FIX"
    elif [ "$GPS_FIX" = "2" ]; then
        echo "⚠️  GPS Fix: 2D FIX"
    else
        echo "❌ GPS Fix: NO FIX"
    fi
    
    # Check satellite count
    SAT_COUNT=$(timeout 5s gpspipe -w -n 10 2>/dev/null | jq -r 'select(.class=="SKY") | .uSat' 2>/dev/null | tail -1)
    if [ -n "$SAT_COUNT" ] && [ "$SAT_COUNT" -gt 0 ]; then
        echo "✅ Satellites: $SAT_COUNT in use"
    else
        echo "❌ Satellites: Not available"
    fi
else
    echo "❌ GPS: Service not running"
fi
echo ""

# NTP Status
echo "=== NTP Status ==="
if systemctl is-active --quiet chrony; then
    CHRONY_SOURCES=$(chronyc sources -n 2>/dev/null | grep -E "^\^" | wc -l)
    GPS_SOURCE=$(chronyc sources 2>/dev/null | grep -i "gps\|pps" | head -1)
    
    if [ "$CHRONY_SOURCES" -gt 0 ]; then
        echo "✅ NTP Sources: $CHRONY_SOURCES active"
    else
        echo "❌ NTP Sources: None active"
    fi
    
    if [ -n "$GPS_SOURCE" ]; then
        echo "✅ GPS Time Source: Available"
        echo "   $GPS_SOURCE"
    else
        echo "⚠️  GPS Time Source: Not available"
    fi
else
    echo "❌ NTP: Service not running"
fi
echo ""

# PPS Status
echo "=== PPS Status ==="
if [ -e "/dev/pps0" ]; then
    echo "✅ PPS Device: Available"
    # Test PPS for 3 seconds
    PPS_TEST=$(timeout 3s sudo ppstest /dev/pps0 2>/dev/null | wc -l)
    if [ "$PPS_TEST" -gt 0 ]; then
        echo "✅ PPS Signal: Active ($PPS_TEST pulses in 3s)"
    else
        echo "❌ PPS Signal: No pulses detected"
    fi
else
    echo "❌ PPS Device: Not available"
fi
echo ""

# ADS-B Status
echo "=== ADS-B Status ==="
if systemctl is-active --quiet readsb; then
    echo "✅ ReadSB: Running"
    
    # Check if JSON data is being generated
    if [ -f "/run/readsb/aircraft.json" ]; then
        AIRCRAFT_COUNT=$(jq '.aircraft | length' /run/readsb/aircraft.json 2>/dev/null || echo 0)
        echo "✅ ADS-B Data: $AIRCRAFT_COUNT aircraft tracked"
    else
        echo "❌ ADS-B Data: No data file found"
    fi
    
    # Check for recent messages
    if [ -f "/run/readsb/stats.json" ]; then
        MESSAGES=$(jq '.messages' /run/readsb/stats.json 2>/dev/null || echo 0)
        echo "✅ ADS-B Messages: $MESSAGES total received"
    fi
else
    echo "❌ ReadSB: Not running"
fi
echo ""

# Storage and Memory
echo "=== System Resources ==="
echo "Memory Usage:"
free -h | grep -E "(Mem|Swap)"

echo ""
echo "Disk Usage:"
df -h | grep -E "(root|tmpfs|log2ram)" | head -5

echo ""
echo "Temperature:"
if command -v vcgencmd &> /dev/null; then
    CPU_TEMP=$(vcgencmd measure_temp | cut -d'=' -f2)
    echo "CPU: $CPU_TEMP"
fi
echo ""

# Log Status
echo "=== Logging Status ==="
if systemctl is-active --quiet log2ram; then
    echo "✅ Log2Ram: Active"
    LOG2RAM_SIZE=$(df -h | grep log2ram | awk '{print $2}')
    LOG2RAM_USED=$(df -h | grep log2ram | awk '{print $3}')
    echo "   RAM Disk: $LOG2RAM_USED / $LOG2RAM_SIZE used"
else
    echo "❌ Log2Ram: Not active"
fi

# Check if /tmp is on tmpfs
TMP_TMPFS=$(mount | grep "tmpfs on /tmp")
if [ -n "$TMP_TMPFS" ]; then
    echo "✅ /tmp on tmpfs: Yes"
else
    echo "❌ /tmp on tmpfs: No"
fi

# Check swap status
SWAP_STATUS=$(cat /proc/swaps | wc -l)
if [ "$SWAP_STATUS" -le 1 ]; then
    echo "✅ Swap: Disabled (good for SD card)"
else
    echo "⚠️  Swap: Enabled (may cause SD card wear)"
fi
echo ""

# Web Interface
echo "=== Web Interface ==="
if systemctl is-active --quiet cockpit.socket; then
    echo "✅ Cockpit: Available"
    if curl -s --connect-timeout 2 http://localhost:9090 > /dev/null; then
        echo "✅ Web Access: http://$(hostname -I | awk '{print $1}'):9090"
    else
        echo "❌ Web Access: Connection failed"
    fi
    
    # Check for custom plugins
    if [ -d "/usr/share/cockpit/radiogps-temp-plugin" ]; then
        echo "✅ Temperature Plugin: Installed"
    else
        echo "⚠️  Temperature Plugin: Not found"
    fi
else
    echo "❌ Cockpit: Not available"
fi
echo ""

# Summary
echo "================================================================"
echo "Verification Complete"
echo "================================================================"

# Count total checks and failures
TOTAL_CHECKS=20  # Update this based on actual checks
echo "System Status: $(hostname) - $(date)"
echo ""
echo "For detailed logs, check:"
echo "  GPS: journalctl -u gpsd"
echo "  NTP: journalctl -u chrony"
echo "  ADS-B: journalctl -u readsb"
echo "  System: dmesg | tail -20"
echo ""
echo "Configuration files located in: /etc/"
echo "Log files: /var/log/ (on RAM disk via log2ram)"
