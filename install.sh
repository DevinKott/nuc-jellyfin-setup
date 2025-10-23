#!/bin/bash

# Installation script for NAS Mount and Docker Startup Service
# Run this script as root to install the service

set -e

SCRIPT_NAME="nas-mount-and-start.sh"
SERVICE_NAME="nas-mount-startup.service"
ENV_EXAMPLE="nas-mount-startup.env.example"
SCRIPT_PATH="/usr/local/bin/$SCRIPT_NAME"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"
ENV_PATH="/etc/nas-mount-startup.env"

echo "Installing NAS Mount and Docker Startup Service..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Copy the main script
echo "Installing script to $SCRIPT_PATH..."
cp "$SCRIPT_NAME" "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"

# Copy the service file
echo "Installing service to $SERVICE_PATH..."
cp "$SERVICE_NAME" "$SERVICE_PATH"

# Copy the environment file example (don't overwrite if exists)
if [ ! -f "$ENV_PATH" ]; then
    echo "Creating environment configuration file at $ENV_PATH..."
    cp "$ENV_EXAMPLE" "$ENV_PATH"
    chmod 600 "$ENV_PATH"
    echo "IMPORTANT: Environment file created with example values - YOU MUST EDIT IT!"
else
    echo "Environment file already exists at $ENV_PATH (not overwriting)"
fi

# Create log file with proper permissions
echo "Setting up log file..."
touch /var/log/nas-mount-startup.log
chmod 644 /var/log/nas-mount-startup.log

# Reload systemd and enable the service
echo "Configuring systemd service..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"

echo ""
echo "========================================"
echo "Installation complete!"
echo "========================================"
echo ""
echo "CRITICAL: Before starting the service, you MUST configure:"
echo ""
echo "1. Edit the environment configuration file:"
echo "   sudo nano $ENV_PATH"
echo ""
echo "   Required settings:"
echo "   - NAS_PASSWORD: Set your NAS password"
echo "   - DOCKER_COMPOSE_DIR: Set to your actual Docker Compose directory"
echo ""
echo "   Optional settings (uncomment and modify if needed):"
echo "   - NAS_IP, NAS_USERNAME, NAS_SHARE"
echo "   - EXPECTED_FOLDERS, MOUNT_POINT, LOG_FILE"
echo ""
echo "2. Verify required packages are installed:"
echo "   - cifs-utils: sudo apt install cifs-utils"
echo "   - docker: sudo apt install docker.io docker-compose-plugin"
echo ""
echo "========================================"
echo "Commands to manage the service:"
echo "========================================"
echo "  Start:      sudo systemctl start $SERVICE_NAME"
echo "  Stop:       sudo systemctl stop $SERVICE_NAME"
echo "  Status:     sudo systemctl status $SERVICE_NAME"
echo "  Logs:       sudo journalctl -u $SERVICE_NAME -f"
echo "  Log file:   /var/log/nas-mount-startup.log"
echo "  Restart:    sudo systemctl restart $SERVICE_NAME"
echo ""
echo "To test the script manually (after configuring $ENV_PATH):"
echo "  sudo $SCRIPT_PATH"
echo ""
echo "To reload service after editing $ENV_PATH:"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl restart $SERVICE_NAME"