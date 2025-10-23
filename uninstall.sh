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

# Function to expand ~ to actual home directory
expand_home() {
    local path="$1"
    if [[ "$path" == "~/"* ]]; then
        echo "$HOME/${path#~/}"
    else
        echo "$path"
    fi
}

echo "========================================"
echo "NAS Mount Service Uninstaller"
echo "========================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Load environment variables early so we can use them later
JELLYFIN_CONFIG_DIR=""
JELLYFIN_CACHE_DIR=""
DOCKER_COMPOSE_DIR=""
if [ -f "$ENV_PATH" ]; then
    source "$ENV_PATH"
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

# Stop Docker containers if they're running
if [ -f "$ENV_PATH" ]; then
    source "$ENV_PATH"
    if [ -n "$DOCKER_COMPOSE_DIR" ] && [ -d "$DOCKER_COMPOSE_DIR" ]; then
        if [ -f "$DOCKER_COMPOSE_DIR/compose.yml" ] || [ -f "$DOCKER_COMPOSE_DIR/docker-compose.yml" ]; then
            echo "Stopping Docker containers..."
            cd "$DOCKER_COMPOSE_DIR"
            if docker compose down 2>/dev/null; then
                echo "  ✓ Docker containers stopped"
            else
                echo "  ⚠ WARNING: Failed to stop Docker containers (may already be stopped)"
            fi
        fi
    fi
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

# Remove compose.yml if it exists
if [ -f "$ENV_PATH" ]; then
    source "$ENV_PATH"
    if [ -n "$DOCKER_COMPOSE_DIR" ] && [ -f "$DOCKER_COMPOSE_DIR/compose.yml" ]; then
        echo "Removing generated compose.yml: $DOCKER_COMPOSE_DIR/compose.yml"
        rm -f "$DOCKER_COMPOSE_DIR/compose.yml"
        echo "  ✓ compose.yml removed"
    fi
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

# Show Jellyfin directories if they exist
JELLYFIN_CONFIG_DIR_EXPANDED=$(expand_home "${JELLYFIN_CONFIG_DIR:-~/jellyfin_config}")
JELLYFIN_CACHE_DIR_EXPANDED=$(expand_home "${JELLYFIN_CACHE_DIR:-~/jellyfin_cache}")

if [ -d "$JELLYFIN_CONFIG_DIR_EXPANDED" ]; then
    echo "  • Jellyfin config directory still exists: $JELLYFIN_CONFIG_DIR_EXPANDED"
    echo "    To remove: sudo rm -rf $JELLYFIN_CONFIG_DIR_EXPANDED"
    echo ""
fi

if [ -d "$JELLYFIN_CACHE_DIR_EXPANDED" ]; then
    echo "  • Jellyfin cache directory still exists: $JELLYFIN_CACHE_DIR_EXPANDED"
    echo "    To remove: sudo rm -rf $JELLYFIN_CACHE_DIR_EXPANDED"
    echo ""
fi
