# Cockpit Plugins

This directory contains the custom Cockpit plugins for the RadioGPS system as git submodules.

## Available Plugins

### Temperature Monitor (`temperature-monitor/`)
- **Repository**: https://github.com/brunoamui/cockpit-temp-plugin
- **Function**: Monitors and displays CPU/GPU temperatures with historical graphs
- **Installation**: Copy to `/usr/share/cockpit/radiogps-temp-plugin/`

### ADS-B Monitor (`adsb-monitor/`)
- **Repository**: https://github.com/brunoamui/cockpit-adsb-plugin  
- **Function**: Displays real-time ADS-B aircraft tracking data
- **Installation**: Copy to `/usr/share/cockpit/radiogps-adsb-plugin/`

### NTP Monitor (`ntp-monitor/`)
- **Repository**: https://github.com/brunoamui/cockpit-ntp-plugin
- **Function**: Shows NTP server status, time sources, and synchronization info
- **Installation**: Copy to `/usr/share/cockpit/radiogps-ntp-plugin/`

## Working with Submodules

### Initial Clone
When cloning this repository, initialize submodules:
```bash
git clone https://github.com/brunoamui/radiogps-setup.git
cd radiogps-setup
git submodule update --init --recursive
```

### Updating Submodules
To pull latest changes from plugin repositories:
```bash
git submodule update --remote
```

### Building Plugins
Each plugin directory contains its own build instructions. Generally:
```bash
cd plugins/temperature-monitor
npm install
npm run build
```

## Plugin Installation Script

Use the deployment script to install all plugins:
```bash
./scripts/deploy-plugins.sh
```

This will:
1. Build each plugin
2. Copy built files to appropriate Cockpit directories
3. Restart Cockpit service
4. Verify installations

## Development

To make changes to plugins:
1. Navigate to the plugin directory
2. Make changes and commit to the plugin repository
3. Update the submodule reference in this repository:
   ```bash
   git add plugins/plugin-name
   git commit -m "Update plugin-name to latest version"
   ```

## Plugin Architecture

All plugins follow the Cockpit plugin architecture:
- `manifest.json` - Plugin metadata and navigation
- `index.html` - Main plugin interface
- `index.js` - Plugin logic and API calls
- `index.css` - Plugin styling
- Built with React/TypeScript using Cockpit's PatternFly components
