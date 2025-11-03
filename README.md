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
- `install.sh` - Installation script (also generates compose.yml)
- `uninstall.sh` - Uninstallation/teardown script
- `compose.yml` - **Auto-generated** during installation (not in repo)

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

   **Optional NAS settings** (uncomment and modify if needed):
   ```bash
   #NAS_IP=192.168.1.241
   #NAS_USERNAME=devin
   #NAS_SHARE=Media
   #MOUNT_POINT=/mnt/synology_nas/media
   #EXPECTED_FOLDERS=Movies,TV Shows,Music
   ```

   **Optional Jellyfin settings** (uncomment and modify if needed):
   ```bash
   #JELLYFIN_IMAGE=jellyfin/jellyfin
   #JELLYFIN_CONTAINER_NAME=jellyfin
   #JELLYFIN_CONFIG_DIR=~/jellyfin_config
   #JELLYFIN_CACHE_DIR=~/jellyfin_cache
   #JELLYFIN_PORT=8096
   #JELLYFIN_MEDIA_DIR=/mnt/synology_nas/media
   ```

   **Optional TinyMediaManager settings** (uncomment and modify if needed):
   ```bash
   #TMM_IMAGE=tinymediamanager/tinymediamanager:latest
   #TMM_CONTAINER_NAME=tmm
   #TMM_DATA_DIR=~/tmm-data
   #TMM_PORT=4000
   #TMM_TZ=America/Denver
   #TMM_TVSHOWS_DIR=/mnt/synology_nas/media/TV Shows
   #TMM_MOVIES_DIR=/mnt/synology_nas/media/Movies
   ```

4. **Generate the compose.yml file** after configuring DOCKER_COMPOSE_DIR:
   ```bash
   sudo ./install.sh --generate-compose
   ```
   This creates a `compose.yml` file in your `DOCKER_COMPOSE_DIR` with Jellyfin and TinyMediaManager configuration based on your environment variables.

5. **Verify the configuration file permissions**:
   ```bash
   sudo chmod 600 /etc/nas-mount-startup.env
   ```

6. **Start the service**:
   ```bash
   sudo systemctl start nas-mount-startup
   ```

## Configuration

All configuration is managed through `/etc/nas-mount-startup.env`. This file is automatically created during installation but **you must edit it** before starting the service.

### Environment Variables

#### Required Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `NAS_PASSWORD` | *(none)* | Password for NAS CIFS mount |
| `DOCKER_COMPOSE_DIR` | `/path/to/your/docker/compose` | Path where compose.yml will be generated |

#### Optional NAS Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `NAS_IP` | `192.168.1.241` | IP address of your NAS |
| `NAS_USERNAME` | `devin` | Username for NAS authentication |
| `NAS_SHARE` | `Media` | Name of the NAS share to mount |
| `MOUNT_POINT` | `/mnt/synology_nas/media` | Local mount point path |
| `EXPECTED_FOLDERS` | `Movies,TV Shows,Music` | Comma-separated folders to verify |
| `LOG_FILE` | `/var/log/nas-mount-startup.log` | Log file location |

#### Optional Jellyfin Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `JELLYFIN_IMAGE` | `jellyfin/jellyfin` | Docker image for Jellyfin |
| `JELLYFIN_CONTAINER_NAME` | `jellyfin` | Name for the Jellyfin container |
| `JELLYFIN_CONFIG_DIR` | `~/jellyfin_config` | Directory for Jellyfin configuration |
| `JELLYFIN_CACHE_DIR` | `~/jellyfin_cache` | Directory for Jellyfin cache |
| `JELLYFIN_PORT` | `8096` | HTTP port for Jellyfin (host networking) |
| `JELLYFIN_MEDIA_DIR` | `${MOUNT_POINT}` | Path to media files from NAS |

#### Optional TinyMediaManager Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `TMM_IMAGE` | `tinymediamanager/tinymediamanager:latest` | Docker image for TinyMediaManager |
| `TMM_CONTAINER_NAME` | `tmm` | Name for the TinyMediaManager container |
| `TMM_DATA_DIR` | `~/tmm-data` | Directory for TinyMediaManager data/config |
| `TMM_PORT` | `4000` | HTTP port for TinyMediaManager web interface |
| `TMM_TZ` | `America/Denver` | Timezone for TinyMediaManager |
| `TMM_TVSHOWS_DIR` | `${MOUNT_POINT}/TV Shows` | Path to TV shows from NAS |
| `TMM_MOVIES_DIR` | `${MOUNT_POINT}/Movies` | Path to movies from NAS |

### Updating Configuration

After modifying `/etc/nas-mount-startup.env`:

```bash
# If you changed any Jellyfin or TinyMediaManager settings, regenerate compose.yml
sudo ./install.sh --generate-compose

# Reload the systemd service configuration
sudo systemctl daemon-reload

# Restart the service to apply changes
sudo systemctl restart nas-mount-startup
```

### Auto-Generated compose.yml

The `compose.yml` file is **automatically generated** by the installer based on your environment variables. This means:

- **Do not edit compose.yml directly** - your changes will be overwritten
- **Edit `/etc/nas-mount-startup.env` instead** - then regenerate with `sudo ./install.sh --generate-compose`
- The file is **not tracked in git** - it's created fresh on each system based on local configuration
- **Location**: Generated in `$DOCKER_COMPOSE_DIR/compose.yml`

Example generated compose.yml:
```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin
    container_name: jellyfin
    network_mode: 'host' # Port 8096
    volumes:
      - /home/user/jellyfin_config:/config
      - /home/user/jellyfin_cache:/cache
      - type: bind
        source: /mnt/synology_nas/media
        target: /media
    devices:
      - /dev/dri:/dev/dri

  tinymediamanager:
    image: tinymediamanager/tinymediamanager:latest
    container_name: tmm
    ports:
      - "4000:4000"
    environment:
      - TZ=America/Denver
      - USER_ID=1000
      - GROUP_ID=1000
      - LC_ALL=en_US.UTF-8
      - LANG=en_US.UTF-8
    volumes:
      - /home/user/tmm-data:/data
      - /mnt/synology_nas/media/TV Shows:/media/tvshows
      - /mnt/synology_nas/media/Movies:/media/movies
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
   - Generate compose.yml: `sudo ./install.sh --generate-compose`

5. **"No compose.yml or docker-compose.yml found"**
   - Generate the compose.yml file: `sudo ./install.sh --generate-compose`
   - Verify DOCKER_COMPOSE_DIR is set correctly in `/etc/nas-mount-startup.env`
   - Check that the directory exists: `ls -la $DOCKER_COMPOSE_DIR`

6. **"Failed to start Docker Compose services"**
   - Check if Docker is running: `sudo systemctl status docker`
   - Verify compose.yml is valid: `cd $DOCKER_COMPOSE_DIR && docker compose config`
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

### Customizing Jellyfin Configuration

All Jellyfin settings are controlled via environment variables in `/etc/nas-mount-startup.env`:

```bash
# Use a specific Jellyfin version
JELLYFIN_IMAGE=jellyfin/jellyfin:10.8.13

# Change container name
JELLYFIN_CONTAINER_NAME=my-jellyfin

# Use different directories
JELLYFIN_CONFIG_DIR=/opt/jellyfin/config
JELLYFIN_CACHE_DIR=/opt/jellyfin/cache

# Change port (requires regenerating compose.yml)
JELLYFIN_PORT=8097

# Point to different media location
JELLYFIN_MEDIA_DIR=/mnt/other-nas/movies
```

After changing any settings, regenerate compose.yml:
```bash
sudo ./install.sh --generate-compose
sudo systemctl restart nas-mount-startup
```

### Customizing TinyMediaManager Configuration

All TinyMediaManager settings are controlled via environment variables in `/etc/nas-mount-startup.env`:

```bash
# Use a specific TinyMediaManager version
TMM_IMAGE=tinymediamanager/tinymediamanager:4.3

# Change container name
TMM_CONTAINER_NAME=my-tmm

# Use different data directory
TMM_DATA_DIR=/opt/tmm/data

# Change port
TMM_PORT=4001

# Change timezone
TMM_TZ=Europe/London

# Point to different media locations
TMM_TVSHOWS_DIR=/mnt/nas/series
TMM_MOVIES_DIR=/mnt/nas/films
```

After changing any settings, regenerate compose.yml:
```bash
sudo ./install.sh --generate-compose
sudo systemctl restart nas-mount-startup
```

### Adding More Verification

You can add more verification steps in the `verify_mount()` function:

```bash
# Example: Check for specific files
if [ ! -f "$MOUNT_POINT/Movies/test-file.txt" ]; then
    log "WARNING: Test file not found"
fi
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