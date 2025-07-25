#!/bin/bash
# Deploy updated temperature plugin to radiogps
# This script deploys the Log2Ram-compatible version

set -e

echo "=== Deploying Temperature Plugin to RadioGPS ==="
echo "Deploying Log2Ram-compatible version..."

# Build the plugin
echo "Step 1: Building plugin..."
npm run build

# Copy to radiogps
echo "Step 2: Copying files to radiogps..."
scp -r dist/* brunoamui@radiogps:/tmp/cockpit-temp-plugin/

# Install on radiogps
echo "Step 3: Installing on radiogps..."
ssh brunoamui@radiogps "sudo mkdir -p /usr/share/cockpit/cockpit-temp-plugin && \
sudo cp -r /tmp/cockpit-temp-plugin/* /usr/share/cockpit/cockpit-temp-plugin/ && \
sudo chown -R root:root /usr/share/cockpit/cockpit-temp-plugin && \
sudo chmod -R 644 /usr/share/cockpit/cockpit-temp-plugin/* && \
sudo chmod 755 /usr/share/cockpit/cockpit-temp-plugin && \
sudo systemctl restart cockpit"

echo "✅ Deployment complete!"
echo ""
echo "=== Plugin Features ==="
echo "• Log2Ram Compatible: Temperature logs now use RAM disk"
echo "• Improved Performance: Faster log access and reduced SD card wear"
echo "• Standard Cron: Uses /etc/cron.d/ instead of /etc/crontab"
echo "• Automatic Persistence: Log2Ram handles log rotation and sync"
echo ""
echo "Access the plugin at: http://radiogps:9090"
echo "Navigate to 'Temperature Monitor' in the Cockpit sidebar"
