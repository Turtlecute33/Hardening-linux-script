# Expanded Hardening Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add five new hardening features (kernel module blacklisting, USB storage disable, core dump restrictions, automatic security updates, fail2ban) to the existing baseline hardening script.

**Architecture:** Each feature is a self-contained function following the existing pattern: function → prompt gate in `main()` → append to `SUMMARY[]`. Features 1+2 share a blacklist file written once after both prompts. All config files are fully managed (overwritten, not appended). Tests use raw string matching against script source.

**Tech Stack:** Bash, sysctl, modprobe, systemd, apt/dnf/pacman, fail2ban

**Spec:** `docs/superpowers/specs/2026-03-25-hardening-baseline-design.md`

---

### File Structure

**Files:**
- Modify: `hardening-script.sh` — add 5 new feature functions + update `main()`
- Modify: `tests/test_hardening_script.sh` — add assertions for new features
- Modify: `README.md` — document new features

---

### Task 1: Kernel module blacklisting + USB storage disable

These two features share `/etc/modprobe.d/hardening-blacklist.conf` and must be implemented together. The file is written once after both prompts are answered.

**Files:**
- Modify: `hardening-script.sh:179` (before `print_summary`, after `disable_bluetooth`)
- Modify: `tests/test_hardening_script.sh`

- [ ] **Step 1: Write the failing test**

Add to `tests/test_hardening_script.sh` before the final `echo "All tests passed."` line:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_hardening_script.sh`
Expected: FAIL — `write_module_blacklist()` not found in script source

- [ ] **Step 3: Write minimal implementation**

Add these constants and functions to `hardening-script.sh` after the `SYSCTL_DROPIN` line (around line 5):

```bash
MODPROBE_BLACKLIST="/etc/modprobe.d/hardening-blacklist.conf"
```

Add this function before `print_summary()` (around line 179):

```bash
write_module_blacklist() {
  local blacklist_modules="$1"
  local blacklist_usb="$2"
  local temp_file
  local content=""

  if [[ "$blacklist_modules" == "no" && "$blacklist_usb" == "no" ]]; then
    return
  fi

  temp_file="$(mktemp)"

  {
    echo "## Managed by ${SCRIPT_NAME}"
    echo "## File: ${MODPROBE_BLACKLIST}"
    if [[ "$blacklist_modules" == "yes" ]]; then
      echo ""
      echo "## Disable unused filesystem modules"
      echo "install cramfs /bin/true"
      echo "install freevxfs /bin/true"
      echo "install jffs2 /bin/true"
      echo "install hfs /bin/true"
      echo "install hfsplus /bin/true"
      echo "install udf /bin/true"
    fi
    if [[ "$blacklist_usb" == "yes" ]]; then
      echo ""
      echo "## Disable USB storage"
      echo "install usb-storage /bin/true"
    fi
  } > "$temp_file"

  mkdir -p "$(dirname "$MODPROBE_BLACKLIST")"
  install -m 0644 "$temp_file" "$MODPROBE_BLACKLIST"
  rm -f "$temp_file"

  if [[ "$blacklist_modules" == "yes" ]]; then
    SUMMARY+=("Blacklisted unused kernel modules (cramfs, freevxfs, jffs2, hfs, hfsplus, udf).")
  fi
  if [[ "$blacklist_usb" == "yes" ]]; then
    SUMMARY+=("Blacklisted USB storage module.")
  fi
}
```

Add wrapper functions that `main()` calls (these exist so the function names match the feature names and are discoverable in tests):

```bash
blacklist_kernel_modules() {
  write_module_blacklist "yes" "${1:-no}"
}

disable_usb_storage() {
  write_module_blacklist "${1:-no}" "yes"
}
```

Update `main()` — add after the Bluetooth prompt block:

```bash
  local do_blacklist_modules="no"
  local do_blacklist_usb="no"

  if prompt_yes_no "Do you want to blacklist unused kernel modules (cramfs, freevxfs, jffs2, hfs, hfsplus, udf)?" "yes"; then
    do_blacklist_modules="yes"
  else
    SUMMARY+=("Skipped kernel module blacklisting.")
  fi

  if prompt_yes_no "Do you want to disable USB storage?" "no"; then
    do_blacklist_usb="yes"
  else
    SUMMARY+=("Skipped USB storage disable.")
  fi

  write_module_blacklist "$do_blacklist_modules" "$do_blacklist_usb"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_hardening_script.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hardening-script.sh tests/test_hardening_script.sh
git commit -m "feat: add kernel module blacklisting and USB storage disable"
```

---

### Task 2: Core dump restrictions

**Files:**
- Modify: `hardening-script.sh`
- Modify: `tests/test_hardening_script.sh`

- [ ] **Step 1: Write the failing test**

Add to `tests/test_hardening_script.sh` before the final echo:

```bash
# Feature: core dump restrictions
assert_contains "$script_source" 'restrict_core_dumps()'
assert_contains "$script_source" '/etc/security/limits.d/99-hardening-no-coredump.conf'
assert_contains "$script_source" 'kernel.core_pattern=/dev/null'
assert_contains "$script_source" '* hard core 0'
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_hardening_script.sh`
Expected: FAIL — `restrict_core_dumps()` not found

- [ ] **Step 3: Write minimal implementation**

Add constants near the top of the script:

```bash
COREDUMP_LIMITS="/etc/security/limits.d/99-hardening-no-coredump.conf"
COREDUMP_SYSCTL="/etc/sysctl.d/99-hardening-coredump.conf"
COREDUMP_SYSTEMD="/etc/systemd/coredump.conf.d/hardening.conf"
```

Add function before `print_summary()`:

```bash
restrict_core_dumps() {
  local temp_file

  echo "Restricting core dumps..."

  # limits.conf
  temp_file="$(mktemp)"
  cat > "$temp_file" <<'EOF'
## Managed by Turtlecute33/Hardening-linux-script
* hard core 0
EOF
  mkdir -p "$(dirname "$COREDUMP_LIMITS")"
  install -m 0644 "$temp_file" "$COREDUMP_LIMITS"
  rm -f "$temp_file"

  # sysctl
  temp_file="$(mktemp)"
  cat > "$temp_file" <<'EOF'
## Managed by Turtlecute33/Hardening-linux-script
## Core dump restrictions
kernel.core_pattern=/dev/null
EOF
  mkdir -p "$(dirname "$COREDUMP_SYSCTL")"
  install -m 0644 "$temp_file" "$COREDUMP_SYSCTL"
  rm -f "$temp_file"

  if command -v sysctl >/dev/null 2>&1; then
    sysctl -p "$COREDUMP_SYSCTL" >/dev/null 2>&1 || true
  fi

  # systemd-coredump override (binary lives at /usr/lib/systemd/, not in PATH)
  if [[ -x /usr/lib/systemd/systemd-coredump ]]; then
    temp_file="$(mktemp)"
    cat > "$temp_file" <<'EOF'
[Coredump]
Storage=none
ProcessSizeMax=0
EOF
    mkdir -p "$(dirname "$COREDUMP_SYSTEMD")"
    install -m 0644 "$temp_file" "$COREDUMP_SYSTEMD"
    rm -f "$temp_file"
    SUMMARY+=("Restricted core dumps (limits.conf, sysctl, systemd-coredump).")
  else
    SUMMARY+=("Restricted core dumps (limits.conf, sysctl).")
  fi
}
```

Add to `main()` after the module blacklist block:

```bash
  if prompt_yes_no "Do you want to restrict core dumps?" "yes"; then
    restrict_core_dumps
  else
    SUMMARY+=("Skipped core dump restrictions.")
  fi
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_hardening_script.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hardening-script.sh tests/test_hardening_script.sh
git commit -m "feat: add core dump restrictions"
```

---

### Task 3: Automatic security updates

**Files:**
- Modify: `hardening-script.sh`
- Modify: `tests/test_hardening_script.sh`

- [ ] **Step 1: Write the failing test**

Add to `tests/test_hardening_script.sh` before the final echo:

```bash
# Feature: automatic security updates
assert_contains "$script_source" 'setup_auto_updates()'
assert_contains "$script_source" 'unattended-upgrades'
assert_contains "$script_source" 'dnf-automatic'
assert_contains "$script_source" 'APT::Periodic::Unattended-Upgrade'
assert_contains "$script_source" '/etc/dnf/automatic.conf'
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_hardening_script.sh`
Expected: FAIL — `setup_auto_updates()` not found

- [ ] **Step 3: Write minimal implementation**

Add function before `print_summary()`:

```bash
setup_auto_updates() {
  local temp_file

  echo "Setting up automatic security updates..."

  case "$PM_FAMILY" in
    apt)
      apt-get install -y unattended-upgrades >/dev/null 2>&1
      temp_file="$(mktemp)"
      cat > "$temp_file" <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
      install -m 0644 "$temp_file" /etc/apt/apt.conf.d/20auto-upgrades
      rm -f "$temp_file"
      SUMMARY+=("Installed and configured unattended-upgrades.")
      ;;
    dnf)
      dnf install -y dnf-automatic >/dev/null 2>&1
      if [[ -f /etc/dnf/automatic.conf ]]; then
        sed -i 's/^apply_updates.*=.*/apply_updates = yes/' /etc/dnf/automatic.conf
      fi
      systemctl enable dnf-automatic.timer 2>/dev/null || true
      systemctl start dnf-automatic.timer 2>/dev/null || true
      SUMMARY+=("Installed and enabled dnf-automatic with apply_updates = yes.")
      ;;
    pacman)
      echo "Note: Automatic updates are not recommended on Arch Linux (rolling release)."
      echo "Please manage updates manually with: pacman -Syu"
      SUMMARY+=("Skipped automatic updates (Arch Linux — not recommended).")
      ;;
  esac
}
```

Add to `main()` after the core dump block:

```bash
  if prompt_yes_no "Do you want to enable automatic security updates?" "yes"; then
    setup_auto_updates
  else
    SUMMARY+=("Skipped automatic security updates.")
  fi
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_hardening_script.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hardening-script.sh tests/test_hardening_script.sh
git commit -m "feat: add automatic security updates"
```

---

### Task 4: Fail2ban installation

**Files:**
- Modify: `hardening-script.sh`
- Modify: `tests/test_hardening_script.sh`

- [ ] **Step 1: Write the failing test**

Add to `tests/test_hardening_script.sh` before the final echo:

```bash
# Feature: fail2ban
assert_contains "$script_source" 'install_fail2ban()'
assert_contains "$script_source" 'fail2ban'
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_hardening_script.sh`
Expected: FAIL — `install_fail2ban()` not found

- [ ] **Step 3: Write minimal implementation**

Add function before `print_summary()`:

```bash
install_fail2ban() {
  echo "Installing and enabling fail2ban..."

  case "$PM_FAMILY" in
    apt)
      apt-get install -y fail2ban >/dev/null 2>&1
      ;;
    dnf)
      dnf install -y fail2ban >/dev/null 2>&1
      ;;
    pacman)
      pacman -S --noconfirm fail2ban >/dev/null 2>&1
      ;;
  esac

  systemctl enable fail2ban.service 2>/dev/null || true
  systemctl start fail2ban.service 2>/dev/null || true

  SUMMARY+=("Installed and enabled fail2ban.")
}
```

Add to `main()` after the auto-updates block:

```bash
  if prompt_yes_no "Do you want to install fail2ban for brute-force protection?" "yes"; then
    install_fail2ban
  else
    SUMMARY+=("Skipped fail2ban installation.")
  fi
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_hardening_script.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hardening-script.sh tests/test_hardening_script.sh
git commit -m "feat: add fail2ban installation"
```

---

### Task 5: Update README

**Files:**
- Modify: `README.md`
- Modify: `tests/test_hardening_script.sh`

- [ ] **Step 1: Write the failing test**

Add to `tests/test_hardening_script.sh` before the final echo:

```bash
# README documents new features
assert_contains "$readme_source" 'kernel module'
assert_contains "$readme_source" 'USB storage'
assert_contains "$readme_source" 'core dump'
assert_contains "$readme_source" 'automatic security updates'
assert_contains "$readme_source" 'fail2ban'
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_hardening_script.sh`
Expected: FAIL — README doesn't mention new features yet

- [ ] **Step 3: Write minimal implementation**

Update the "What the script does" section in `README.md` to add after item 4:

```markdown
5. Prompting before blacklisting unused kernel modules (cramfs, freevxfs, jffs2, hfs, hfsplus, udf).
6. Prompting before disabling USB storage.
7. Prompting before restricting core dumps.
8. Prompting before enabling automatic security updates (Debian/Ubuntu, RHEL/Fedora only).
9. Prompting before installing fail2ban for brute-force protection.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_hardening_script.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add README.md tests/test_hardening_script.sh
git commit -m "docs: document new hardening features in README"
```

---

### Task 6: Final verification

**Files:**
- All modified files

- [ ] **Step 1: Run the full test suite**

Run: `bash tests/test_hardening_script.sh`
Expected: `All tests passed.`

- [ ] **Step 2: Run syntax check**

Run: `bash -n hardening-script.sh`
Expected: No output (clean parse)

- [ ] **Step 3: Verify no policy regressions**

Run: `git diff main -- hardening-script.sh | head -200`
Verify: no `ufw`, no `sshd`, no aggressive network settings (`icmp_echo_ignore_all`, `tcp_sack=0`, `accept_ra=0`, `kexec_load_disabled`)

- [ ] **Step 4: Review script structure**

Read `hardening-script.sh` end-to-end and verify:
- All 5 new features are present as functions
- All are gated behind `prompt_yes_no` in `main()`
- Module blacklist features share a single file write
- `SUMMARY` array captures all outcomes
