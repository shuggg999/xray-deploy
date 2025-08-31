# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a dual-protocol Xray deployment script for secure internet access, supporting Reality+VLESS (port 443) and Shadowsocks (port 8388). The project is entirely written in Bash and designed for Ubuntu 18.04+, Debian 9+, and CentOS 7+ systems.

## Key Commands

### Running the Deployment Script
```bash
# Main interactive menu
sudo bash deploy.sh

# Quick installation
sudo bash install.sh
```

### Testing and Validation
```bash
# Check script syntax
bash -n deploy.sh
bash -n modules/*.sh

# Verify service status after installation
sudo systemctl status xray
sudo systemctl status nginx

# Check listening ports
sudo netstat -tulpn | grep -E ':(443|8388|80)'
```

## Architecture & Module Structure

The codebase follows a modular architecture where `deploy.sh` serves as the main orchestrator that sources and executes functions from specialized modules:

### Core Flow
1. **deploy.sh** - Entry point with interactive menu, sources modules dynamically
2. **modules/** - Each module handles a specific concern (install, backup, status, etc.)
3. **templates/** - Configuration templates with variable placeholders

### Module Responsibilities
- **modules/install.sh**: Handles all installation logic including dependency management, Xray download, key generation, and service configuration
- **modules/backup.sh**: Creates compressed timestamped backups, maintains rolling history
- **modules/restore.sh**: Restores configurations from backups
- **modules/status.sh**: Comprehensive monitoring and diagnostics
- **modules/docker.sh**: Docker proxy configuration guidance
- **modules/uninstall.sh**: Complete removal of services and configurations

### Configuration Template System
The project uses `templates/config.template.json` with placeholder variables:
- `{{UUID}}`: Generated client UUID
- `{{PRIVATE_KEY}}`: Reality protocol private key
- `{{SHORT_ID}}`: Reality short ID
- `{{SS_PASSWORD}}`: Shadowsocks password

These are replaced during installation using `sed` commands in modules/install.sh.

## Critical Implementation Details

### Key Generation Logic
- UUIDs are generated using `/proc/sys/kernel/random/uuid`
- Reality keys are generated via `xray x25519`
- Shadowsocks passwords use `openssl rand -base64 32`

### Service Configuration
- Xray config: `/usr/local/etc/xray/config.json`
- Client configs: `/root/*_config*.txt`
- Web-accessible configs: `/var/www/html/`

### Firewall Management
The script manages UFW (if available) or iptables directly, opening ports: 22, 80, 443, 8388

### Client Configuration Generation
The script generates multiple client configuration formats:
- Plain text connection strings
- Base64 encoded URIs for v2rayN/Nekoray
- QR codes for mobile clients
- Clash Verge YAML configurations

## Development Guidelines

When modifying this codebase:
1. Maintain the modular structure - new features should be separate modules
2. Use the existing color output functions (red(), green(), yellow(), blue())
3. Follow the error handling pattern: check command success and provide clear feedback
4. Test on Ubuntu 20.04/22.04 as primary targets
5. Preserve backward compatibility with existing backup files
6. Update VERSION file when making significant changes