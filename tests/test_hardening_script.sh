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

echo "All tests passed."
