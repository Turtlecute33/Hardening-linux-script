# Hardening Baseline Design — Expanded

**Date:** 2026-03-25

## Goal

Expand the existing safe baseline Linux hardening script with five new hardening features while preserving the interactive, prompt-per-feature approach. All new features are universally safe, behind prompts, and follow established patterns.

## Scope

### Existing (unchanged)
- Sysctl drop-in with kernel, network, and userspace hardening
- CUPS removal (prompted)
- Bluetooth disable (prompted)
- Support for Debian/Ubuntu, RHEL/Fedora, and Arch

### New Features

**1. Blacklist unused kernel modules (prompted, default yes)**
- Write `/etc/modprobe.d/hardening-blacklist.conf`
- Use `install <module> /bin/true` for: `cramfs`, `freevxfs`, `jffs2`, `hfs`, `hfsplus`, `udf`
- Standard CIS benchmark approach — prevents loading without reboot

**2. Disable USB storage (prompted, default no)**
- Add `install usb-storage /bin/true` to the module blacklist file
- **Write strategy**: Features 1 and 2 share `/etc/modprobe.d/hardening-blacklist.conf`. Both prompts are collected first. The file is written once, containing whichever modules were selected. If only feature 2 is chosen (no feature 1), the file contains only the USB line. If only feature 1, no USB line. If both, all lines. The file is always fully overwritten (never appended).
- Separate prompt because servers don't need USB but desktops might
- Default "no" to avoid surprising users who use USB drives

**3. Core dump restrictions (prompted, default yes)**
- Write `/etc/security/limits.d/99-hardening-no-coredump.conf` with `* hard core 0`
- Add `kernel.core_pattern=/dev/null` via a separate sysctl drop-in `/etc/sysctl.d/99-hardening-coredump.conf` (using `/dev/null` rather than `|/bin/false` to avoid kernel log spam on crash events)
- Detect systemd-coredump by checking `[[ -x /usr/lib/systemd/systemd-coredump ]]` (the binary is not in `$PATH`). If present, write `/etc/systemd/coredump.conf.d/hardening.conf` with `Storage=none` and `ProcessSizeMax=0`
- After writing, call `sysctl -p /etc/sysctl.d/99-hardening-coredump.conf` to apply the coredump sysctl immediately (does not rely on the earlier `apply_sysctl_settings` which may only reload the baseline drop-in in the fallback path)
- Prevents credential leakage from memory dumps

**4. Automatic security updates (prompted, default yes)**
- **Debian/Ubuntu**: install `unattended-upgrades` package, write `/etc/apt/apt.conf.d/20auto-upgrades` with:
  ```
  APT::Periodic::Update-Package-Lists "1";
  APT::Periodic::Unattended-Upgrade "1";
  ```
- **RHEL/Fedora**: install `dnf-automatic` package, edit `/etc/dnf/automatic.conf` to set `apply_updates = yes` (using `sed` to replace the existing `apply_updates` line), then enable `dnf-automatic.timer` via systemctl
- **Arch**: skip with informational message (rolling release, no safe auto-update mechanism)

**5. Fail2ban (prompted, default yes)**
- Install `fail2ban` via package manager
- Enable and start the service
- No custom jail config — defaults protect SSH and are safe out of the box

## Non-Goals

- No firewall configuration
- No SSH/sshd changes
- No aggressive network settings that break VPNs, containers, routing, or IPv6
- No Arch support for automatic updates

## Execution Order

```
1.  require_root
2.  require_systemctl
3.  detect_package_manager
4.  write_sysctl_dropin
5.  apply_sysctl_settings
6.  prompt: Remove CUPS?
7.  prompt: Disable Bluetooth?
8.  prompt: Blacklist unused kernel modules? → store answer
9.  prompt: Disable USB storage? → store answer
10. write_module_blacklist (using stored answers from 8+9)
11. prompt: Restrict core dumps?
12. prompt: Enable automatic security updates?
13. prompt: Install fail2ban?
14. print_summary
```

## Implementation Patterns

Each new feature follows the existing pattern:
- Dedicated function (e.g., `blacklist_kernel_modules()`)
- Called from `main()` behind `prompt_yes_no`
- Appends result to `SUMMARY[]` array
- Service operations use `|| true` to tolerate absent services. Note: `require_systemctl` at startup ensures systemctl itself is present — `|| true` guards against individual services being absent, not systemctl.

### File Ownership

| File | Owner |
|------|-------|
| `/etc/sysctl.d/99-hardening-baseline.conf` | Existing sysctl settings |
| `/etc/modprobe.d/hardening-blacklist.conf` | Module blacklist (features 1 + 2, written once) |
| `/etc/security/limits.d/99-hardening-no-coredump.conf` | Core dump limits (feature 3) |
| `/etc/sysctl.d/99-hardening-coredump.conf` | Core dump sysctl (feature 3) |
| `/etc/systemd/coredump.conf.d/hardening.conf` | Systemd coredump override (feature 3) |
| `/etc/apt/apt.conf.d/20auto-upgrades` | Debian auto-updates config (feature 4) |
| `/etc/dnf/automatic.conf` | RHEL auto-updates config — edited in place (feature 4) |

## Safety and Idempotency

- All config files are fully managed (overwritten on rerun, not appended), except `/etc/dnf/automatic.conf` which is edited in place via `sed`
- Atomic writes via temp file + `install` command
- Package installs are idempotent (already-installed packages are no-ops)
- Service operations tolerate absent services via `|| true`

## Test Updates

Tests use raw string matching against the script source (`assert_contains` / `assert_not_contains`). New assertions will:
- Check for new function names: `blacklist_kernel_modules`, `disable_usb_storage`, `restrict_core_dumps`, `setup_auto_updates`, `install_fail2ban`
- Check for key config paths: `/etc/modprobe.d/hardening-blacklist.conf`, `/etc/security/limits.d/`
- Check for key content strings: `cramfs`, `usb-storage`, `core 0`, `fail2ban`
- Maintain existing negative assertions (no ufw, no aggressive settings)

## Documentation Updates

- Update README to list the five new features
- Keep the "what it does not do" section unchanged
