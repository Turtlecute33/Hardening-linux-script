#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo or log in as the root user."
  exit 1
fi

# Function to add sysctl lines to a file
add_sysctl_lines() {
  local file="$1"
  local lines_to_add="$2"

  if [ -f "$file" ]; then
    # Check if each line exists and uncommented in the file
    for line in $lines_to_add; do
      if ! grep -q "^\s*#*${line}" "$file"; then
        echo "$line" >> "$file"
        added_lines="$added_lines\n$line"
      fi
    done
  else
    echo "File $file not found."
  fi
}

# Lines to add to sysctl configuration
lines_to_add="#kernel security
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.printk=3 3 3 3
kernel.unprivileged_bpf_disabled=1
net.core.bpf_jit_harden=2
dev.tty.ldisc_autoload=0
vm.unprivileged_userfaultfd=0
kernel.kexec_load_disabled=1
kernel.sysrq=4

#network security
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

#userspace security
kernel.yama.ptrace_scope=2
fs.protected_fifos=2
fs.protected_regular=2"

# Check for /etc/sysctl.conf and add lines
added_lines=""
add_sysctl_lines "/etc/sysctl.conf" "$lines_to_add"

# Check for /etc/sysctl.d and add lines
if [ -d "/etc/sysctl.d" ]; then
  for file in "/etc/sysctl.d/*"; do
    add_sysctl_lines "$file" "$lines_to_add"
  done
fi

# Print the message
if [ -n "$added_lines" ]; then
  echo "Added the following lines to sysctl configuration files:"
  echo -e "$added_lines"
else
  echo "No changes were made to sysctl configuration files."
fi

#!/bin/bash

# Function to configure UFW
configure_ufw() {
  echo "Configuring the firewall..."
  ufw enable
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow ssh
  ufw allow http
  ufw allow https
}

# Prompt the user for UFW configuration
while true; do
  read -p "Do you want to install and configure UFW (Uncomplicated Firewall)? Say no if this PC needs incoming connections such as VPN, Tor nodes, etc. (yes/no): " answer
  case $answer in
    [Yy]*)
      # Install UFW if it's not already installed
      if ! command -v ufw &> /dev/null; then
        echo "Installing UFW..."
        if [ -f /etc/debian_version ]; then
          apt-get install -y ufw
        elif [ -f /etc/redhat-release ]; then
          dnf install -y ufw
        elif [ -f /etc/arch-release ]; then
          pacman -S --noconfirm ufw
        else
          echo "Unsupported Linux distribution. Please install UFW manually."
        fi
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
if ! command -v systemctl &> /dev/null; then
  echo "Systemctl is not available on this system. Exiting."
  exit 1
fi

# Prompt the user to disable CUPS services
while true; do
  read -p "Do you want to disable the printer services (CUPS) to improve security? (yes/no): " answer
  case $answer in
    [Yy]*)
      # Disable CUPS services using systemctl
      systemctl stop cups.service
      systemctl disable cups.service
      systemctl stop cups-browsed.service
      systemctl disable cups-browsed.service
      echo "CUPS services have been disabled."
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
      # Disable Bluetooth services using systemctl
      systemctl stop bluetooth.service
      systemctl disable bluetooth.service
      echo "Bluetooth services have been disabled."
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
echo "System hardening completed. You should also remove all your unused packages, clean logs, and update your system. If you want, there is a script for doing this automatically on my GitHub."
