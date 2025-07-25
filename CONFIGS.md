# Configuration Files Reference

This directory contains all the key configuration files needed to recreate the RadioGPS system.

## Configuration Files Overview

### Boot Configuration
- **`configs/config.txt`**: Raspberry Pi boot configuration
  - Enables UART for GPS
  - Configures PPS GPIO overlay
  - Disables Bluetooth
  - Sets GPU memory split

- **`configs/fstab`**: Filesystem mount table
  - Configures tmpfs mounts for `/tmp` and other RAM disks
  - Optimized for SD card wear reduction

### GPS Configuration
- **`configs/gpsd`**: GPS daemon configuration (`/etc/default/gpsd`)
  - Defines GPS devices (`/dev/ttyS0`, `/dev/pps0`)
  - Sets GPSD options for time server operation

### NTP Configuration  
- **`configs/chrony.conf`**: Chrony NTP server configuration
  - GPS and PPS time source configuration
  - Network time server fallbacks
  - Client access permissions
  - High-precision timing settings

### ADS-B Configuration
- **`configs/readsb`**: ReadSB ADS-B receiver configuration (`/etc/default/readsb`)
  - RTL-SDR device settings
  - Output formats and locations
  - Geographic location settings
  - Network port configurations

### System Optimization
- **`configs/log2ram.conf`**: Log2Ram configuration
  - RAM disk size for system logs
  - Sync intervals and paths
  - Compression settings

## Installation Instructions

### Automated Installation
Most configuration files can be copied directly to their system locations:

```bash
# Copy all configuration files
sudo cp configs/chrony.conf /etc/chrony/chrony.conf
sudo cp configs/gpsd /etc/default/gpsd
sudo cp configs/readsb /etc/default/readsb  
sudo cp configs/log2ram.conf /etc/log2ram.conf

# Boot configurations (requires reboot)
sudo cp configs/config.txt /boot/firmware/config.txt
sudo cp configs/fstab /etc/fstab
```

### Manual Configuration
Some files may need customization for your specific setup:

1. **Location Settings**: Update GPS coordinates in `readsb` config
2. **Network Settings**: Modify NTP client access ranges in `chrony.conf`
3. **Hardware Settings**: Adjust GPIO pins or device paths if different

### Verification
After copying configurations:

```bash
# Verify configuration syntax
sudo chronyd -Q
sudo gpsd -V
sudo readsb --help

# Check file permissions
ls -la /etc/chrony/chrony.conf
ls -la /etc/default/gpsd
ls -la /etc/default/readsb
```

## Key Configuration Parameters

### GPS/NTP Timing
```bash
# In chrony.conf
refclock PPS /dev/pps0 refid PPS precision 1e-7 lock GPS
allow 192.168.0.0/16    # Adjust for your network

# In gpsd
DEVICES="/dev/ttyS0 /dev/pps0"
GPSD_OPTIONS="-n -r"
```

### ADS-B Reception
```bash
# In readsb  
DECODER_OPTIONS="--device 0 --gain auto --ppm 0"
NET_OPTIONS="--net --net-heartbeat 60"
JSON_OPTIONS="--write-json /run/readsb"
```

### System Optimization
```bash
# In log2ram.conf
SIZE=128M
USE_RSYNC=true
MAIL=false

# In fstab
tmpfs /tmp tmpfs defaults,noatime,nosuid,nodev,noexec,mode=1777,size=100M 0 0
```

## Backup and Restore

### Creating Backups
```bash
# Backup current configurations
mkdir -p ~/radiogps-backup
sudo cp /etc/chrony/chrony.conf ~/radiogps-backup/
sudo cp /etc/default/gpsd ~/radiogps-backup/
sudo cp /etc/default/readsb ~/radiogps-backup/
sudo cp /boot/firmware/config.txt ~/radiogps-backup/
sudo cp /etc/fstab ~/radiogps-backup/
```

### Restoring from Backup
```bash
# Restore configurations
sudo cp ~/radiogps-backup/* /etc/
sudo systemctl daemon-reload
sudo systemctl restart chrony gpsd readsb
```

## Environment-Specific Customization

### Network Configuration
Update these settings for your network:

```bash
# In chrony.conf - adjust allowed networks
allow 192.168.1.0/24     # Your local subnet
allow 10.0.0.0/8         # Private networks

# Fallback NTP servers - choose geographically close ones
server pool.ntp.org      # Global pool
server time.nist.gov     # US NIST
server pool.ntp.br       # Brazil (example)
```

### Geographic Location
Update coordinates for your location:

```bash
# In readsb config
DECODER_OPTIONS="--lat YOUR_LATITUDE --lon YOUR_LONGITUDE"

# Get coordinates:
# GPS: gpspipe -w -n 1 | jq '.lat, .lon'
# Online: https://www.gps-coordinates.net/
```

### Hardware Variations
If using different hardware:

```bash
# Different GPIO for PPS
# In config.txt: dtoverlay=pps-gpio,gpiopin=XX

# Different RTL-SDR device
# In readsb: --device 1 (if multiple SDRs)

# Different UART
# In gpsd: DEVICES="/dev/ttyUSB0 /dev/pps0"
```

## Security Considerations

### NTP Access Control
```bash
# Restrict NTP access by network
allow 192.168.1.0/24     # Local network only
# Remove or comment global access:
# allow 0.0.0.0/0        # Don't allow global access
```

### File Permissions
Ensure proper permissions on configuration files:

```bash
sudo chmod 644 /etc/chrony/chrony.conf
sudo chmod 644 /etc/default/gpsd
sudo chmod 644 /etc/default/readsb
sudo chmod 644 /boot/firmware/config.txt
sudo chmod 644 /etc/fstab
```

## Troubleshooting Configuration Issues

### Syntax Validation
```bash
# Test chrony configuration
sudo chronyd -Q

# Test GPSD configuration  
sudo gpsd -D 5 -N -n /dev/ttyS0

# Check readsb parameters
sudo readsb --help
```

### Service Restart After Changes
```bash
# Restart services after configuration changes
sudo systemctl restart chrony
sudo systemctl restart gpsd  
sudo systemctl restart readsb
sudo systemctl restart log2ram

# For boot config changes
sudo reboot
```

### Common Configuration Errors
- **Wrong device paths**: Check `/dev/ttyS0`, `/dev/pps0` exist
- **Permission issues**: Ensure user in `dialout` group
- **Network conflicts**: Verify no port conflicts (123 for NTP)
- **Syntax errors**: Use configuration validation tools
