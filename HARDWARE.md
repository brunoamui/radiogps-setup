# Hardware Setup

## Components List

### Main Hardware
- **Raspberry Pi 4 Model B** (4GB RAM)
- **MicroSD Card** (32GB SanDisk Ultra Class 10)
- **Power Supply** (5V 3A USB-C)
- **Ethernet Cable** (for initial setup and management)

### GPS Module
- **GPS Module**: u-blox NEO-8M based module with PPS output
- **GPS Antenna**: Active GPS antenna (3.3V powered)
- **Connections**: UART (Serial) + PPS

### ADS-B Receiver
- **RTL-SDR Dongle**: RTL2832U-based SDR (Generic RTL2832U)
- **ADS-B Antenna**: 1090MHz antenna optimized for ADS-B
- **Connection**: USB 2.0

### Camera (Optional)
- **Raspberry Pi Camera Module** v2 or compatible
- **Connection**: CSI camera connector

## GPIO Connections

### GPS Module Connections
```
GPS Module    →  Raspberry Pi GPIO
VCC           →  Pin 1  (3.3V)
GND           →  Pin 6  (Ground)
TX (GPS)      →  Pin 10 (GPIO 15 - UART RX)
RX (GPS)      →  Pin 8  (GPIO 14 - UART TX)  [Optional if GPS doesn't need commands]
PPS           →  Pin 12 (GPIO 18)
```

### GPIO Pinout Reference
```
     3.3V  1 ● ● 2   5V
    GPIO2  3 ● ● 4   5V
    GPIO3  5 ● ● 6   GND
    GPIO4  7 ● ● 8   GPIO14 (UART TX)
      GND  9 ● ● 10  GPIO15 (UART RX)
   GPIO17 11 ● ● 12  GPIO18 (PPS)
   GPIO27 13 ● ● 14  GND
   GPIO22 15 ● ● 16  GPIO23
     3.3V 17 ● ● 18  GPIO24
   GPIO10 19 ● ● 20  GND
```

## Physical Layout

### Case Considerations
- Ensure GPS antenna has clear sky view
- ADS-B antenna should be elevated and away from obstructions
- Adequate ventilation for Raspberry Pi cooling
- Access to GPIO pins for GPS connections

### Antenna Placement
- **GPS Antenna**: Mount with clear view of sky, minimal metal obstruction
- **ADS-B Antenna**: Higher elevation = better range (typical range: 200-400km)
- **Separation**: Keep antennas separated to avoid interference

## Wiring Diagram

```
┌─────────────────┐    ┌─────────────────┐
│   GPS Module    │    │  Raspberry Pi   │
│                 │    │                 │
│ VCC ────────────┼────┤ Pin 1 (3.3V)    │
│ GND ────────────┼────┤ Pin 6 (GND)     │
│ TX ─────────────┼────┤ Pin 10 (RX)     │
│ PPS ────────────┼────┤ Pin 12 (GPIO18) │
└─────────────────┘    └─────────────────┘

┌─────────────────┐    ┌─────────────────┐
│   RTL-SDR       │    │  Raspberry Pi   │
│                 │    │                 │
│ USB ────────────┼────┤ USB Port        │
└─────────────────┘    └─────────────────┘
```

## Initial Setup Requirements

### Boot Configuration
The Raspberry Pi requires specific boot configuration for GPS and PPS support. Key settings in `/boot/firmware/config.txt`:

```
# Enable UART for GPS
enable_uart=1
dtparam=uart0=on

# Enable PPS support
dtoverlay=pps-gpio,gpiopin=18

# Disable Bluetooth to free up UART
dtoverlay=disable-bt
```

### UART Configuration
- Primary UART (`/dev/ttyS0`) is used for GPS communication
- Bluetooth is disabled to prevent UART conflicts
- Console output on UART is disabled in `/boot/firmware/cmdline.txt`

## Power Considerations

### Power Requirements
- Raspberry Pi 4: ~3W (idle) to ~8W (full load)
- GPS Module: ~50mA @ 3.3V
- RTL-SDR: ~300mA @ 5V
- Total: Recommend 5V 3A power supply minimum

### Power Quality
- Use quality power supply to avoid GPS timing issues
- Consider UPS for continuous operation
- Monitor temperature under load

## Verification Steps

After hardware setup, verify connections:

1. **Boot Check**: System boots without errors
2. **UART Check**: `ls -la /dev/ttyS0` shows UART device
3. **PPS Check**: `ls -la /dev/pps*` shows PPS device
4. **USB Check**: `lsusb` shows RTL-SDR device
5. **GPIO Check**: `cat /proc/device-tree/chosen/bootargs` shows no console on UART

## Safety Notes

- Always power off before making connections
- Verify 3.3V vs 5V requirements for modules
- Use anti-static precautions when handling components
- Ensure proper grounding for all components
