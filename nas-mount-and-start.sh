#!/bin/bash

# NAS Mount and Docker Startup Script
# This script mounts a Synology NAS and starts Docker Compose services
# Designed to run on boot via systemd service

# Configuration
# Note: NAS_PASSWORD should be set via environment variable or in /etc/nas-mount-startup.env
NAS_IP="${NAS_IP:-192.168.1.241}"
NAS_SHARE="${NAS_SHARE:-Media}"
NAS_USERNAME="${NAS_USERNAME:-devin}"
NAS_PASSWORD="${NAS_PASSWORD:-}"
MOUNT_POINT="${MOUNT_POINT:-/mnt/synology_nas/media}"
DOCKER_COMPOSE_DIR="${DOCKER_COMPOSE_DIR:-/path/to/your/docker/compose}"  # UPDATE THIS PATH
LOG_FILE="${LOG_FILE:-/var/log/nas-mount-startup.log}"

# Expected folders to verify successful mount (customize as needed)
# Set via EXPECTED_FOLDERS env var (comma-separated) or use default
IFS=',' read -ra EXPECTED_FOLDERS <<< "${EXPECTED_FOLDERS:-Movies,TV Shows,Music}"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to check if NAS is pingable
check_nas_connectivity() {
    log "Checking connectivity to NAS at $NAS_IP..."
    if ping -c 3 -W 5 "$NAS_IP" >/dev/null 2>&1; then
        log "NAS is reachable"
        return 0
    else
        log "ERROR: Cannot reach NAS at $NAS_IP"
        return 1
    fi
}

# Function to check if NAS is already mounted
is_nas_mounted() {
    if mountpoint -q "$MOUNT_POINT"; then
        log "NAS is already mounted at $MOUNT_POINT"
        return 0
    else
        log "NAS is not mounted"
        return 1
    fi
}

# Function to mount the NAS
mount_nas() {
    log "Attempting to mount NAS..."
    
    # Create mount point if it doesn't exist
    if [ ! -d "$MOUNT_POINT" ]; then
        log "Creating mount point directory: $MOUNT_POINT"
        mkdir -p "$MOUNT_POINT"
    fi
    
    # Mount the NAS
    if mount -t cifs -o username="$NAS_USERNAME",password="$NAS_PASSWORD",uid=1000,gid=1000,iocharset=utf8 \
        "//$NAS_IP/$NAS_SHARE" "$MOUNT_POINT"; then
        log "Successfully mounted NAS"
        return 0
    else
        log "ERROR: Failed to mount NAS"
        return 1
    fi
}

# Function to verify mount contents
verify_mount() {
    log "Verifying mount contents..."
    
    # Check if mount point exists and is accessible
    if [ ! -d "$MOUNT_POINT" ]; then
        log "ERROR: Mount point does not exist"
        return 1
    fi
    
    # Check if we can list the directory
    if ! ls "$MOUNT_POINT" >/dev/null 2>&1; then
        log "ERROR: Cannot access mount point contents"
        return 1
    fi
    
    # Check for expected folders
    local missing_folders=()
    for folder in "${EXPECTED_FOLDERS[@]}"; do
        if [ ! -d "$MOUNT_POINT/$folder" ]; then
            missing_folders+=("$folder")
        fi
    done
    
    if [ ${#missing_folders[@]} -eq 0 ]; then
        log "All expected folders found in mount"
        return 0
    else
        log "WARNING: Missing expected folders: ${missing_folders[*]}"
        log "Mount appears to be successful but may not contain expected content"
        return 0  # Continue anyway, might be acceptable
    fi
}

# Function to start Docker Compose
start_docker_services() {
    log "Starting Docker Compose services..."
    
    # Check if Docker Compose directory exists
    if [ ! -d "$DOCKER_COMPOSE_DIR" ]; then
        log "ERROR: Docker Compose directory does not exist: $DOCKER_COMPOSE_DIR"
        return 1
    fi
    
    # Check if compose.yml exists
    if [ ! -f "$DOCKER_COMPOSE_DIR/compose.yml" ] && [ ! -f "$DOCKER_COMPOSE_DIR/docker-compose.yml" ]; then
        log "ERROR: No compose.yml or docker-compose.yml found in $DOCKER_COMPOSE_DIR"
        return 1
    fi
    
    # Change to the Docker Compose directory and start services
    cd "$DOCKER_COMPOSE_DIR" || {
        log "ERROR: Cannot change to Docker Compose directory"
        return 1
    }
    
    if docker compose up -d; then
        log "Successfully started Docker Compose services"
        return 0
    else
        log "ERROR: Failed to start Docker Compose services"
        return 1
    fi
}

# Function to wait for network to be ready
wait_for_network() {
    log "Waiting for network to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            log "Network is ready"
            return 0
        fi
        log "Network not ready, attempt $attempt/$max_attempts"
        sleep 2
        ((attempt++))
    done
    
    log "WARNING: Network may not be fully ready after $max_attempts attempts"
    return 1
}

# Main execution
main() {
    log "=== NAS Mount and Docker Startup Script Started ==="

    # Validate required configuration
    if [ -z "$NAS_PASSWORD" ]; then
        log "ERROR: NAS_PASSWORD environment variable is not set"
        log "Please set NAS_PASSWORD in /etc/nas-mount-startup.env or as an environment variable"
        exit 1
    fi

    if [ "$DOCKER_COMPOSE_DIR" = "/path/to/your/docker/compose" ]; then
        log "ERROR: DOCKER_COMPOSE_DIR has not been configured"
        log "Please set DOCKER_COMPOSE_DIR in /etc/nas-mount-startup.env or update the script"
        exit 1
    fi

    # Wait for network to be ready
    wait_for_network
    
    # Check if NAS is already mounted
    if is_nas_mounted; then
        log "NAS already mounted, verifying contents..."
        if verify_mount; then
            log "Mount verification successful"
        else
            log "Mount verification failed, attempting remount..."
            umount "$MOUNT_POINT" 2>/dev/null
            sleep 2
        fi
    fi
    
    # If not mounted or verification failed, attempt to mount
    if ! is_nas_mounted; then
        # Check connectivity first
        if ! check_nas_connectivity; then
            log "ERROR: Cannot proceed without NAS connectivity"
            exit 1
        fi
        
        # Attempt to mount
        if ! mount_nas; then
            log "ERROR: Failed to mount NAS, exiting"
            exit 1
        fi
        
        # Verify the mount
        if ! verify_mount; then
            log "ERROR: Mount verification failed"
            exit 1
        fi
    fi
    
    # Start Docker services
    if start_docker_services; then
        log "=== Script completed successfully ==="
    else
        log "=== Script completed with Docker startup errors ==="
        exit 1
    fi
}

# Run main function
main "$@"