# NAS Mount and Docker Startup Service

This service automatically mounts your Synology NAS and starts Docker Compose
services on boot.
Vibe-coded with Claude.

## Features

- ✅ Waits for network connectivity before attempting mount
- ✅ Pings NAS to verify connectivity
- ✅ Checks if NAS is already mounted
- ✅ Mounts NAS using CIFS if not already mounted
- ✅ Verifies mount contents by checking for expected folders
- ✅ Starts Docker Compose services after successful mount
- ✅ Comprehensive logging
- ✅ Automatic retry on failure
- ✅ Runs as systemd service on boot

## Files

- `nas-mount-and-start.sh` - Main script that handles mounting and Docker startup
- `nas-mount-startup.service` - Systemd service file
- `nas-mount-startup.env.example` - Environment configuration template
- `install.sh` - Installation script
- `uninstall.sh` - Uninstallation/teardown script

## Prerequisites

1. **Install required packages:**
   ```bash
   sudo apt update
   sudo apt install cifs-utils docker.io docker-compose-plugin
   ```

2. **Enable Docker service:**
   ```bash
   sudo systemctl enable docker
   ```

## Installation

1. **Download the files** to your NUC

2. **Run the installation script:**
   ```bash
   chmod +x install.sh
   sudo ./install.sh
   ```

3. **Configure the environment file** at `/etc/nas-mount-startup.env`:
   ```bash
   sudo nano /etc/nas-mount-startup.env
   ```

   **Required settings** (you MUST change these):
   ```bash
   NAS_PASSWORD=your_actual_nas_password
   DOCKER_COMPOSE_DIR=/path/to/your/docker/compose
   ```

   **Optional settings** (uncomment and modify if needed):
   ```bash
   #NAS_IP=192.168.1.241
   #NAS_USERNAME=devin
   #NAS_SHARE=Media
   #MOUNT_POINT=/mnt/synology_nas/media
   #EXPECTED_FOLDERS=Movies,TV Shows,Music
   ```

4. **Verify the configuration file permissions**:
   ```bash
   sudo chmod 600 /etc/nas-mount-startup.env
   ```

5. **Start the service**:
   ```bash
   sudo systemctl start nas-mount-startup
   ```

## Configuration

All configuration is managed through `/etc/nas-mount-startup.env`. This file is automatically created during installation but **you must edit it** before starting the service.

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `NAS_PASSWORD` | **YES** | *(none)* | Password for NAS CIFS mount |
| `DOCKER_COMPOSE_DIR` | **YES** | `/path/to/your/docker/compose` | Path to directory with compose.yml |
| `NAS_IP` | No | `192.168.1.241` | IP address of your NAS |
| `NAS_USERNAME` | No | `devin` | Username for NAS authentication |
| `NAS_SHARE` | No | `Media` | Name of the NAS share to mount |
| `MOUNT_POINT` | No | `/mnt/synology_nas/media` | Local mount point path |
| `EXPECTED_FOLDERS` | No | `Movies,TV Shows,Music` | Comma-separated folders to verify |
| `LOG_FILE` | No | `/var/log/nas-mount-startup.log` | Log file location |

### Updating Configuration

After modifying `/etc/nas-mount-startup.env`:

```bash
# Reload the systemd service configuration
sudo systemctl daemon-reload

# Restart the service to apply changes
sudo systemctl restart nas-mount-startup
```

## Usage

### Service Management

```bash
# Start the service
sudo systemctl start nas-mount-startup

# Stop the service
sudo systemctl stop nas-mount-startup

# Check service status
sudo systemctl status nas-mount-startup

# View service logs
sudo journalctl -u nas-mount-startup -f

# Restart the service
sudo systemctl restart nas-mount-startup
```

### Manual Testing

Test the script manually (make sure `/etc/nas-mount-startup.env` is configured first):

```bash
# Load environment variables and run the script
sudo bash -c 'source /etc/nas-mount-startup.env && /usr/local/bin/nas-mount-and-start.sh'
```

### Logs

The service creates logs in two places:

- **Systemd journal**: `sudo journalctl -u nas-mount-startup`
- **Log file**: `/var/log/nas-mount-startup.log`

## Uninstallation

To completely remove the NAS mount service from your system:

### Quick Removal

```bash
chmod +x uninstall.sh
sudo ./uninstall.sh
```

The uninstall script will automatically:
- Stop and disable the systemd service
- Unmount the NAS (if mounted)
- Remove all installed files (script, service file, environment file, logs)
- Reload systemd daemon

### Manual Removal

If you prefer to remove components manually:

```bash
# Stop and disable the service
sudo systemctl stop nas-mount-startup
sudo systemctl disable nas-mount-startup

# Unmount NAS (if mounted)
sudo umount /mnt/synology_nas/media

# Remove installed files
sudo rm -f /usr/local/bin/nas-mount-and-start.sh
sudo rm -f /etc/systemd/system/nas-mount-startup.service
sudo rm -f /etc/nas-mount-startup.env
sudo rm -f /var/log/nas-mount-startup.log

# Reload systemd
sudo systemctl daemon-reload
sudo systemctl reset-failed

# Optional: Remove mount point directory
sudo rmdir /mnt/synology_nas/media
```

### Complete Cleanup

After uninstalling, you may also want to:

1. **Stop Docker containers** (if they were started by the service):
   ```bash
   cd /your/docker/compose/dir
   sudo docker compose down
   ```

2. **Remove mount point directory** (if no longer needed):
   ```bash
   sudo rmdir /mnt/synology_nas/media
   ```

## Testing Workflow

For developers or users who want to quickly test the installation/removal:

```bash
# Install
chmod +x install.sh
sudo ./install.sh
sudo nano /etc/nas-mount-startup.env  # Configure required settings
sudo systemctl start nas-mount-startup

# Test
sudo systemctl status nas-mount-startup
sudo journalctl -u nas-mount-startup -f

# Uninstall
chmod +x uninstall.sh
sudo ./uninstall.sh
```

This workflow is particularly useful when testing configuration changes or debugging issues.

## Troubleshooting

### Common Issues

1. **"Cannot reach NAS"**
   - Check if NAS IP is correct
   - Verify NAS is powered on and network is working
   - Test manually: `ping 192.168.1.241`

2. **"Failed to mount NAS"**
   - Verify username/password in `/etc/nas-mount-startup.env` are correct
   - Check if `cifs-utils` is installed: `sudo apt install cifs-utils`
   - Test manual mount (replace with your values):
     ```bash
     sudo mount -t cifs -o username=devin,password=YOUR_PASSWORD //192.168.1.241/Media /mnt/synology_nas/media
     ```

3. **"NAS_PASSWORD environment variable is not set"**
   - Make sure you've created and configured `/etc/nas-mount-startup.env`
   - Verify the file has the correct permissions: `sudo chmod 600 /etc/nas-mount-startup.env`
   - Check that the systemd service is loading it: `sudo systemctl cat nas-mount-startup`

4. **"DOCKER_COMPOSE_DIR has not been configured"**
   - Set `DOCKER_COMPOSE_DIR` in `/etc/nas-mount-startup.env`
   - Ensure the path contains `compose.yml` or `docker-compose.yml`

5. **"Failed to start Docker Compose services"**
   - Check if Docker is running: `sudo systemctl status docker`
   - Test Docker Compose manually: `cd /your/docker/dir && sudo docker compose up -d`

### Debug Mode

To see detailed output, run the script manually with debug mode:

```bash
sudo bash -xc 'source /etc/nas-mount-startup.env && /usr/local/bin/nas-mount-and-start.sh'
```

### Disable Service

If you need to disable the service:

```bash
sudo systemctl disable nas-mount-startup
sudo systemctl stop nas-mount-startup
```

## Security Notes

- **Password Storage**: NAS password is stored in `/etc/nas-mount-startup.env` (not in the script itself)
- **File Permissions**: The environment file has restrictive permissions (600) so only root can read it
- **Service Execution**: The systemd service runs as root and loads the environment file securely
- **Best Practices**:
  - Use a dedicated NAS user with limited permissions (read-only access to the media share)
  - Never commit `/etc/nas-mount-startup.env` to version control
  - Regularly rotate your NAS password
  - Consider using a credentials file with `credentials=` mount option for additional security

## Customization

### Adding More Verification

You can add more verification steps in the `verify_mount()` function:

```bash
# Example: Check for specific files
if [ ! -f "$MOUNT_POINT/Movies/test-file.txt" ]; then
    log "WARNING: Test file not found"
fi
```

### Different Docker Compose Commands

Modify the `start_docker_services()` function for different Docker commands:

```bash
# Example: Use specific compose file
docker compose -f jellyfin-compose.yml up -d

# Example: Start only specific services
docker compose up -d jellyfin
```

### Using Credentials File (Alternative to Environment Variables)

For even better security, you can use a CIFS credentials file instead of environment variables:

1. Create a credentials file:
   ```bash
   sudo nano /etc/nas-credentials
   ```

2. Add your credentials:
   ```
   username=devin
   password=your_password_here
   ```

3. Secure the file:
   ```bash
   sudo chmod 600 /etc/nas-credentials
   ```

4. Modify the mount command in `nas-mount-and-start.sh` (line 58):
   ```bash
   mount -t cifs -o credentials=/etc/nas-credentials,uid=1000,gid=1000,iocharset=utf8 \
       "//$NAS_IP/$NAS_SHARE" "$MOUNT_POINT"
   ```