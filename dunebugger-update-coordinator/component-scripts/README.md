# Component Update Scripts

Example update, rollback, and health-check scripts for each DuneBugger component.

## Overview

Each component must provide three standard scripts that the update coordinator will execute:

1. **update.sh** - Update component to a new version
2. **rollback.sh** - Rollback to previous version
3. **health-check.sh** - Verify component is healthy

## Script Interface

### update.sh

**Purpose:** Update component to a new version

**Arguments:**
- `$1` - Target version (e.g., "1.2.3")

**Exit Codes:**
- `0` - Update successful
- `non-zero` - Update failed

**Example:**
```bash
./update.sh 1.2.3
```

### rollback.sh

**Purpose:** Rollback to previous version

**Arguments:** None

**Exit Codes:**
- `0` - Rollback successful
- `non-zero` - Rollback failed

**Example:**
```bash
./rollback.sh
```

### health-check.sh

**Purpose:** Verify component is healthy

**Arguments:** None

**Exit Codes:**
- `0` - Component is healthy
- `non-zero` - Component is unhealthy

**Example:**
```bash
./health-check.sh
```

## Component-Specific Details

### Remote (Container)

**Location:** `/opt/dunebugger/remote/`

**What it does:**
- Updates docker-compose.yml with new image tag
- Pulls new image from GHCR
- Restarts container with `docker-compose up -d`
- Verifies container is running

**Dependencies:**
- docker
- docker-compose
- Access to docker-compose.yml

### Scheduler (Container)

**Location:** `/opt/dunebugger/scheduler/`

**What it does:**
- Similar to remote component
- Updates scheduler image tag
- Restarts scheduler container

**Dependencies:**
- docker
- docker-compose
- Access to docker-compose.yml

### Core (Python Application)

**Location:** `/opt/dunebugger/core/`

**What it does:**
- Downloads release artifact from GitHub
- Creates backup of current installation
- Stops systemd service
- Extracts new version
- Installs Python dependencies
- Starts service

**Dependencies:**
- systemd
- wget
- tar
- pip3
- Python 3.7+

## Installation

Copy the appropriate scripts to each component directory:

```bash
# Remote component
sudo cp remote/*.sh /opt/dunebugger/remote/
sudo chmod +x /opt/dunebugger/remote/*.sh

# Scheduler component
sudo cp scheduler/*.sh /opt/dunebugger/scheduler/
sudo chmod +x /opt/dunebugger/scheduler/*.sh

# Core component
sudo cp core/*.sh /opt/dunebugger/core/
sudo chmod +x /opt/dunebugger/core/*.sh
```

## Testing Scripts

Test each script manually before using with the coordinator:

```bash
# Test health check
sudo /opt/dunebugger/remote/health-check.sh
echo "Exit code: $?"

# Test update (use a valid version)
sudo /opt/dunebugger/remote/update.sh 1.0.0

# Test rollback
sudo /opt/dunebugger/remote/rollback.sh
```

## Customization

These scripts are examples and may need customization for your environment:

- **Image names:** Update GHCR image paths
- **Paths:** Adjust install directories
- **Timeouts:** Modify wait times for your hardware
- **Backup retention:** Add cleanup of old backups
- **Validation:** Add more comprehensive health checks

## Best Practices

1. **Idempotency:** Scripts should be safe to run multiple times
2. **Logging:** Include clear progress messages
3. **Error Handling:** Use `set -e` and check critical commands
4. **Backups:** Always backup before making changes
5. **Rollback:** Implement automatic rollback on failure
6. **Validation:** Verify success before reporting completion

## Troubleshooting

### Script fails with permission error

```bash
# Ensure scripts are executable
sudo chmod +x /opt/dunebugger/*/update.sh
sudo chmod +x /opt/dunebugger/*/rollback.sh
sudo chmod +x /opt/dunebugger/*/health-check.sh
```

### Update fails to download artifact

```bash
# Verify GitHub release exists
# Check if version format matches (v1.2.3 vs 1.2.3)
# Verify network connectivity
wget -q --spider https://github.com/marco-svitol/dunebugger/releases
```

### Container update fails

```bash
# Verify docker-compose.yml exists
ls -la /opt/dunebugger/docker-compose.yml

# Test docker-compose commands manually
docker-compose -f /opt/dunebugger/docker-compose.yml config
```

### Service rollback fails

```bash
# Check if backup exists
ls -la /opt/dunebugger/backups/

# Verify systemd service
systemctl status dunebugger
```
