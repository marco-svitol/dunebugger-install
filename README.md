
# Dunebugger Installer

This repository contains the installation automation for the entire Dunebugger system.  
Its purpose is to provide a single entry point for deploying all components — core, dispatcher (remote), terminal, captive portal — on a Raspberry Pi.

The installer fetches all required stages directly from their respective GitHub repositories, applies configurations, and prepares the environment automatically.  
It is designed to be idempotent, lightweight, and easy to run even on a fresh Raspberry Pi OS installation.

## Prerequisites

1. Install Raspberry Pi OS (Lite recommended) on your Raspberry Pi.
2. Ensure Python 3.10+ is installed.
3. Ensure `git` is installed.
4. Raspberry Pi must have network access to the websocket hub.
5. Optional: Install `mqueue` if running in local-only mode.

## How to Run the Installer

### Copy the wrapper script to your RPi:
```
curl -fsSL https://raw.githubusercontent.com/ilciclaio/dunebugger-install/main/install-dunebugger.sh -o install-dunebugger.sh
chmod +x install-dunebugger.sh
```
### Run it:
```
bash install-dunebugger.sh
```