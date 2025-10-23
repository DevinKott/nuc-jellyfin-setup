#!/bin/bash

# Uninstallation script for NAS Mount and Docker Startup Service
# Run this script as root to completely remove the service

set -e

SERVICE_NAME="nas-mount-startup.service"
SCRIPT_PATH="/usr/local/bin/nas-mount-and-start.sh"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"
ENV_PATH="/etc/nas-mount-startup.env"
LOG_FILE="/var/log/nas-mount-startup.log"
MOUNT_POINT="/mnt/synology_nas/media"

echo "========================================"
echo "NAS Mount Service Uninstaller"
echo "========================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Stop the service if it's running
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Stopping $SERVICE_NAME..."
    systemctl stop "$SERVICE_NAME"
    echo "  ✓ Service stopped"
else
    echo "  ℹ Service is not running"
fi

# Disable the service if it's enabled
if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo "Disabling $SERVICE_NAME..."
    systemctl disable "$SERVICE_NAME"
    echo "  ✓ Service disabled"
else
    echo "  ℹ Service is not enabled"
fi

# Unmount NAS if mounted
if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    echo "Unmounting NAS from $MOUNT_POINT..."
    if umount "$MOUNT_POINT"; then
        echo "  ✓ NAS unmounted successfully"
    else
        echo "  ⚠ WARNING: Failed to unmount NAS (may need manual intervention)"
        echo "    Try: sudo umount -f $MOUNT_POINT"
    fi
else
    echo "  ℹ NAS is not mounted"
fi

# Remove service file
if [ -f "$SERVICE_PATH" ]; then
    echo "Removing service file: $SERVICE_PATH"
    rm -f "$SERVICE_PATH"
    echo "  ✓ Service file removed"
else
    echo "  ℹ Service file not found (already removed)"
fi

# Remove script
if [ -f "$SCRIPT_PATH" ]; then
    echo "Removing script: $SCRIPT_PATH"
    rm -f "$SCRIPT_PATH"
    echo "  ✓ Script removed"
else
    echo "  ℹ Script not found (already removed)"
fi

# Remove environment file
if [ -f "$ENV_PATH" ]; then
    echo "Removing environment file: $ENV_PATH"
    rm -f "$ENV_PATH"
    echo "  ✓ Environment file removed"
else
    echo "  ℹ Environment file not found (already removed)"
fi

# Remove log file
if [ -f "$LOG_FILE" ]; then
    echo "Removing log file: $LOG_FILE"
    rm -f "$LOG_FILE"
    echo "  ✓ Log file removed"
else
    echo "  ℹ Log file not found (already removed)"
fi

# Reload systemd daemon
echo "Reloading systemd daemon..."
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true
echo "  ✓ Systemd daemon reloaded"

echo ""
echo "========================================"
echo "Uninstallation Complete"
echo "========================================"
echo ""
echo "The following have been removed:"
echo "  • Systemd service: $SERVICE_NAME"
echo "  • Service script: $SCRIPT_PATH"
echo "  • Environment file: $ENV_PATH"
echo "  • Log file: $LOG_FILE"
echo ""
echo "Optional cleanup:"
echo "  • Mount point directory still exists: $MOUNT_POINT"
echo "    To remove: sudo rmdir $MOUNT_POINT"
echo ""
echo "  • If Docker containers were started by this service, they may still be running."
echo "    To stop them, run: docker compose down"
echo "    (in your Docker Compose directory)"
echo ""
