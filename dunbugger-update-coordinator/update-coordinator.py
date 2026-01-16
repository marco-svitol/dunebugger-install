#!/usr/bin/env python3
"""
DuneBugger Update Coordinator
==============================

Lightweight host-side service that executes component update scripts.
Listens for update requests from dunebugger-remote container via shared volume.

Architecture:
    dunebugger-remote (container) --[writes JSON]--> /var/dunebugger/updates/requests/
                                                              ↓
                                                    update-coordinator.py
                                                              ↓
                                            [executes component scripts]
                                                              ↓
    dunebugger-remote (container) <--[reads JSON]-- /var/dunebugger/updates/status/

Request Format:
    {
        "component": "remote|scheduler|core",
        "action": "update|rollback|health",
        "version": "1.2.3",
        "request_id": "uuid",
        "timestamp": "2026-01-16T10:30:00Z"
    }

Response Format:
    {
        "request_id": "uuid",
        "success": true|false,
        "message": "Update completed successfully",
        "output": "command stdout",
        "error": "command stderr",
        "timestamp": "2026-01-16T10:31:00Z"
    }
"""

import os
import sys
import json
import time
import logging
import subprocess
import signal
from pathlib import Path
from datetime import datetime
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# Configuration
REQUEST_DIR = Path("/var/dunebugger/updates/requests")
STATUS_DIR = Path("/var/dunebugger/updates/status")
LOG_FILE = Path("/var/log/dunebugger/update-coordinator.log")

# Component script directories
COMPONENTS = {
    "core": "/opt/dunebugger/core",
    "scheduler": "/opt/dunebugger/scheduler",
    "remote": "/opt/dunebugger/remote"
}

# Valid actions
VALID_ACTIONS = ["update", "rollback", "health"]

# Global flag for graceful shutdown
shutdown_requested = False


class CoordinatorLogger:
    """Simple logger for coordinator"""
    
    def __init__(self, log_file: Path):
        self.log_file = log_file
        log_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Setup Python logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger('UpdateCoordinator')
    
    def info(self, msg):
        self.logger.info(msg)
    
    def error(self, msg):
        self.logger.error(msg)
    
    def warning(self, msg):
        self.logger.warning(msg)


logger = CoordinatorLogger(LOG_FILE)


class UpdateRequestHandler(FileSystemEventHandler):
    """Handles update request file events"""
    
    def on_created(self, event):
        """Handle new request file"""
        if event.is_directory:
            return
        
        if event.src_path.endswith('.json'):
            # Small delay to ensure file is fully written
            time.sleep(0.1)
            self.process_request(Path(event.src_path))
    
    def process_request(self, request_file: Path):
        """Process an update request"""
        logger.info(f"Processing request: {request_file.name}")
        
        try:
            # Read request
            with open(request_file, 'r') as f:
                request = json.load(f)
            
            # Validate request
            validation_error = self.validate_request(request)
            if validation_error:
                self.write_error_status(request, validation_error)
                request_file.unlink()  # Remove request file
                return
            
            # Execute action
            component = request['component']
            action = request['action']
            version = request.get('version', '')
            
            logger.info(f"Executing {action} for {component} (version: {version})")
            
            result = self.execute_component_action(component, action, version)
            
            # Write status
            self.write_status(request, result)
            
            # Remove processed request file
            request_file.unlink()
            logger.info(f"Request {request.get('request_id', 'unknown')} completed")
            
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON in request file: {e}")
            request_file.unlink()
        except Exception as e:
            logger.error(f"Error processing request: {e}")
            try:
                self.write_error_status(request, str(e))
                request_file.unlink()
            except:
                pass
    
    def validate_request(self, request: dict) -> str:
        """Validate request structure. Returns error message or empty string."""
        if 'component' not in request:
            return "Missing 'component' field"
        
        if 'action' not in request:
            return "Missing 'action' field"
        
        if request['component'] not in COMPONENTS:
            return f"Unknown component: {request['component']}"
        
        if request['action'] not in VALID_ACTIONS:
            return f"Invalid action: {request['action']}"
        
        # Check if component script directory exists
        component_dir = Path(COMPONENTS[request['component']])
        if not component_dir.exists():
            return f"Component directory not found: {component_dir}"
        
        # Check if action script exists
        script_name = f"{request['action']}.sh"
        script_path = component_dir / script_name
        if not script_path.exists():
            return f"Script not found: {script_path}"
        
        return ""
    
    def execute_component_action(self, component: str, action: str, version: str = "") -> dict:
        """Execute a component action script"""
        component_dir = Path(COMPONENTS[component])
        script_path = component_dir / f"{action}.sh"
        
        # Build command
        cmd = [str(script_path)]
        if version and action == 'update':
            cmd.append(version)
        
        logger.info(f"Executing: {' '.join(cmd)} in {component_dir}")
        
        try:
            # Execute script with timeout
            result = subprocess.run(
                cmd,
                cwd=component_dir,
                capture_output=True,
                text=True,
                timeout=600  # 10 minute timeout
            )
            
            success = result.returncode == 0
            
            return {
                "success": success,
                "returncode": result.returncode,
                "output": result.stdout,
                "error": result.stderr,
                "message": "Command completed successfully" if success else f"Command failed with code {result.returncode}"
            }
            
        except subprocess.TimeoutExpired:
            logger.error(f"Script timeout: {script_path}")
            return {
                "success": False,
                "returncode": -1,
                "output": "",
                "error": "Script execution timeout (10 minutes)",
                "message": "Script execution timeout"
            }
        except Exception as e:
            logger.error(f"Script execution error: {e}")
            return {
                "success": False,
                "returncode": -1,
                "output": "",
                "error": str(e),
                "message": f"Script execution error: {e}"
            }
    
    def write_status(self, request: dict, result: dict):
        """Write status response file"""
        request_id = request.get('request_id', 'unknown')
        status_file = STATUS_DIR / f"{request_id}.json"
        
        status = {
            "request_id": request_id,
            "component": request['component'],
            "action": request['action'],
            "success": result['success'],
            "message": result['message'],
            "output": result['output'],
            "error": result['error'],
            "timestamp": datetime.now().isoformat()
        }
        
        STATUS_DIR.mkdir(parents=True, exist_ok=True)
        
        with open(status_file, 'w') as f:
            json.dump(status, f, indent=2)
        
        logger.info(f"Status written: {status_file.name}")
    
    def write_error_status(self, request: dict, error_message: str):
        """Write error status when request is invalid"""
        request_id = request.get('request_id', 'unknown')
        status_file = STATUS_DIR / f"{request_id}.json"
        
        status = {
            "request_id": request_id,
            "component": request.get('component', 'unknown'),
            "action": request.get('action', 'unknown'),
            "success": False,
            "message": f"Request validation failed: {error_message}",
            "output": "",
            "error": error_message,
            "timestamp": datetime.now().isoformat()
        }
        
        STATUS_DIR.mkdir(parents=True, exist_ok=True)
        
        with open(status_file, 'w') as f:
            json.dump(status, f, indent=2)


def signal_handler(signum, frame):
    """Handle shutdown signals"""
    global shutdown_requested
    logger.info(f"Received signal {signum}, initiating graceful shutdown...")
    shutdown_requested = True


def setup_directories():
    """Ensure required directories exist"""
    REQUEST_DIR.mkdir(parents=True, exist_ok=True)
    STATUS_DIR.mkdir(parents=True, exist_ok=True)
    logger.info(f"Request directory: {REQUEST_DIR}")
    logger.info(f"Status directory: {STATUS_DIR}")


def main():
    """Main coordinator loop"""
    logger.info("=" * 70)
    logger.info("DuneBugger Update Coordinator Starting")
    logger.info("=" * 70)
    
    # Setup signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    # Setup directories
    setup_directories()
    
    # Log component configuration
    logger.info("Component directories:")
    for comp, path in COMPONENTS.items():
        exists = "✓" if Path(path).exists() else "✗"
        logger.info(f"  {comp}: {path} [{exists}]")
    
    # Create observer
    observer = Observer()
    event_handler = UpdateRequestHandler()
    observer.schedule(event_handler, str(REQUEST_DIR), recursive=False)
    
    logger.info(f"Watching for requests in: {REQUEST_DIR}")
    observer.start()
    
    try:
        while not shutdown_requested:
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received")
    finally:
        logger.info("Stopping observer...")
        observer.stop()
        observer.join()
        logger.info("Update coordinator stopped")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)
