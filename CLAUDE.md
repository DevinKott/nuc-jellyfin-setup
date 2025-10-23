# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

This is a systemd service setup for automatically mounting a Synology NAS via
CIFS and starting Docker Compose services on boot. The system is designed to run
on an Intel NUC running Linux, specifically for managing a Jellyfin media server
setup.

## Architecture

The system consists of four main components:

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
   - Provides example configuration for all variables
   - Documents required vs optional settings
   - Gets copied to /etc/nas-mount-startup.env during installation

4. **install.sh** - Installation script that:
   - Copies script to /usr/local/bin/nas-mount-and-start.sh
   - Copies service file to /etc/systemd/system/nas-mount-startup.service
   - Creates /etc/nas-mount-startup.env from template with secure permissions (600)
   - Creates log file at /var/log/nas-mount-startup.log
   - Enables but doesn't start the service (requires configuration first)

## Key Configuration Variables

All configuration is managed via environment variables in `/etc/nas-mount-startup.env`:

**Required Variables:**
- `NAS_PASSWORD` - Password for CIFS mount (NO DEFAULT - must be set)
- `DOCKER_COMPOSE_DIR` - Directory containing compose.yml (NO DEFAULT - must be set)

**Optional Variables (with defaults):**
- `NAS_IP` - IP address of the Synology NAS (default: 192.168.1.241)
- `NAS_SHARE` - Name of the NAS share to mount (default: "Media")
- `NAS_USERNAME` - Username for CIFS mount (default: "devin")
- `MOUNT_POINT` - Local mount location (default: /mnt/synology_nas/media)
- `EXPECTED_FOLDERS` - Comma-separated list of folders to verify (default: "Movies,TV Shows,Music")
- `LOG_FILE` - Log file location (default: /var/log/nas-mount-startup.log)

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

1. **Configuration Validation**: The script validates that NAS_PASSWORD and DOCKER_COMPOSE_DIR are set before proceeding. If either is missing or has placeholder values, it exits with an error message.
2. **Environment Variable Loading**: All configuration uses environment variables with defaults via bash parameter expansion (e.g., `${NAS_IP:-192.168.1.241}`).
3. **Network Dependency Chain**: The script waits for network-online.target, then pings 8.8.8.8 up to 30 times (2 second intervals) before attempting NAS connectivity.
4. **Mount Verification**: The script checks both that the mount point is active (via `mountpoint -q`) and that expected folders exist. If folders are missing, it logs a warning but continues.
5. **Idempotency**: The script checks if NAS is already mounted before attempting mount, and verifies existing mounts.
6. **Error Handling**: Failed mount or Docker startup exits with code 1, triggering systemd's restart policy after 30 seconds.
7. **Logging**: All operations log to both systemd journal and /var/log/nas-mount-startup.log with timestamps.
8. **CIFS Mount Options**: Uses uid=1000, gid=1000, and iocharset=utf8 for proper permissions and character encoding.

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
