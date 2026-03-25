# Hardening Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the script into a safe baseline Linux hardening tool that removes `ufw`, avoids SSH changes, manages an idempotent sysctl drop-in, and keeps only situational prompts for `CUPS` and Bluetooth.

**Architecture:** Refactor the shell script into small functions with a `main` entrypoint guard so it can be sourced by tests. Manage all baseline sysctl settings in one generated file under `/etc/sysctl.d`, reload them safely, and preserve optional service/package prompts for disruptive changes only.

**Tech Stack:** Bash, standard Linux userland tools, lightweight shell tests, Markdown documentation

---

### File Structure

**Files:**
- Modify: `hardening-script.sh`
- Modify: `README.md`
- Create: `tests/test_hardening_script.sh`

### Task 1: Add a failing shell test harness

**Files:**
- Create: `tests/test_hardening_script.sh`
- Modify: `hardening-script.sh`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${script_dir}/hardening-script.sh"

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

content="$(build_sysctl_content)"
assert_contains "$content" "net.ipv4.tcp_syncookies=1"
assert_not_contains "$content" "net.ipv4.icmp_echo_ignore_all=1"
assert_not_contains "$content" "net.ipv4.tcp_sack=0"

script_source="$(<"${script_dir}/hardening-script.sh")"
assert_not_contains "$script_source" "configure_ufw"
assert_not_contains "$script_source" "ufw"
assert_not_contains "$script_source" "sshd"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_hardening_script.sh`
Expected: FAIL because `build_sysctl_content` and the guarded source-friendly structure do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```bash
build_sysctl_content() {
  cat <<'EOF'
...
EOF
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_hardening_script.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/test_hardening_script.sh hardening-script.sh
git commit -m "test: add hardening script baseline checks"
```

### Task 2: Refactor the script to a safe baseline implementation

**Files:**
- Modify: `hardening-script.sh`
- Test: `tests/test_hardening_script.sh`

- [ ] **Step 1: Write the failing test**

Add expectations covering:
- sysctl output includes the full approved baseline set
- the script defines a managed file path under `/etc/sysctl.d/99-hardening-baseline.conf`
- the script exposes no `ufw`, `ssh`, or `sshd` handling

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_hardening_script.sh`
Expected: FAIL on missing baseline lines and managed-file behavior.

- [ ] **Step 3: Write minimal implementation**

Implement:
- `require_root`
- `require_systemctl`
- `detect_package_manager`
- `prompt_yes_no`
- `build_sysctl_content`
- `write_sysctl_dropin`
- `apply_sysctl_settings`
- optional `CUPS` and Bluetooth helpers
- `main`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_hardening_script.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add hardening-script.sh tests/test_hardening_script.sh
git commit -m "feat: convert script to safe baseline hardening"
```

### Task 3: Update the README to match the new behavior

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Write the failing test**

Add assertions to `tests/test_hardening_script.sh` or a second lightweight doc check verifying the README now mentions:
- safe baseline hardening
- no firewall management
- no SSH or `sshd` changes
- optional `CUPS` and Bluetooth prompts

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_hardening_script.sh`
Expected: FAIL because the existing README still documents `ufw`.

- [ ] **Step 3: Write minimal implementation**

Update the README text to match the approved scope and execution flow.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_hardening_script.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add README.md tests/test_hardening_script.sh
git commit -m "docs: update hardening baseline behavior"
```

### Task 4: Verify the complete change

**Files:**
- Modify: `hardening-script.sh`
- Modify: `README.md`
- Modify: `tests/test_hardening_script.sh`

- [ ] **Step 1: Run the shell test suite**

Run: `bash tests/test_hardening_script.sh`
Expected: PASS

- [ ] **Step 2: Run a syntax check**

Run: `bash -n hardening-script.sh`
Expected: PASS with no output

- [ ] **Step 3: Inspect the diff for policy regressions**

Run: `git diff -- hardening-script.sh README.md tests/test_hardening_script.sh`
Expected: no `ufw`, `ssh`, or `sshd` management present

- [ ] **Step 4: Commit**

```bash
git add hardening-script.sh README.md tests/test_hardening_script.sh
git commit -m "chore: verify hardening baseline update"
```
