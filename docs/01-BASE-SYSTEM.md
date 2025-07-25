# Base System Setup

## Raspberry Pi OS Installation

### Download and Flash OS
1. Download **Raspberry Pi OS (64-bit)** - Debian 12 Bookworm
2. Use Raspberry Pi Imager or `dd` to flash to SD card
3. Enable SSH and configure WiFi/Ethernet in imager settings

### Initial Boot Configuration
1. Insert SD card and boot Raspberry Pi
2. Complete initial setup wizard if using desktop version
3. Enable SSH if not already enabled:
   ```bash
   sudo systemctl enable ssh
   sudo systemctl start ssh
   ```

### System Updates
```bash
# Update package lists and system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y \
    curl \
    wget \
    git \
    htop \
    nano \
    vim \
    net-tools \
    dnsutils \
    build-essential \
    cmake \
    pkg-config
```

## Boot Configuration

### Edit `/boot/firmware/config.txt`
Add/modify these lines for GPS and PPS support:

```bash
# Enable UART for GPS
enable_uart=1
dtparam=uart0=on

# Enable PPS support  
dtoverlay=pps-gpio,gpiopin=18

# Disable Bluetooth to free up UART
dtoverlay=disable-bt

# GPU memory split (minimal for headless)
gpu_mem=16

# Enable camera (if using)
camera_auto_detect=1

# I2C enable (for sensors)
dtparam=i2c_arm=on
```

### Edit `/boot/firmware/cmdline.txt`
Remove console output from UART:
- Remove: `console=serial0,115200`
- Keep other parameters intact

Example final line:
```
console=tty1 root=PARTUUID=738a4d67-02 rootfstype=ext4 fsck.repair=yes rootwait quiet splash plymouth.ignore-serial-consoles
```

### Disable Serial Console Service
```bash
sudo systemctl stop serial-getty@ttyS0.service
sudo systemctl disable serial-getty@ttyS0.service
```

## User Configuration

### Create System User (if needed)
```bash
# Add user to necessary groups
sudo usermod -a -G dialout,video,audio,plugdev,gpio,i2c,spi pi

# Or create dedicated user
sudo adduser radiogps
sudo usermod -a -G dialout,video,audio,plugdev,gpio,i2c,spi,sudo radiogps
```

### SSH Key Setup
```bash
# Generate SSH key for secure access
ssh-keygen -t ed25519 -C "radiogps@$(hostname)"

# Copy public key to authorized_keys
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

## Network Configuration

### Set Static IP (Optional)
Edit `/etc/dhcpcd.conf`:
```bash
# Static IP configuration
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 8.8.8.8
```

### Hostname Configuration
```bash
# Set hostname
sudo hostnamectl set-hostname radiogps

# Update /etc/hosts
sudo nano /etc/hosts
# Add: 127.0.0.1 radiogps
```

## System Services

### Install systemd-timesyncd (temporary)
```bash
# Install timesyncd for initial time sync
sudo apt install -y systemd-timesyncd
sudo systemctl enable systemd-timesyncd
sudo systemctl start systemd-timesyncd
```

### Disable Unnecessary Services
```bash
# Disable services that may cause issues
sudo systemctl disable bluetooth
sudo systemctl disable hciuart
sudo systemctl disable triggerhappy

# Disable ModemManager (can interfere with GPS)
sudo systemctl disable ModemManager
```

## Development Tools

### Install Build Dependencies
```bash
# Install development packages
sudo apt install -y \
    gcc \
    g++ \
    make \
    cmake \
    pkg-config \
    git \
    autoconf \
    automake \
    libtool \
    libusb-1.0-0-dev \
    libusb-dev \
    libfftw3-dev
```

### Install Node.js (for web development)
```bash
# Install Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Verify installation
node --version
npm --version
```

## System Optimization Preparation

### Create Directories
```bash
# Create log directories
sudo mkdir -p /var/log/temperature
sudo mkdir -p /var/log/gps
sudo mkdir -p /var/log/adsb

# Set permissions
sudo chown pi:pi /var/log/temperature
sudo chown pi:pi /var/log/gps
sudo chown pi:pi /var/log/adsb
```

### Install Monitoring Tools
```bash
# Install system monitoring
sudo apt install -y \
    htop \
    iotop \
    vnstat \
    lm-sensors \
    rpi-eeprom

# Configure sensors
sudo sensors-detect --auto

# Update EEPROM if needed
sudo rpi-eeprom-update -a
```

## Reboot and Verify

### Reboot System
```bash
sudo reboot
```

### Verify Configuration
After reboot, check:

```bash
# Check UART device
ls -la /dev/ttyS0

# Check PPS device (may not show until GPS connected)
ls -la /dev/pps*

# Check boot messages
dmesg | grep -i uart
dmesg | grep -i pps

# Check disabled services
sudo systemctl status bluetooth
sudo systemctl status serial-getty@ttyS0.service

# Check GPIO state
cat /proc/device-tree/chosen/bootargs
```

## Next Steps

After completing base system setup:
1. Connect GPS hardware as per [HARDWARE.md](../HARDWARE.md)
2. Proceed to [02-GPS-SETUP.md](02-GPS-SETUP.md) for GPS configuration
3. Continue with remaining setup steps

## Troubleshooting

### Common Issues

**UART not available:**
- Check `/boot/firmware/config.txt` has `enable_uart=1`
- Verify Bluetooth is disabled with `dtoverlay=disable-bt`
- Ensure `console=serial0,115200` is removed from cmdline.txt

**Permission denied on devices:**
- Add user to `dialout` group: `sudo usermod -a -G dialout $USER`
- Log out and back in for group changes to take effect

**System time issues:**
- Ensure internet connectivity for initial time sync
- Check `timedatectl` status
- Verify `systemd-timesyncd` is running
