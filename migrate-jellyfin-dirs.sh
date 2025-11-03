#!/bin/bash

# Migration script for fixing Jellyfin directory locations
# This script moves directories from /root/~/jellyfin_* to the correct user home
directory

set -e

SERVICE_NAME="nas-mount-startup.service"
ENV_PATH="/etc/nas-mount-startup.env"

echo "========================================"
echo "Jellyfin Directory Migration Script"
echo "========================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Load environment variables
if [ ! -f "$ENV_PATH" ]; then
    echo "ERROR: Environment file not found at $ENV_PATH"
    exit 1
fi

source "$ENV_PATH"

# Get the real user and their home directory
real_user="${SUDO_USER:-$USER}"
if [ "$real_user" = "root" ]; then
    echo "ERROR: Could not determine the real user. Please run this script with sudo as your regular user."
    exit 1
fi

real_home=$(getent passwd "$real_user" | cut -d: -f6)
echo "Detected user: $real_user"
echo "User home directory: $real_home"
echo ""

# Define source and destination directories
old_config="/root/~/jellyfin_config"
old_cache="/root/~/jellyfin_cache"
new_config="${JELLYFIN_CONFIG_DIR:-~/jellyfin_config}"
new_cache="${JELLYFIN_CACHE_DIR:-~/jellyfin_cache}"

# Expand tildes in new paths
if [[ "$new_config" == "~/"* ]] || [[ "$new_config" == "~" ]]; then
    new_config="${real_home}${new_config#\~}"
fi
if [[ "$new_cache" == "~/"* ]] || [[ "$new_cache" == "~" ]]; then
    new_cache="${real_home}${new_cache#\~}"
fi

echo "Migration plan:"
echo "  Config: $old_config → $new_config"
echo "  Cache:  $old_cache → $new_cache"
echo ""

# Check if old directories exist
config_exists=false
cache_exists=false

if [ -d "$old_config" ]; then
    config_exists=true
    echo "✓ Found old config directory: $old_config"
fi

if [ -d "$old_cache" ]; then
    cache_exists=true
    echo "✓ Found old cache directory: $old_cache"
fi

if [ "$config_exists" = false ] && [ "$cache_exists" = false ]; then
    echo ""
    echo "No old directories found. Nothing to migrate!"
    echo "If you expected to find directories, please check the paths above."
    exit 0
fi

echo ""
read -p "Do you want to proceed with the migration? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Migration cancelled."
    exit 0
fi

echo ""
echo "Starting migration..."
echo ""

# Stop the Jellyfin container if it's running
echo "Step 1: Stopping Jellyfin container..."
if [ -n "$DOCKER_COMPOSE_DIR" ] && [ -d "$DOCKER_COMPOSE_DIR" ]; then
    cd "$DOCKER_COMPOSE_DIR"
    if docker compose ps | grep -q jellyfin; then
        docker compose down
        echo "  ✓ Container stopped"
    else
        echo "  ℹ Container was not running"
    fi
else
    echo "  ⚠ DOCKER_COMPOSE_DIR not found, skipping container stop"
fi

echo ""

# Migrate config directory
if [ "$config_exists" = true ]; then
    echo "Step 2: Migrating config directory..."

    # Create parent directory if needed
    config_parent=$(dirname "$new_config")
    if [ ! -d "$config_parent" ]; then
        mkdir -p "$config_parent"
        chown "$real_user:$real_user" "$config_parent"
    fi

    # Move the directory
    if [ -d "$new_config" ]; then
        echo "  ⚠ Destination already exists: $new_config"
        echo "  Creating backup: ${new_config}.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$new_config" "${new_config}.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    mv "$old_config" "$new_config"
    chown -R "$real_user:$real_user" "$new_config"
    echo "  ✓ Config moved to: $new_config"

    # Clean up the old parent directory if empty
    old_parent=$(dirname "$old_config")
    if [ -d "$old_parent" ] && [ -z "$(ls -A "$old_parent")" ]; then
        rmdir "$old_parent"
        echo "  ✓ Cleaned up empty directory: $old_parent"
    fi
else
    echo "Step 2: Config directory not found, skipping..."
fi

echo ""

# Migrate cache directory
if [ "$cache_exists" = true ]; then
    echo "Step 3: Migrating cache directory..."

    # Create parent directory if needed
    cache_parent=$(dirname "$new_cache")
    if [ ! -d "$cache_parent" ]; then
        mkdir -p "$cache_parent"
        chown "$real_user:$real_user" "$cache_parent"
    fi

    # Move the directory
    if [ -d "$new_cache" ]; then
        echo "  ⚠ Destination already exists: $new_cache"
        echo "  Creating backup: ${new_cache}.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$new_cache" "${new_cache}.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    mv "$old_cache" "$new_cache"
    chown -R "$real_user:$real_user" "$new_cache"
    echo "  ✓ Cache moved to: $new_cache"

    # Clean up the old parent directory if empty
    old_parent=$(dirname "$old_cache")
    if [ -d "$old_parent" ] && [ -z "$(ls -A "$old_parent")" ]; then
        rmdir "$old_parent"
        echo "  ✓ Cleaned up empty directory: $old_parent"
    fi
else
    echo "Step 3: Cache directory not found, skipping..."
fi

echo ""

# Regenerate compose.yml
echo "Step 4: Regenerating compose.yml..."
if [ -f "./install.sh" ]; then
    ./install.sh --generate-compose
    echo "  ✓ compose.yml regenerated"
else
    echo "  ⚠ install.sh not found in current directory"
    echo "  Please run manually: sudo ./install.sh --generate-compose"
fi

echo ""

# Restart the service
echo "Step 5: Restarting the service..."
systemctl daemon-reload
systemctl restart "$SERVICE_NAME"
echo "  ✓ Service restarted"

echo ""
echo "========================================"
echo "Migration complete!"
echo "========================================"
echo ""
echo "Summary:"
echo "  Config: $new_config"
echo "  Cache:  $new_cache"
echo ""
echo "Check service status:"
echo "  sudo systemctl status $SERVICE_NAME"
echo ""
echo "Check Jellyfin logs:"
echo "  sudo docker logs jellyfin"
echo ""
echo "Access Jellyfin at:"
echo "  http://localhost:${JELLYFIN_PORT:-8096}"
echo ""
