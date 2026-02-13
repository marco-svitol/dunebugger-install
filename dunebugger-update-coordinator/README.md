# DuneBugger Update Coordinator

A lightweight host-side service that executes component update scripts in response to requests from the dunebugger-remote container.

## Architecture

The update coordinator implements a hybrid approach to container self-updates:

- **dunebugger-remote** (in container): Coordinates updates, checks versions, provides WebSocket API
- **update-coordinator** (on host): Executes Docker/system commands with proper privileges
- **Shared volume**: File-based communication between container and host

```
┌─────────────────────────────────────────────────────────────────┐
│                      Raspberry Pi Host                          │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Update Coordinator (systemd service)                  │    │
│  │  - Watches /var/dunebugger/updates/requests/          │    │
│  │  - Executes component scripts                          │    │
│  │  - Writes status to /var/dunebugger/updates/status/   │    │
│  └────────────────┬───────────────────────────────────────┘    │
│                   │                                             │
│       ┌───────────┼───────────────┬──────────────────┐         │
│       ▼           ▼               ▼                   │         │
│   ┌──────┐   ┌─────────┐   ┌──────────┐             │         │
│   │ core │   │scheduler│   │  remote  │ (containers) │         │
│   │      │   │         │   │          │              │         │
│   │update│   │ update  │   │  update  │              │         │
│   │.sh   │   │ .sh     │   │  .sh     │              │         │
│   └──────┘   └─────────┘   └──────────┘              │         │
│                                                        │         │
│  Shared Volume: /var/dunebugger/updates/             │         │
│  ├── requests/  ← dunebugger-remote writes here      │         │
│  └── status/    ← coordinator writes here            │         │
└──────────────────────────────────────────────────────┘         │
                                                                  │
         ┌────────────────────────────────────────────────────┐  │
         │  dunebugger-remote container                       │  │
         │  - Checks for updates periodically                 │  │
         │  - Writes requests to shared volume                │  │
         │  - Polls status directory                          │  │
         │  - Provides WebSocket API                          │  │
         └────────────────────────────────────────────────────┘  │
                                                                  │
                    (volume mounted at both sides)               │
                                                                  │
```

## Installation

### Prerequisites

- Python 3.7+
- pip3
- systemd (typically pre-installed on Raspberry Pi OS)
- Docker and docker-compose (should already be installed)

### Install Coordinator

```bash
cd _host_coordinator
sudo ./install.sh
```

This will:
1. Install the coordinator script to `/opt/dunebugger/update-coordinator/`
2. Create required directories (`/var/dunebugger/updates/`)
3. Install and start the systemd service
4. Verify the service is running

### Verify Installation

```bash
# Check service status
sudo systemctl status dunebugger-update-coordinator

# View logs
sudo journalctl -u dunebugger-update-coordinator -f

# Check directories
ls -la /var/dunebugger/updates/
```

## Component Scripts

Each component must provide standard scripts in its directory:

### Required Scripts

1. **update.sh** - Update to a new version
   - Arguments: `VERSION` (e.g., "1.2.3")
   - Exit code 0 = success, non-zero = failure

2. **rollback.sh** - Rollback to previous version
   - No arguments
   - Exit code 0 = success, non-zero = failure

3. **health-check.sh** - Verify component is healthy
   - No arguments
   - Exit code 0 = healthy, non-zero = unhealthy

### Script Locations

```
/opt/dunebugger/update-coordinator/component-scripts/
├── core/
│   ├── update.sh
│   ├── rollback.sh
│   └── health-check.sh
├── scheduler/
│   ├── update.sh
│   ├── rollback.sh
│   └── health-check.sh
└── remote/
    ├── update.sh
    ├── rollback.sh
    └── health-check.sh
```

See `component-scripts/` directory for examples.

## Request/Status Protocol

### Request Format

Container writes JSON file to `/var/dunebugger/updates/requests/`:

```json
{
  "component": "remote",
  "action": "update",
  "version": "1.2.3",
  "request_id": "uuid-1234-5678",
  "timestamp": "2026-01-16T10:30:00Z"
}
```

**Fields:**
- `component`: One of "core", "scheduler", "remote"
- `action`: One of "update", "rollback", "health"
- `version`: Target version (required for "update" action)
- `request_id`: Unique identifier for tracking
- `timestamp`: ISO 8601 timestamp

### Status Format

Coordinator writes JSON file to `/var/dunebugger/updates/status/`:

```json
{
  "request_id": "uuid-1234-5678",
  "component": "remote",
  "action": "update",
  "success": true,
  "message": "Update completed successfully",
  "output": "stdout from script...",
  "error": "stderr from script...",
  "timestamp": "2026-01-16T10:31:00Z"
}
```

## Configuration

### Component Directories

Edit `COMPONENTS` dictionary in `update-coordinator.py`:

```python
COMPONENTS = {
    "core": "/opt/dunebugger/core",
    "scheduler": "/opt/dunebugger/scheduler",
    "remote": "/opt/dunebugger/remote"
}
```

### Timeouts

Script execution timeout is set to 10 minutes. Adjust in `execute_component_action()`:

```python
timeout=600  # 10 minutes
```

### Logging

Logs are written to:
- `/var/log/dunebugger/update-coordinator.log` (file)
- journald (systemd journal)

View logs:
```bash
# Real-time logs
sudo journalctl -u dunebugger-update-coordinator -f

# Last 100 lines
sudo journalctl -u dunebugger-update-coordinator -n 100

# File logs
sudo tail -f /var/log/dunebugger/update-coordinator.log
```

## Security Considerations

### Permissions

- Coordinator runs as `root` (required for Docker commands)
- Update directories are readable/writable by all (0755)
- Request files should be validated before processing
- Consider implementing request signing for production

### Resource Limits

Systemd service has resource limits:
- CPU: 20% quota
- Memory: 256MB limit

### Isolation

- Uses `PrivateTmp=yes` for temporary files
- Uses `ProtectHome=yes` to prevent home directory access
- Uses `ProtectSystem=full` for read-only system directories

## Troubleshooting

### Service won't start

```bash
# Check service status
sudo systemctl status dunebugger-update-coordinator

# View detailed logs
sudo journalctl -u dunebugger-update-coordinator -n 50

# Check if directories exist
ls -la /var/dunebugger/updates/
```

### Updates not processing

```bash
# Verify request file was created
ls -la /var/dunebugger/updates/requests/

# Check coordinator logs
sudo journalctl -u dunebugger-update-coordinator -f

# Verify component script exists and is executable
ls -la /opt/dunebugger/remote/update.sh
```

### Script execution fails

```bash
# Test script manually
sudo /opt/dunebugger/remote/update.sh 1.2.3

# Check script permissions
ls -la /opt/dunebugger/remote/*.sh

# View script output in logs
sudo tail -f /var/log/dunebugger/update-coordinator.log
```

## Maintenance

### Restart Service

```bash
sudo systemctl restart dunebugger-update-coordinator
```

### Stop Service

```bash
sudo systemctl stop dunebugger-update-coordinator
```

### Disable Service

```bash
sudo systemctl disable dunebugger-update-coordinator
```

### Uninstall

```bash
sudo systemctl stop dunebugger-update-coordinator
sudo systemctl disable dunebugger-update-coordinator
sudo rm /etc/systemd/system/dunebugger-update-coordinator.service
sudo rm -rf /opt/dunebugger/update-coordinator
sudo systemctl daemon-reload
```

## Development

### Testing Manually

Create a test request:

```bash
cat > /var/dunebugger/updates/requests/test-123.json << EOF
{
  "component": "remote",
  "action": "health",
  "request_id": "test-123",
  "timestamp": "$(date -Iseconds)"
}
EOF
```

Check status:

```bash
cat /var/dunebugger/updates/status/test-123.json
```

### Adding New Components

1. Add component to `COMPONENTS` dictionary in `update-coordinator.py`
2. Create component directory (e.g., `/opt/dunebugger/new-component/`)
3. Add required scripts (`update.sh`, `rollback.sh`, `health-check.sh`)
4. Restart coordinator: `sudo systemctl restart dunebugger-update-coordinator`

## License

See main project LICENSE file.
