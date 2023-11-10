# Linux hardening script 🔒

![hardening Logo](https://turtlecute33.github.io/Turtlecute.org/images/hard.png)

## Description
This script is designed to simplify the process of hardening your Linux system. Running this bash you'll not became magically invincible but this script will guide you to improve your system security.

## Prerequisites
- You should run this script as a superuser (root) to ensure proper permissions.
  
## Usage
1. Clone the repository or download the script to your Linux system.
2. Make the script executable:
   ```bash
   chmod +x hardening.sh
3. Execute
   ```bash
   ./hardening.sh

# What the script does

The script will perform the following steps:

1. Check if the script is run as root to ensure proper permissions.
2. Check if your distro is using systemd.
3. improve kernel, network and user space security tweaking some values inside your systemd config.
4. Setup a basic firewall with UFW (optional).
5. Disable CUPS & Bluetooth services (optional).

Happy hardening! 🦾
