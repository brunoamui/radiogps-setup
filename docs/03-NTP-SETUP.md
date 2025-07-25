# NTP Setup with GPS Time Source

## Prerequisites
- GPS configured and working as per [02-GPS-SETUP.md](02-GPS-SETUP.md)
- GPS showing 3D fix with PPS signal active

## Install and Configure Chrony

### Install Chrony NTP Server
```bash
# Stop and disable systemd-timesyncd first
sudo systemctl stop systemd-timesyncd
sudo systemctl disable systemd-timesyncd

# Install chrony
sudo apt install -y chrony

# Enable chrony service
sudo systemctl enable chrony
```

### Configure Chrony for GPS Time Source

Edit `/etc/chrony/chrony.conf`:

```bash
# GPS time source configuration
# GPS via gpsd (SHM)
refclock SHM 0 refid GPS precision 1e-1 offset 0.9999 delay 0.2 noselect

# PPS source (high precision)
refclock PPS /dev/pps0 refid PPS precision 1e-7 lock GPS

# Fallback NTP servers (lower stratum)
pool 2.debian.pool.ntp.org iburst maxsources 4
server time.nist.gov iburst
server pool.ntp.br iburst

# Allow NTP client access from local network
allow 192.168.0.0/16
allow 10.0.0.0/8
allow 172.16.0.0/12

# Serve time even if not synchronized to a time source
local stratum 10

# Record the rate at which the system clock gains/losses time
driftfile /var/lib/chrony/chrony.drift

# Allow the system clock to be stepped in the first three updates
makestep 1000 3

# Enable kernel synchronization of the real-time clock (RTC)
rtcsync

# Enable hardware timestamping on all interfaces that support it
#hwtimestamp *

# Increase the minimum number of selectable sources required to adjust
# the system clock
minsources 1

# Allow NTP client access on this computer
bindcmdaddress 127.0.0.1
bindcmdaddress ::1

# Disable logging of client accesses
noclientlog

# Send a message to syslog if a clock adjustment is larger than 0.5 seconds
logchange 0.5

# Log files
logdir /var/log/chrony
log measurements statistics tracking
```

### Set Chrony GPS Configuration
Create `/etc/chrony/sources.d/gps.sources`:

```bash
# GPS reference clock via shared memory from gpsd
refclock SHM 0 refid GPS precision 1e-1 offset 0.9999 delay 0.2 noselect

# PPS reference clock (requires GPS lock)
refclock PPS /dev/pps0 refid PPS precision 1e-7 lock GPS poll 4 prefer
```

## Configure GPSD for Chrony Integration

### Edit GPSD Configuration
Update `/etc/default/gpsd`:

```bash
# Devices gpsd should monitor
DEVICES="/dev/ttyS0 /dev/pps0"

# Additional options for time server operation
GPSD_OPTIONS="-n -r"

# Enable shared memory export for chrony
USBAUTO="false"
GPSD_SOCKET="/var/run/gpsd.sock"
```

### Restart Services
```bash
# Restart gpsd with new configuration
sudo systemctl restart gpsd

# Start chrony
sudo systemctl start chrony

# Check status
sudo systemctl status chrony
sudo systemctl status gpsd
```

## Verify NTP Operation

### Check Chrony Sources
```bash
# Show all time sources
chronyc sources -v

# Expected output should show:
# ^? GPS    - GPS via SHM (may show as unreachable initially)  
# ^* PPS    - PPS reference (should be selected when GPS has fix)
# ^+ pool   - Internet NTP servers as backup

# Check source statistics
chronyc sourcestats

# Show tracking information
chronyc tracking
```

### Monitor Time Synchronization
```bash
# Watch synchronization status
watch chronyc tracking

# Check system clock status
timedatectl status

# Should show:
# - NTP service: active
# - NTP synchronized: yes
# - Time zone configured
```

### Test PPS Integration
```bash
# Check PPS statistics
chronyc sourcestats | grep PPS

# Monitor PPS performance
journalctl -u chrony -f | grep -i pps
```

## Performance Tuning

### Optimize for High Precision
Add to `/etc/chrony/chrony.conf`:

```bash
# Reduce polling intervals for better stability
refclock SHM 0 refid GPS precision 1e-1 offset 0.9999 delay 0.2 poll 4 noselect
refclock PPS /dev/pps0 refid PPS precision 1e-7 lock GPS poll 4 prefer

# Reduce maximum adjustment rate
maxupdateskew 100

# Set minimum and maximum polling intervals
minpoll 4
maxpoll 6

# Increase the number of measurements used for regression
maxsamples 32
```

### Configure Client Access Logging (Optional)
```bash
# Enable client access logging if needed
# clientlog

# Log client access to specific file
# clientloglimit 16777216
```

## Firewall Configuration

### Allow NTP Traffic
```bash
# Allow NTP client connections (port 123)
sudo ufw allow 123/udp

# Or allow from specific networks only
sudo ufw allow from 192.168.0.0/16 to any port 123
```

## Monitoring and Logging

### Create NTP Status Script
Create `/usr/local/bin/ntp-status.sh`:

```bash
#!/bin/bash

echo "=== Chrony NTP Status ==="
echo "System Time: $(date)"
echo ""

echo "--- Time Sources ---"
chronyc sources -v

echo ""
echo "--- Source Statistics ---"
chronyc sourcestats

echo ""
echo "--- Tracking Information ---"
chronyc tracking

echo ""
echo "--- System Time Status ---"
timedatectl status

echo ""
echo "--- GPS Fix Status ---"
if command -v cgps &> /dev/null; then
    timeout 3s cgps -s | head -10
fi
```

Make executable:
```bash
sudo chmod +x /usr/local/bin/ntp-status.sh
```

### Regular Monitoring
Add to crontab for periodic status logging:

```bash
# Add to system crontab
echo "*/15 * * * * root /usr/local/bin/ntp-status.sh >> /var/log/ntp-status.log 2>&1" | sudo tee -a /etc/crontab
```

## Troubleshooting

### Common Issues

**GPS not appearing as source:**
```bash
# Check gpsd shared memory
ipcs -m | grep gpsd

# Verify gpsd is exporting time
gpspipe -w -n 5 | grep -i tpv

# Check chrony logs
journalctl -u chrony | grep -i gps
```

**PPS not working:**
```bash
# Verify PPS device
ls -la /dev/pps0

# Test PPS signal
sudo ppstest /dev/pps0

# Check PPS in chrony
chronyc sources | grep PPS
```

**Time not synchronizing:**
```bash
# Force immediate sync
sudo chronyc makestep

# Check for large time differences
chronyc tracking | grep "System time"

# Verify network connectivity to NTP servers
chronyc activity
```

**Stratum too high:**
```bash
# Check if GPS/PPS is being used
chronyc sources -v | grep "^\^*"

# Reduce local stratum if needed
# Edit /etc/chrony/chrony.conf: local stratum 1
```

## Validation Tests

### Time Accuracy Test
```bash
# Compare GPS time with system time
GPS_TIME=$(gpspipe -w -n 1 | jq -r '.time' 2>/dev/null)
SYS_TIME=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)

echo "GPS Time: $GPS_TIME"
echo "System Time: $SYS_TIME"
```

### NTP Client Test
From another machine on the network:

```bash
# Test NTP response
ntpdate -q <radiogps-ip>

# Or use chrony client
chronyc sources -a -v
```

### Precision Measurement
```bash
# Monitor time offset over time
watch 'chronyc tracking | grep "System time"'

# Log precision over time
while true; do
    echo "$(date): $(chronyc tracking | grep 'System time')"
    sleep 60
done >> /var/log/time-precision.log
```

## Expected Performance

### Typical Metrics
- **GPS alone**: ±100ms accuracy
- **PPS locked**: ±1μs accuracy  
- **Stratum level**: 1 (with GPS/PPS), 2-3 (fallback)
- **Offset**: <10μs with PPS, <100ms without
- **Synchronization time**: 5-15 minutes after GPS fix

### Status Indicators
- `^*` - Currently selected time source
- `^+` - Acceptable time source
- `^-` - Rejected time source
- `^?` - Unreachable time source

## Next Steps

After NTP is working properly:
1. Set up ADS-B receiver: [04-ADSB-SETUP.md](04-ADSB-SETUP.md)
2. Configure web interface: [05-WEB-INTERFACE.md](05-WEB-INTERFACE.md)
3. Apply system optimizations: [06-OPTIMIZATIONS.md](06-OPTIMIZATIONS.md)
