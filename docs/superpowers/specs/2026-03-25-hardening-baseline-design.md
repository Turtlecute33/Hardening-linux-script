# Hardening Baseline Design

**Date:** 2026-03-25

## Goal

Refocus the project from a mixed hardening-and-policy script into a broadly safe baseline Linux hardening script suitable for general-purpose servers. The script should improve kernel, network, and userspace security defaults without making opinionated choices about host-specific services such as firewalls or SSH access policies.

## Scope

- Remove all `ufw` installation and configuration logic.
- Do not modify `ssh` or `sshd` configuration.
- Automatically apply only broadly safe sysctl settings.
- Keep prompts for situational changes that can affect real user setups, specifically `CUPS` removal and Bluetooth disablement.
- Preserve support for Debian-family, Red Hat-family, and Arch-based systems.

## Non-Goals

- Managing firewall policy.
- Enforcing SSH authentication policy.
- Applying aggressive network settings that can break routing, VPNs, containers, or IPv6 autoconfiguration.
- Claiming to provide full hardening for every deployment profile.

## Baseline Sysctl Profile

The script should manage a dedicated drop-in file at `/etc/sysctl.d/99-hardening-baseline.conf` with a clear generated-file header. The file should contain only settings owned by this project, making the script idempotent and easy to reason about on reruns.

### Settings to Apply Automatically

Kernel and userspace:

- `kernel.kptr_restrict=2`
- `kernel.dmesg_restrict=1`
- `kernel.unprivileged_bpf_disabled=1`
- `vm.unprivileged_userfaultfd=0`
- `kernel.yama.ptrace_scope=1`
- `fs.protected_hardlinks=1`
- `fs.protected_symlinks=1`
- `fs.protected_fifos=2`
- `fs.protected_regular=2`
- `fs.suid_dumpable=0`

Network:

- `net.ipv4.tcp_syncookies=1`
- `net.ipv4.tcp_rfc1337=1`
- `net.ipv4.icmp_echo_ignore_broadcasts=1`
- `net.ipv4.icmp_ignore_bogus_error_responses=1`
- `net.ipv4.conf.all.accept_redirects=0`
- `net.ipv4.conf.default.accept_redirects=0`
- `net.ipv4.conf.all.secure_redirects=0`
- `net.ipv4.conf.default.secure_redirects=0`
- `net.ipv4.conf.all.send_redirects=0`
- `net.ipv4.conf.default.send_redirects=0`
- `net.ipv4.conf.all.accept_source_route=0`
- `net.ipv4.conf.default.accept_source_route=0`
- `net.ipv6.conf.all.accept_redirects=0`
- `net.ipv6.conf.default.accept_redirects=0`
- `net.ipv6.conf.all.accept_source_route=0`
- `net.ipv6.conf.default.accept_source_route=0`
- `net.ipv4.conf.all.log_martians=1`
- `net.ipv4.conf.default.log_martians=1`

### Settings Explicitly Excluded

The following existing or plausible settings are intentionally excluded from the general baseline because they are too disruptive or too role-specific:

- `net.ipv4.icmp_echo_ignore_all=1`
- `net.ipv4.tcp_sack=0`
- `net.ipv4.tcp_dsack=0`
- `net.ipv4.tcp_fack=0`
- `net.ipv6.conf.*.accept_ra=0`
- `net.ipv4.conf.*.rp_filter=1`
- `kernel.kexec_load_disabled=1`
- Any `ufw`, `ssh`, or `sshd` changes

## Execution Flow

1. Verify the script is running as root.
2. Verify `systemctl` is available before attempting service operations.
3. Detect the supported package manager.
4. Write the managed sysctl drop-in file atomically.
5. Reload sysctl settings using `sysctl --system` when available, with a fallback to `sysctl -p` on the managed file.
6. Prompt the user about removing `CUPS`.
7. Prompt the user about disabling Bluetooth.
8. Print a concise summary of what was applied and what was skipped.

## Safety and Idempotency

- The sysctl configuration should be fully managed by this project in one file to avoid duplicate appends into `/etc/sysctl.conf`.
- Optional package removals and service shutdowns should be resilient when the target packages or services are absent.
- Unsupported distributions should fail clearly and early.
- Prompts remain only for optional steps that can impact user workflows or hardware usage.

## Documentation

The README should be updated to reflect the new baseline positioning:

- Describe the script as a safe baseline hardening script.
- State explicitly that it does not configure firewalls or SSH.
- List the categories of changes it applies automatically.
- Note that `CUPS` and Bluetooth remain optional prompts.
