#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_path="${repo_dir}/hardening-script.sh"
readme_path="${repo_dir}/README.md"

assert_contains() {
  local haystack="$1"
  local needle="$2"

  [[ "$haystack" == *"$needle"* ]] || {
    echo "Expected to find: $needle"
    exit 1
  }
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"

  [[ "$haystack" != *"$needle"* ]] || {
    echo "Did not expect to find: $needle"
    exit 1
  }
}

script_source="$(<"$script_path")"
readme_source="$(<"$readme_path")"

assert_contains "$script_source" 'SYSCTL_DROPIN="/etc/sysctl.d/99-hardening-baseline.conf"'
assert_contains "$script_source" 'build_sysctl_content()'
assert_contains "$script_source" 'if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then'
assert_contains "$script_source" 'net.ipv4.tcp_syncookies=1'
assert_contains "$script_source" 'net.ipv4.icmp_echo_ignore_broadcasts=1'
assert_not_contains "$script_source" 'ufw'
assert_not_contains "$script_source" 'configure_ufw'
assert_not_contains "$script_source" 'net.ipv4.icmp_echo_ignore_all=1'
assert_not_contains "$script_source" 'net.ipv4.tcp_sack=0'
assert_not_contains "$script_source" 'net.ipv6.conf.default.accept_ra=0'
assert_not_contains "$script_source" 'kernel.kexec_load_disabled=1'

assert_contains "$readme_source" 'safe baseline'
assert_contains "$readme_source" 'does not configure a firewall'
assert_contains "$readme_source" 'does not touch SSH'
assert_contains "$readme_source" 'CUPS'
assert_contains "$readme_source" 'Bluetooth'
assert_not_contains "$readme_source" 'UFW'

# Feature: kernel module blacklisting
assert_contains "$script_source" 'blacklist_kernel_modules()'
assert_contains "$script_source" 'disable_usb_storage()'
assert_contains "$script_source" 'write_module_blacklist()'
assert_contains "$script_source" '/etc/modprobe.d/hardening-blacklist.conf'
assert_contains "$script_source" 'install cramfs /bin/true'
assert_contains "$script_source" 'install freevxfs /bin/true'
assert_contains "$script_source" 'install jffs2 /bin/true'
assert_contains "$script_source" 'install hfs /bin/true'
assert_contains "$script_source" 'install hfsplus /bin/true'
assert_contains "$script_source" 'install udf /bin/true'
assert_contains "$script_source" 'install usb-storage /bin/true'

# Feature: core dump restrictions
assert_contains "$script_source" 'restrict_core_dumps()'
assert_contains "$script_source" '/etc/security/limits.d/99-hardening-no-coredump.conf'
assert_contains "$script_source" 'kernel.core_pattern=/dev/null'
assert_contains "$script_source" '* hard core 0'

# Feature: automatic security updates
assert_contains "$script_source" 'setup_auto_updates()'
assert_contains "$script_source" 'unattended-upgrades'
assert_contains "$script_source" 'dnf-automatic'
assert_contains "$script_source" 'APT::Periodic::Unattended-Upgrade'
assert_contains "$script_source" '/etc/dnf/automatic.conf'

# Feature: fail2ban
assert_contains "$script_source" 'install_fail2ban()'
assert_contains "$script_source" 'fail2ban'

# README documents new features
assert_contains "$readme_source" 'kernel module'
assert_contains "$readme_source" 'USB storage'
assert_contains "$readme_source" 'core dump'
assert_contains "$readme_source" 'automatic security updates'
assert_contains "$readme_source" 'fail2ban'

echo "All tests passed."
