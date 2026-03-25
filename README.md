# Linux hardening script

![hardening Logo](https://turtlecute33.github.io/Turtlecute.org/images/Linux-Hardening-Security-1600x900.webp)

## Description

This project provides a safe baseline hardening script for Linux servers. It is meant to improve common kernel, network, and userspace defaults without pretending to replace a real security review or a host-specific operations policy.

The script does not configure a firewall and does not touch SSH. Those choices are intentionally left to the server owner because they are too dependent on the workload and access model.

## Prerequisites

- Run the script as `root`.
- Use a Linux system with `systemd`.
- Supported distro families: Debian/Ubuntu, Red Hat family, and Arch.

## Usage

1. Clone the repository or download the script.
2. Make the script executable:

```bash
chmod +x hardening-script.sh
```

3. Run it as root:

```bash
sudo ./hardening-script.sh
```

## What the script does

The script applies a safe baseline by:

1. Writing a managed sysctl drop-in under `/etc/sysctl.d/99-hardening-baseline.conf`.
2. Applying broadly safe kernel, network, and userspace hardening settings.
3. Prompting before optional changes such as removing `CUPS`.
4. Prompting before optional changes such as disabling Bluetooth.
5. Prompting before blacklisting unused kernel modules (cramfs, freevxfs, jffs2, hfs, hfsplus, udf).
6. Prompting before disabling USB storage.
7. Prompting before restricting core dumps.
8. Prompting before enabling automatic security updates (Debian/Ubuntu, RHEL/Fedora only).
9. Prompting before installing fail2ban for brute-force protection.

## What the script does not do

- It does not configure a firewall.
- It does not touch SSH or `sshd`.
- It does not apply aggressive network hardening that can break VPNs, containers, routing, or IPv6 autoconfiguration.

## Notes

This is a general baseline meant to be usable on home servers, P2P servers, Bitcoin nodes, and production systems. You should still review the resulting configuration against your actual workload and threat model.
