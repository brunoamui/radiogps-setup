# GPS Setup

## Prerequisites
- Hardware connected as per [HARDWARE.md](../HARDWARE.md)
- Base system configured as per [01-BASE-SYSTEM.md](01-BASE-SYSTEM.md)
- GPS module connected to UART (/dev/ttyS0) and PPS (GPIO 18)

## Install GPS Software

### Install gpsd and Tools
```bash
# Install GPS daemon and utilities
sudo apt install -y gpsd gpsd-clients

# Install PPS tools
sudo apt install -y pps-tools

# Install development libraries (if needed)
sudo apt install -y libgps-dev
```

## Configure gpsd

### Edit gpsd Configuration
Create/edit `/etc/default/gpsd`:

```bash
# Devices gpsd should monitor
DEVICES="/dev/ttyS0 /dev/pps0"

# Additional options
GPSD_OPTIONS="-n"

# gpsd user
USBAUTO="false"
GPSD_SOCKET="/var/run/gpsd.sock"
```

### Configure gpsd Service
```bash
# Enable and start gpsd socket (auto-starts daemon)
sudo systemctl enable gpsd.socket
sudo systemctl start gpsd.socket

# Check service status
sudo systemctl status gpsd.socket
sudo systemctl status gpsd.service
```

## Verify GPS Hardware

### Check Device Files
```bash
# Check UART device
ls -la /dev/ttyS0
# Should show: crw-rw---- 1 root dialout

# Check PPS device (after GPS gets fix)
ls -la /dev/pps*
# Should show: crw------- 1 root root ... /dev/pps0
```

### Test Raw GPS Data
```bash
# Monitor raw NMEA data (Ctrl+C to stop)
sudo cat /dev/ttyS0

# Should see NMEA sentences like:
# $GPRMC,123456.00,A,1234.5678,N,01234.5678,W,0.123,45.67,123456,,,A*12
# $GPGGA,123456.00,1234.5678,N,01234.5678,W,1,08,1.23,456.7,M,12.3,M,,*12
```

### Test PPS Signal
```bash
# Test PPS functionality (requires GPS fix)
sudo ppstest /dev/pps0

# Should show regular PPS pulses:
# source 0 (pps0), edge 1, ticks 1234567890, time 1234567890.000000000
```

## Verify gpsd Operation

### Check gpsd Status
```bash
# Query gpsd daemon
gpspipe -r -n 5

# Should show JSON format GPS data
```

### Monitor GPS Status
```bash
# Interactive GPS monitor
gpsmon

# Or check specific device
gpsmon /dev/ttyS0
```

### GPS Fix Information
```bash
# Get current GPS status
gpspipe -w -n 1 | jq '.'

# Check for GPS fix
cgps -s

# Expected output shows:
# - Status: 3D FIX
# - Satellites: 8+ used
# - Time: Current UTC time
# - Position: Lat/Lon coordinates
```

## GPS Configuration Optimization

### Set GPS Update Rate (Optional)
For better timing precision, configure 10Hz updates:

```bash
# Send configuration to GPS (u-blox specific)
echo -ne '\xB5\x62\x06\x08\x06\x00\x64\x00\x01\x00\x01\x00\x7A\x12' | sudo tee /dev/ttyS0 > /dev/null

# Restart gpsd to pick up changes
sudo systemctl restart gpsd
```

### Disable GPS NMEA Sentences (Optional)
To reduce UART traffic, disable unnecessary NMEA sentences:

```bash
# Keep only essential sentences (GGA, RMC, GSA, GSV)
echo '$PUBX,40,GLL,0,0,0,0*5C' | sudo tee /dev/ttyS0 > /dev/null
echo '$PUBX,40,GST,0,0,0,0*5B' | sudo tee /dev/ttyS0 > /dev/null
echo '$PUBX,40,VTG,0,0,0,0*5E' | sudo tee /dev/ttyS0 > /dev/null
```

## Set System Location

### Configure Geographic Location
Edit `/etc/default/gpsd` to add location for faster initial fix:

```bash
# Add approximate coordinates (helps with initial acquisition)
GPSD_OPTIONS="-n -G"
```

### Manual Location Setting
If GPS takes too long to get initial fix:

```bash
# Set approximate location (Brasília, Brazil coordinates)
echo "!SPEED" | nc localhost 2947
echo "?DEVICE;" | nc localhost 2947
```

## Troubleshooting GPS

### Common Issues

**No GPS fix:**
```bash
# Check GPS antenna connection
# Verify clear sky view
# Monitor satellite count: cgps -s
# Check for interference from metal objects
```

**No PPS device:**
```bash
# Verify PPS overlay in config.txt
grep pps-gpio /boot/firmware/config.txt

# Check kernel module
lsmod | grep pps

# Check dmesg for PPS messages
dmesg | grep -i pps
```

**Permission denied errors:**
```bash
# Add user to dialout group
sudo usermod -a -G dialout $USER

# Set PPS device permissions
sudo chmod 666 /dev/pps0
```

**gpsd not starting:**
```bash
# Check configuration
sudo gpsd -D 5 -N -n /dev/ttyS0

# Check logs
journalctl -u gpsd -f
```

## Monitoring and Logging

### Create GPS Logging Script
Create `/usr/local/bin/gps-logger.sh`:

```bash
#!/bin/bash
LOGFILE="/var/log/gps/gps.log"
mkdir -p "$(dirname "$LOGFILE")"

while true; do
    DATE=$(date '+%Y-%m-%d %H:%M:%S')
    GPS_DATA=$(gpspipe -w -n 1 2>/dev/null | jq -c '. | select(.class=="TPV")' 2>/dev/null)
    
    if [ -n "$GPS_DATA" ]; then
        echo "$DATE $GPS_DATA" >> "$LOGFILE"
    fi
    
    sleep 60
done
```

### Create systemd Service for GPS Logging
Create `/etc/systemd/system/gps-logger.service`:

```ini
[Unit]
Description=GPS Data Logger
After=gpsd.service
Requires=gpsd.service

[Service]
Type=simple
User=pi
ExecStart=/usr/local/bin/gps-logger.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable the service:
```bash
sudo chmod +x /usr/local/bin/gps-logger.sh
sudo systemctl enable gps-logger.service
sudo systemctl start gps-logger.service
```

## Final Verification

### Complete GPS Test
```bash
# Check all components
echo "=== GPS Hardware Test ==="
ls -la /dev/ttyS0 /dev/pps0

echo "=== GPSD Status ==="
systemctl status gpsd --no-pager

echo "=== GPS Fix Status ==="
timeout 10s cgps -s

echo "=== PPS Test ==="
timeout 5s sudo ppstest /dev/pps0

echo "=== GPS Time ==="
gpspipe -w -n 1 | jq '.time' 2>/dev/null || echo "No GPS time data"
```

### Expected Results
- UART device accessible
- PPS device present (after GPS fix)
- gpsd service running
- GPS showing 3D fix with 4+ satellites
- PPS pulses every second
- GPS time matches UTC

## Next Steps

After GPS is working properly:
1. Configure NTP with GPS time source: [03-NTP-SETUP.md](03-NTP-SETUP.md)
2. Set up ADS-B receiver: [04-ADSB-SETUP.md](04-ADSB-SETUP.md)

## Performance Notes

- GPS initial fix can take 2-30 minutes depending on conditions
- Keep GPS antenna away from metal objects and interference sources
- Higher elevation provides better satellite visibility
- Cold starts take longer than warm starts
- PPS requires GPS fix to function
