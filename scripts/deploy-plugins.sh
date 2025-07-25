#!/bin/bash

# RadioGPS Cockpit Plugins Deployment Script
# Builds and deploys all custom Cockpit plugins

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PLUGINS_DIR="$REPO_ROOT/plugins"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're running with appropriate permissions
check_permissions() {
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root. This script can be run as regular user with sudo for installation steps."
    fi
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check for Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js 18+ first."
        exit 1
    fi
    
    # Check for npm
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed. Please install npm first."
        exit 1
    fi
    
    # Check Node.js version
    NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        print_error "Node.js version $NODE_VERSION is too old. Please install Node.js 18 or later."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Build a plugin
build_plugin() {
    local plugin_name=$1
    local plugin_dir="$PLUGINS_DIR/$plugin_name"
    
    if [ ! -d "$plugin_dir" ]; then
        print_error "Plugin directory not found: $plugin_dir"
        return 1
    fi
    
    print_status "Building plugin: $plugin_name"
    
    cd "$plugin_dir"
    
    # Install dependencies if node_modules doesn't exist
    if [ ! -d "node_modules" ]; then
        print_status "Installing dependencies for $plugin_name..."
        npm install
    fi
    
    # Build the plugin
    print_status "Building $plugin_name..."
    npm run build
    
    if [ $? -eq 0 ]; then
        print_success "Successfully built $plugin_name"
        return 0
    else
        print_error "Failed to build $plugin_name"
        return 1
    fi
}

# Deploy a plugin
deploy_plugin() {
    local plugin_name=$1
    local plugin_dir="$PLUGINS_DIR/$plugin_name"
    local cockpit_name=""
    
    # Map plugin names to Cockpit directory names
    case $plugin_name in
        "temperature-monitor")
            cockpit_name="radiogps-temp-plugin"
            ;;
        "adsb-monitor")
            cockpit_name="radiogps-adsb-plugin"
            ;;
        "ntp-monitor")
            cockpit_name="radiogps-ntp-plugin"
            ;;
        *)
            print_error "Unknown plugin: $plugin_name"
            return 1
            ;;
    esac
    
    local target_dir="/usr/share/cockpit/$cockpit_name"
    
    print_status "Deploying $plugin_name to $target_dir..."
    
    # Create target directory
    sudo mkdir -p "$target_dir"
    
    # Copy built files
    if [ -d "$plugin_dir/dist" ]; then
        sudo cp -r "$plugin_dir"/dist/* "$target_dir/"
    else
        print_error "Build directory not found for $plugin_name. Did the build succeed?"
        return 1
    fi
    
    # Set proper permissions
    sudo chown -R root:root "$target_dir"
    sudo chmod -R 644 "$target_dir"/*
    
    print_success "Successfully deployed $plugin_name"
}

# Restart Cockpit service
restart_cockpit() {
    print_status "Restarting Cockpit service..."
    
    if systemctl is-active --quiet cockpit.socket; then
        sudo systemctl restart cockpit.socket
        print_success "Cockpit service restarted"
    else
        print_warning "Cockpit service is not running. Starting it..."
        sudo systemctl start cockpit.socket
        sudo systemctl enable cockpit.socket
        print_success "Cockpit service started and enabled"
    fi
}

# Verify plugin installation
verify_plugin() {
    local plugin_name=$1
    local cockpit_name=""
    
    case $plugin_name in
        "temperature-monitor")
            cockpit_name="radiogps-temp-plugin"
            ;;
        "adsb-monitor")
            cockpit_name="radiogps-adsb-plugin"
            ;;
        "ntp-monitor")
            cockpit_name="radiogps-ntp-plugin"
            ;;
    esac
    
    local target_dir="/usr/share/cockpit/$cockpit_name"
    
    if [ -f "$target_dir/manifest.json" ] && [ -f "$target_dir/index.html" ]; then
        print_success "Plugin $plugin_name is properly installed"
        return 0
    else
        print_error "Plugin $plugin_name installation verification failed"
        return 1
    fi
}

# Main deployment function
deploy_all_plugins() {
    local plugins=("temperature-monitor" "adsb-monitor" "ntp-monitor")
    local failed_plugins=()
    
    print_status "Starting deployment of all RadioGPS Cockpit plugins..."
    
    # Build all plugins
    for plugin in "${plugins[@]}"; do
        if ! build_plugin "$plugin"; then
            failed_plugins+=("$plugin")
        fi
    done
    
    # Deploy successfully built plugins
    for plugin in "${plugins[@]}"; do
        if [[ ! " ${failed_plugins[@]} " =~ " ${plugin} " ]]; then
            if ! deploy_plugin "$plugin"; then
                failed_plugins+=("$plugin")
            fi
        fi
    done
    
    # Restart Cockpit
    restart_cockpit
    
    # Verify installations
    print_status "Verifying plugin installations..."
    for plugin in "${plugins[@]}"; do
        if [[ ! " ${failed_plugins[@]} " =~ " ${plugin} " ]]; then
            verify_plugin "$plugin"
        fi
    done
    
    # Summary
    echo ""
    print_status "Deployment Summary:"
    for plugin in "${plugins[@]}"; do
        if [[ " ${failed_plugins[@]} " =~ " ${plugin} " ]]; then
            print_error "❌ $plugin: FAILED"
        else
            print_success "✅ $plugin: SUCCESS"
        fi
    done
    
    if [ ${#failed_plugins[@]} -eq 0 ]; then
        echo ""
        print_success "All plugins deployed successfully!"
        print_status "Access Cockpit at: http://$(hostname -I | awk '{print $1}'):9090"
    else
        echo ""
        print_error "Some plugins failed to deploy. Check the output above for details."
        exit 1
    fi
}

# Parse command line arguments
case "${1:-all}" in
    "temperature-monitor"|"adsb-monitor"|"ntp-monitor")
        check_permissions
        check_prerequisites
        plugin_name="$1"
        if build_plugin "$plugin_name" && deploy_plugin "$plugin_name"; then
            restart_cockpit
            verify_plugin "$plugin_name"
            print_success "Plugin $plugin_name deployed successfully!"
        else
            print_error "Failed to deploy plugin $plugin_name"
            exit 1
        fi
        ;;
    "all"|"")
        check_permissions
        check_prerequisites
        deploy_all_plugins
        ;;
    "help"|"-h"|"--help")
        echo "RadioGPS Cockpit Plugins Deployment Script"
        echo ""
        echo "Usage: $0 [plugin-name|all]"
        echo ""
        echo "Available plugins:"
        echo "  temperature-monitor  - CPU/GPU temperature monitoring"
        echo "  adsb-monitor        - ADS-B aircraft tracking"
        echo "  ntp-monitor         - NTP server status"
        echo "  all                 - Deploy all plugins (default)"
        echo ""
        echo "Examples:"
        echo "  $0                    # Deploy all plugins"
        echo "  $0 all               # Deploy all plugins"
        echo "  $0 temperature-monitor  # Deploy only temperature monitor"
        ;;
    *)
        print_error "Unknown option: $1"
        print_status "Use '$0 help' for usage information"
        exit 1
        ;;
esac
