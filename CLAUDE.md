# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

This is a systemd service setup for automatically mounting a Synology NAS via
CIFS and starting Docker Compose services on boot. The system is designed to run
on an Intel NUC running Linux, specifically for managing a Jellyfin media server
setup.

## Architecture

The system consists of five main components:

1. **nas-mount-and-start.sh** - Main orchestration script that:
   - Validates required environment variables (NAS_PASSWORD, DOCKER_COMPOSE_DIR)
   - Waits for network connectivity (pings 8.8.8.8)
   - Checks NAS reachability (pings NAS_IP)
   - Mounts CIFS share from Synology NAS at /mnt/synology_nas/media
   - Verifies mount by checking for expected folders
   - Starts Docker Compose services from configured directory

2. **nas-mount-startup.service** - Systemd unit file that:
   - Runs after network-online.target and docker.service
   - Loads environment variables from /etc/nas-mount-startup.env
   - Executes the main script as oneshot with RemainAfterExit=yes
   - Configured with automatic restart on failure (30 second delay)

3. **nas-mount-startup.env.example** - Environment configuration template that:
   - Provides example configuration for all variables (NAS, Docker, and Jellyfin)
   - Documents required vs optional settings
   - Gets copied to /etc/nas-mount-startup.env during installation

4. **install.sh** - Installation script that:
   - Copies script to /usr/local/bin/nas-mount-and-start.sh
   - Copies service file to /etc/systemd/system/nas-mount-startup.service
   - Creates /etc/nas-mount-startup.env from template with secure permissions (600)
   - Creates Jellyfin config and cache directories (~/jellyfin_config, ~/jellyfin_cache)
   - **Dynamically generates compose.yml** from environment variables
   - Creates log file at /var/log/nas-mount-startup.log
   - Enables but doesn't start the service (requires configuration first)
   - Supports `--generate-compose` flag to regenerate compose.yml after config changes

5. **uninstall.sh** - Uninstallation script that:
   - Stops and disables the systemd service
   - Stops Docker containers via docker compose down
   - Unmounts the NAS
   - Removes all installed files (script, service, env, logs, compose.yml)
   - Lists optional cleanup for Jellyfin directories and mount point

## Key Configuration Variables

All configuration is managed via environment variables in `/etc/nas-mount-startup.env`:

**Required Variables:**
- `NAS_PASSWORD` - Password for CIFS mount (NO DEFAULT - must be set)
- `DOCKER_COMPOSE_DIR` - Directory where compose.yml will be generated (NO DEFAULT - must be set)

**Optional NAS Variables (with defaults):**
- `NAS_IP` - IP address of the Synology NAS (default: 192.168.1.241)
- `NAS_SHARE` - Name of the NAS share to mount (default: "Media")
- `NAS_USERNAME` - Username for CIFS mount (default: "devin")
- `MOUNT_POINT` - Local mount location (default: /mnt/synology_nas/media)
- `EXPECTED_FOLDERS` - Comma-separated list of folders to verify (default: "Movies,TV Shows,Music")
- `LOG_FILE` - Log file location (default: /var/log/nas-mount-startup.log)

**Optional Jellyfin Variables (with defaults):**
- `JELLYFIN_IMAGE` - Docker image for Jellyfin (default: jellyfin/jellyfin)
- `JELLYFIN_CONTAINER_NAME` - Name for the Jellyfin container (default: jellyfin)
- `JELLYFIN_CONFIG_DIR` - Directory for Jellyfin configuration (default: ~/jellyfin_config)
- `JELLYFIN_CACHE_DIR` - Directory for Jellyfin cache (default: ~/jellyfin_cache)
- `JELLYFIN_PORT` - HTTP port for Jellyfin (default: 8096, uses host networking)
- `JELLYFIN_MEDIA_DIR` - Path to media files from NAS (default: uses MOUNT_POINT value)

## Development and Testing

### Manual Testing

Before enabling the service, configure and test:
```bash
# Configure the environment file
sudo nano /etc/nas-mount-startup.env

# Test the script with environment variables loaded
sudo bash -c 'source /etc/nas-mount-startup.env && /usr/local/bin/nas-mount-and-start.sh'
```

Or with debug output:
```bash
sudo bash -xc 'source /etc/nas-mount-startup.env && /usr/local/bin/nas-mount-and-start.sh'
```

### Installation Process

```bash
# Run the installation script
chmod +x install.sh
sudo ./install.sh

# Configure the environment file (REQUIRED)
sudo nano /etc/nas-mount-startup.env
# Set NAS_PASSWORD and DOCKER_COMPOSE_DIR at minimum
# Optionally customize Jellyfin settings

# Generate compose.yml from environment variables
sudo ./install.sh --generate-compose

# Verify file permissions are secure
sudo chmod 600 /etc/nas-mount-startup.env

# Start the service:
sudo systemctl start nas-mount-startup
```

### Service Management

```bash
# View logs
sudo journalctl -u nas-mount-startup -f
tail -f /var/log/nas-mount-startup.log

# Check status
sudo systemctl status nas-mount-startup

# Restart service
sudo systemctl restart nas-mount-startup

# Disable service
sudo systemctl disable nas-mount-startup
```

### Testing CIFS Mount Manually

```bash
sudo mount -t cifs -o username=devin,password=PASSWORD //192.168.1.241/Media /mnt/synology_nas/media
```

### Testing Docker Compose
```bash
cd /path/to/docker/compose
sudo docker compose up -d
```

## Important Implementation Details

1. **Dynamic compose.yml Generation**: The compose.yml file is NOT stored in version control. Instead, it's dynamically generated by install.sh based on environment variables. This approach:
   - Allows each installation to be customized via environment variables
   - Prevents hardcoded paths or credentials from being committed to git
   - Enables easy reconfiguration via `sudo ./install.sh --generate-compose`
   - Creates Jellyfin container configuration with user-specified directories and settings

2. **Directory Auto-Creation**: During installation, the script automatically creates:
   - Jellyfin config directory (default: ~/jellyfin_config) with proper ownership
   - Jellyfin cache directory (default: ~/jellyfin_cache) with proper ownership
   - Docker Compose directory if it doesn't exist
   - Directories are owned by $SUDO_USER to avoid permission issues

3. **Configuration Validation**: The script validates that NAS_PASSWORD and DOCKER_COMPOSE_DIR are set before proceeding. If either is missing or has placeholder values, it exits with an error message.

4. **Environment Variable Loading**: All configuration uses environment variables with defaults via bash parameter expansion (e.g., `${NAS_IP:-192.168.1.241}`).

5. **Network Dependency Chain**: The script waits for network-online.target, then pings 8.8.8.8 up to 30 times (2 second intervals) before attempting NAS connectivity.

6. **Mount Verification**: The script checks both that the mount point is active (via `mountpoint -q`) and that expected folders exist. If folders are missing, it logs a warning but continues.

7. **Idempotency**: The script checks if NAS is already mounted before attempting mount, and verifies existing mounts.

8. **Error Handling**: Failed mount or Docker startup exits with code 1, triggering systemd's restart policy after 30 seconds.

9. **Logging**: All operations log to both systemd journal and /var/log/nas-mount-startup.log with timestamps.

10. **CIFS Mount Options**: Uses uid=1000, gid=1000, and iocharset=utf8 for proper permissions and character encoding.

11. **Tilde Expansion**: The install script properly expands `~` in directory paths (like ~/jellyfin_config) to the actual user's home directory, even when run via sudo.

## Security Considerations

**Current Implementation:**
- NAS credentials are stored in `/etc/nas-mount-startup.env` (NOT in the script)
- The environment file has restrictive permissions (600 - only root can read)
- The script runs as root via systemd service
- Systemd loads environment variables securely via `EnvironmentFile` directive
- The environment file is never committed to version control

**Security Best Practices:**
- Use a dedicated NAS user with limited permissions (read-only access to media share)
- Regularly rotate the NAS password
- Never commit `/etc/nas-mount-startup.env` to version control
- Consider using CIFS credentials file (`credentials=` mount option) for additional security
- Monitor the log file at /var/log/nas-mount-startup.log for unauthorized access attempts

**Alternative: CIFS Credentials File**
For even better security, the mount command can be modified to use `/etc/nas-credentials` with the `credentials=` option instead of passing username/password directly.
