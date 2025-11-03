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

# Function to expand ~ to actual home directory
expand_home() {
    local path="$1"
    if [[ "$path" == "~/"* ]] || [[ "$path" == "~" ]]; then
        # Get the actual user's home directory (not root's)
        local real_user="${SUDO_USER:-$USER}"
        local real_home=$(getent passwd "$real_user" | cut -d: -f6)
        echo "${real_home}${path#\~}"
    else
        echo "$path"
    fi
}

# Function to generate compose.yml file
generate_compose_file() {
    local compose_dir="$1"
    local compose_file="$compose_dir/compose.yml"

    # Load environment variables to get configuration
    if [ -f "$ENV_PATH" ]; then
        source "$ENV_PATH"
    fi

    # Set defaults for Jellyfin configuration
    local jellyfin_image="${JELLYFIN_IMAGE:-jellyfin/jellyfin}"
    local jellyfin_container="${JELLYFIN_CONTAINER_NAME:-jellyfin}"
    local jellyfin_config=$(expand_home "${JELLYFIN_CONFIG_DIR:-~/jellyfin_config}")
    local jellyfin_cache=$(expand_home "${JELLYFIN_CACHE_DIR:-~/jellyfin_cache}")
    local jellyfin_port="${JELLYFIN_PORT:-8096}"
    local jellyfin_media="${JELLYFIN_MEDIA_DIR:-${MOUNT_POINT:-/mnt/synology_nas/media}}"

    echo "Generating compose.yml at $compose_file..."

    # Create the compose directory if it doesn't exist
    mkdir -p "$compose_dir"

    # Generate the compose.yml file
    cat > "$compose_file" <<EOF
services:
  jellyfin:
    image: $jellyfin_image
    container_name: $jellyfin_container
    network_mode: 'host' # Port $jellyfin_port
    volumes:
      - $jellyfin_config:/config
      - $jellyfin_cache:/cache
      - type: bind
        source: $jellyfin_media
        target: /media
    devices:
      - /dev/dri:/dev/dri
EOF

    echo "  ✓ Generated compose.yml with Jellyfin configuration"
    echo "    Image: $jellyfin_image"
    echo "    Container: $jellyfin_container"
    echo "    Config: $jellyfin_config"
    echo "    Cache: $jellyfin_cache"
    echo "    Media: $jellyfin_media"
    echo "    Port: $jellyfin_port"
}

# Function to create Jellyfin directories
create_jellyfin_directories() {
    if [ -f "$ENV_PATH" ]; then
        source "$ENV_PATH"
    fi

    local jellyfin_config=$(expand_home "${JELLYFIN_CONFIG_DIR:-~/jellyfin_config}")
    local jellyfin_cache=$(expand_home "${JELLYFIN_CACHE_DIR:-~/jellyfin_cache}")

    echo "Creating Jellyfin directories..."

    # Create config directory
    if [ ! -d "$jellyfin_config" ]; then
        mkdir -p "$jellyfin_config"
        # Set ownership to the user who ran sudo (if applicable)
        if [ -n "$SUDO_USER" ]; then
            chown -R "$SUDO_USER:$SUDO_USER" "$jellyfin_config"
        fi
        echo "  ✓ Created config directory: $jellyfin_config"
    else
        echo "  ℹ Config directory already exists: $jellyfin_config"
    fi

    # Create cache directory
    if [ ! -d "$jellyfin_cache" ]; then
        mkdir -p "$jellyfin_cache"
        # Set ownership to the user who ran sudo (if applicable)
        if [ -n "$SUDO_USER" ]; then
            chown -R "$SUDO_USER:$SUDO_USER" "$jellyfin_cache"
        fi
        echo "  ✓ Created cache directory: $jellyfin_cache"
    else
        echo "  ℹ Cache directory already exists: $jellyfin_cache"
    fi
}

# Handle special flags
if [ "$1" = "--generate-compose" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo "ERROR: This script must be run as root (use sudo)"
        exit 1
    fi
    if [ -f "$ENV_PATH" ]; then
        source "$ENV_PATH"
        if [ -n "$DOCKER_COMPOSE_DIR" ] && [ "$DOCKER_COMPOSE_DIR" != "/path/to/your/docker/compose" ]; then
            generate_compose_file "$DOCKER_COMPOSE_DIR"
            echo "compose.yml generated successfully!"
            exit 0
        else
            echo "ERROR: DOCKER_COMPOSE_DIR not configured in $ENV_PATH"
            exit 1
        fi
    else
        echo "ERROR: Environment file not found at $ENV_PATH"
        exit 1
    fi
fi

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

# Create Jellyfin directories
create_jellyfin_directories

# Generate compose.yml if DOCKER_COMPOSE_DIR is set in env file
if [ -f "$ENV_PATH" ]; then
    source "$ENV_PATH"
    if [ -n "$DOCKER_COMPOSE_DIR" ] && [ "$DOCKER_COMPOSE_DIR" != "/path/to/your/docker/compose" ]; then
        generate_compose_file "$DOCKER_COMPOSE_DIR"
    else
        echo ""
        echo "⚠ DOCKER_COMPOSE_DIR not configured yet - compose.yml will be generated after configuration"
        echo "  After editing $ENV_PATH, run this to generate compose.yml:"
        echo "  sudo bash -c 'source $ENV_PATH && $(readlink -f "$0") --generate-compose-only'"
    fi
fi

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
echo "   - JELLYFIN_IMAGE, JELLYFIN_CONTAINER_NAME, JELLYFIN_CONFIG_DIR"
echo "   - JELLYFIN_CACHE_DIR, JELLYFIN_PORT, JELLYFIN_MEDIA_DIR"
echo ""
echo ""
echo "2. After configuring DOCKER_COMPOSE_DIR, regenerate compose.yml:"
echo "   sudo ./install.sh --generate-compose"
echo "   (or if install.sh is no longer available:"
echo "    cd /tmp && curl -O <repo-url>/install.sh && sudo bash install.sh --generate-compose)"
echo ""
echo "3. Verify required packages are installed:"
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