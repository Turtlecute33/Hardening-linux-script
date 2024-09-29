#!/usr/bin/env bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo or log in as the root user."
  exit 1
fi

# Function to detect package manager and set commands
detect_package_manager() {
  if [ -f /etc/debian_version ]; then
    PM_INSTALL="apt-get install -y"
    PM_REMOVE="apt-get purge -y"
    PM_LIST="dpkg -l"
  elif [ -f /etc/redhat-release ]; then
    PM_INSTALL="dnf install -y"
    PM_REMOVE="dnf remove -y"
    PM_LIST="rpm -qa"
  elif [ -f /etc/arch-release ]; then
    PM_INSTALL="pacman -S --noconfirm"
    PM_REMOVE="pacman -Rns --noconfirm"
    PM_LIST="pacman -Qq"
  else
    echo "Unsupported Linux distribution. Please install packages manually."
    exit 1
  fi
}

# Function to add sysctl lines
add_sysctl_lines() {
  local file="$1"
  local lines="$2"
  local added_lines=""

  if [ -f "$file" ]; then
    while IFS= read -r line; do
      line=$(echo "$line" | sed 's/^\s*#\s*//')  # Remove leading '#' and whitespace
      if ! grep -Eq "^\s*${line//./\\.}" "$file"; then
        echo "$line" >> "$file"
        added_lines="${added_lines}\n$line"
      fi
    done <<< "$lines"
  else
    echo "File $file not found."
  fi

  echo -e "$added_lines"
}

# Function to configure UFW
configure_ufw() {
  echo "Configuring the firewall..."
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow ssh
  ufw allow http
  ufw allow https
  ufw --force enable
}

# Function to remove CUPS packages
remove_cups_packages() {
  echo "Removing CUPS packages..."
  local cups_packages
  local package_count=0

  case "$PM_REMOVE" in
    *apt-get*)
      cups_packages=$(dpkg -l | grep 'cups' | awk '{print $2}')
      if [ -n "$cups_packages" ]; then
        package_count=$(echo "$cups_packages" | wc -l)
        apt-get purge -y $cups_packages >/dev/null 2>&1
      fi
      ;;
    *dnf*)
      cups_packages=$(dnf list installed | grep 'cups' | awk '{print $1}')
      if [ -n "$cups_packages" ]; then
        package_count=$(echo "$cups_packages" | wc -l)
        dnf remove -y $cups_packages >/dev/null 2>&1
      fi
      ;;
    *pacman*)
      cups_packages=$(pacman -Qq | grep 'cups')
      if [ -n "$cups_packages" ]; then
        package_count=$(echo "$cups_packages" | wc -l)
        pacman -Rns --noconfirm $cups_packages >/dev/null 2>&1
      fi
      ;;
    *)
      echo "Package manager not supported for removing CUPS."
      ;;
  esac

  systemctl stop cups.service cups-browsed.service 2>/dev/null
  systemctl disable cups.service cups-browsed.service 2>/dev/null

  if [ "$package_count" -gt 0 ]; then
    echo "Removed $package_count CUPS packages and disabled CUPS services."
  else
    echo "No CUPS packages were found to remove."
  fi
}

# Function to disable Bluetooth services
disable_bluetooth() {
  echo "Disabling Bluetooth services..."
  systemctl stop bluetooth.service 2>/dev/null
  systemctl disable bluetooth.service 2>/dev/null
  echo "Bluetooth services have been disabled."
}

# Main script execution starts here
detect_package_manager

# Lines to add to sysctl configuration
sysctl_lines="
#################################################################### 
## Security configs from Turtlecute33/Hardening-linux-script
## Source: https://github.com/Turtlecute33/Hardening-linux-script

## Kernel security
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.printk=3 3 3 3
kernel.unprivileged_bpf_disabled=1
net.core.bpf_jit_harden=2
dev.tty.ldisc_autoload=0
vm.unprivileged_userfaultfd=0
kernel.kexec_load_disabled=1
kernel.sysrq=4

## Network security
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_rfc1337=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_ra=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.icmp_echo_ignore_all=1
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.default.accept_ra=0
net.ipv4.tcp_sack=0
net.ipv4.tcp_dsack=0
net.ipv4.tcp_fack=0

## Userspace security
kernel.yama.ptrace_scope=2
fs.protected_fifos=2
fs.protected_regular=2

## End of security configs from Turtlecute33/Hardening-linux-script
"

# Apply sysctl settings
added_lines=$(add_sysctl_lines "/etc/sysctl.conf" "$sysctl_lines")
if [ -n "$added_lines" ]; then
  echo "Added the following lines to /etc/sysctl.conf:"
  echo -e "$added_lines"
else
  echo "No changes were made to /etc/sysctl.conf."
fi

# Reload sysctl settings
sysctl -p >/dev/null 2>&1

# Prompt the user for UFW configuration
while true; do
  read -p "Do you want to install and configure UFW (Uncomplicated Firewall)? (yes/no): " answer
  case $answer in
    [Yy]*)
      # Install UFW if it's not already installed
      if ! command -v ufw &>/dev/null; then
        echo "Installing UFW..."
        $PM_INSTALL ufw >/dev/null 2>&1
      fi
      configure_ufw
      break
      ;;
    [Nn]*)
      echo "UFW installation and configuration skipped."
      break
      ;;
    *)
      echo "Please enter 'yes' or 'no'."
      ;;
  esac
done

# Check if systemctl is available
if ! command -v systemctl &>/dev/null; then
  echo "Systemctl is not available on this system. Exiting."
  exit 1
fi

# Prompt the user to remove CUPS services
while true; do
  read -p "Do you want to remove all printer services (CUPS) to improve security? (yes/no): " answer
  case $answer in
    [Yy]*)
      remove_cups_packages
      break
      ;;
    [Nn]*)
      echo "CUPS services remain enabled."
      break
      ;;
    *)
      echo "Please enter 'yes' or 'no'."
      ;;
  esac
done

# Prompt the user to disable Bluetooth services
while true; do
  read -p "Do you want to disable Bluetooth services to improve security? (yes/no): " answer
  case $answer in
    [Yy]*)
      disable_bluetooth
      break
      ;;
    [Nn]*)
      echo "Bluetooth services remain enabled."
      break
      ;;
    *)
      echo "Please enter 'yes' or 'no'."
      ;;
  esac
done

echo "System hardening completed. Consider removing unused packages, cleaning logs, and updating your system."
