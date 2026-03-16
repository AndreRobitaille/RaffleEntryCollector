# Kiosk Setup Script and Deployment Config — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the idempotent kiosk setup script and all deployment configuration files for the Raspberry Pi 4.

**Architecture:** Three-user model (kiosk/raffle/andre) with systemd services, udev USB auto-mount, Wayfire compositor lockdown, and Chromium kiosk mode. All config files live in the repo under `config/systemd/` and `config/kiosk/`; the setup script copies them to system locations.

**Tech Stack:** Bash (setup script), systemd (services/timers), udev (USB mount), Wayfire (compositor), Chromium (kiosk browser)

**Spec:** `docs/superpowers/specs/2026-03-15-kiosk-setup-design.md`

---

## File Structure

| File | Responsibility |
|------|---------------|
| `config/systemd/raffle-kiosk.service` | systemd unit: runs Puma as `raffle` user with hardening |
| `config/systemd/raffle-backup.service` | systemd unit: runs USB backup as `raffle` user |
| `config/systemd/raffle-backup.timer` | systemd timer: triggers backup every 5 minutes |
| `config/kiosk/chromium-kiosk.sh` | Chromium launcher with health-check loop and crash recovery |
| `config/kiosk/wayfire.ini` | Wayfire config: disable shortcuts, autostart Chromium |
| `config/kiosk/bash_profile` | Kiosk user login profile: starts Wayfire on tty1 |
| `config/kiosk/99-raffle-backup.rules` | udev rule: auto-mount RAFFLE_BACKUP drives |
| `config/kiosk/raffle-usb-mount` | udev helper: mount/unmount FAT32 USB drives |
| `bin/setup_kiosk` | Main idempotent setup script tying everything together |
| `bin/backup_to_usb` | Existing file — update comment (cron → systemd timer) |

---

## Chunk 1: Config Files

### Task 1: Create systemd service for Rails/Puma

**Files:**
- Create: `config/systemd/raffle-kiosk.service`

- [ ] **Step 1: Create the systemd service file**

```ini
[Unit]
Description=Raffle Entry Collector (Rails/Puma)
After=local-fs.target

[Service]
Type=simple
User=raffle
Group=raffle
WorkingDirectory=/opt/raffle
EnvironmentFile=/opt/raffle/.env
Environment=RAILS_ENV=production

ExecStart=/opt/raffle/.rbenv/shims/bundle exec puma -C config/puma.rb

Restart=always
RestartSec=5

StandardOutput=journal
StandardError=journal

# Memory safety net — restart if leak develops (Pi 4 has 4GB)
MemoryMax=512M

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/raffle/db /opt/raffle/log /opt/raffle/tmp

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 2: Verify syntax**

Run: `systemd-analyze verify config/systemd/raffle-kiosk.service 2>&1 || true`

Note: This may warn about missing users/paths on dev machine — that's expected. Look for actual syntax errors only.

- [ ] **Step 3: Commit**

```bash
git add config/systemd/raffle-kiosk.service
git commit -m "feat: add systemd service for Rails/Puma kiosk (Issue #15)"
```

---

### Task 2: Create systemd backup service and timer

**Files:**
- Create: `config/systemd/raffle-backup.service`
- Create: `config/systemd/raffle-backup.timer`

- [ ] **Step 1: Create the backup service file**

```ini
[Unit]
Description=Raffle Entry Collector USB Backup
After=local-fs.target

[Service]
Type=oneshot
User=raffle
Group=raffle
WorkingDirectory=/opt/raffle
EnvironmentFile=/opt/raffle/.env
Environment=PATH=/opt/raffle/.rbenv/shims:/opt/raffle/.rbenv/bin:/usr/bin:/bin

ExecStart=/opt/raffle/bin/backup_to_usb

StandardOutput=journal
StandardError=journal
```

- [ ] **Step 2: Create the backup timer file**

```ini
[Unit]
Description=Raffle Entry Collector USB Backup Timer

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
```

- [ ] **Step 3: Verify syntax**

Run: `systemd-analyze verify config/systemd/raffle-backup.service 2>&1 || true`
Run: `systemd-analyze verify config/systemd/raffle-backup.timer 2>&1 || true`

- [ ] **Step 4: Update `bin/backup_to_usb` comment**

Change line 2 from:
```bash
# Called by cron every 5 minutes to back up to USB if present
```
To:
```bash
# Called by systemd timer (raffle-backup.timer) every 5 minutes to back up to USB if present
```

- [ ] **Step 5: Commit**

```bash
git add config/systemd/raffle-backup.service config/systemd/raffle-backup.timer bin/backup_to_usb
git commit -m "feat: add systemd backup timer and service (Issue #15)"
```

---

### Task 3: Create Chromium kiosk launcher

**Files:**
- Create: `config/kiosk/chromium-kiosk.sh`

- [ ] **Step 1: Create the Chromium launcher script**

```bash
#!/usr/bin/env bash
# Chromium kiosk launcher for Raffle Entry Collector
# Waits for Rails to be ready, then launches Chromium in kiosk mode.
# Runs in a loop to recover from Chromium crashes.

set -euo pipefail

RAILS_URL="http://127.0.0.1:3000"
HEALTH_TIMEOUT=60

wait_for_rails() {
    local elapsed=0
    echo "Waiting for Rails at ${RAILS_URL}..."
    while [ $elapsed -lt $HEALTH_TIMEOUT ]; do
        if curl --silent --fail "${RAILS_URL}" > /dev/null 2>&1; then
            echo "Rails is ready."
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    echo "ERROR: Rails did not become ready within ${HEALTH_TIMEOUT}s"
    return 1
}

while true; do
    if wait_for_rails; then
        chromium \
            --kiosk \
            --ozone-platform=wayland \
            --noerrdialogs \
            --disable-translate \
            --disable-features=TranslateUI \
            --no-first-run \
            --disable-infobars \
            --disable-session-crashed-bubble \
            --disable-component-update \
            --check-for-update-interval=31536000 \
            --autoplay-policy=no-user-gesture-required \
            --password-store=basic \
            "${RAILS_URL}" || true
    fi

    echo "Chromium exited. Restarting in 2 seconds..."
    sleep 2
done
```

- [ ] **Step 2: Make executable**

Run: `chmod +x config/kiosk/chromium-kiosk.sh`

- [ ] **Step 3: Verify with shellcheck**

Run: `shellcheck config/kiosk/chromium-kiosk.sh || true`

Fix any issues found (warnings about unused variables, etc. are OK).

- [ ] **Step 4: Commit**

```bash
git add config/kiosk/chromium-kiosk.sh
git commit -m "feat: add Chromium kiosk launcher with crash recovery (Issue #15)"
```

---

### Task 4: Create Wayfire config and kiosk login profile

**Files:**
- Create: `config/kiosk/wayfire.ini`
- Create: `config/kiosk/bash_profile`

- [ ] **Step 1: Create the Wayfire config**

```ini
# Wayfire config for kiosk user
# Locks down the desktop: no shortcuts to close/switch/terminal
# Emergency access: Ctrl+Alt+F2 for TTY (left unblocked)

[core]
plugins = autostart

[autostart]
chromium = /home/kiosk/chromium-kiosk.sh

# Disable close shortcut (Alt+F4, etc.)
[command]
binding_close = none
binding_terminal = none

# Disable window switcher
[switcher]
binding = none
```

- [ ] **Step 2: Create the kiosk user's `.bash_profile`**

This file starts Wayfire when the kiosk user auto-logins on tty1. Without it, the user lands at a bare shell prompt and Chromium never launches.

```bash
# Start Wayfire on tty1 (kiosk auto-login)
if [ "$(tty)" = "/dev/tty1" ]; then
    exec wayfire
fi
```

Save as: `config/kiosk/bash_profile`

- [ ] **Step 3: Commit**

```bash
git add config/kiosk/wayfire.ini config/kiosk/bash_profile
git commit -m "feat: add Wayfire kiosk lockdown config and login profile (Issue #15)"
```

---

### Task 5: Create udev rule and mount helper

**Files:**
- Create: `config/kiosk/99-raffle-backup.rules`
- Create: `config/kiosk/raffle-usb-mount`

- [ ] **Step 1: Create the udev rule**

```
# Auto-mount USB drives labeled RAFFLE_BACKUP for raffle backup service
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="RAFFLE_BACKUP", RUN+="/usr/local/bin/raffle-usb-mount add %k"
ACTION=="remove", SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="RAFFLE_BACKUP", RUN+="/usr/local/bin/raffle-usb-mount remove %k"
```

- [ ] **Step 2: Create the mount helper script**

```bash
#!/usr/bin/env bash
# udev helper script for mounting/unmounting RAFFLE_BACKUP USB drives
# Called by 99-raffle-backup.rules — runs as root
# Must be owned by root:root, mode 755

set -euo pipefail

ACTION="$1"
DEVICE="$2"
MOUNT_POINT="/mnt/raffle_backup"

case "$ACTION" in
    add)
        mkdir -p "$MOUNT_POINT"
        mount -t vfat -o "uid=raffle,gid=raffle,umask=022" "/dev/$DEVICE" "$MOUNT_POINT"
        logger -t raffle-usb "Mounted /dev/$DEVICE at $MOUNT_POINT"
        ;;
    remove)
        umount "$MOUNT_POINT" 2>/dev/null || true
        rmdir "$MOUNT_POINT" 2>/dev/null || true
        logger -t raffle-usb "Unmounted $MOUNT_POINT"
        ;;
    *)
        logger -t raffle-usb "Unknown action: $ACTION"
        exit 1
        ;;
esac
```

- [ ] **Step 3: Make helper executable**

Run: `chmod +x config/kiosk/raffle-usb-mount`

- [ ] **Step 4: Verify with shellcheck**

Run: `shellcheck config/kiosk/raffle-usb-mount || true`

- [ ] **Step 5: Commit**

```bash
git add config/kiosk/99-raffle-backup.rules config/kiosk/raffle-usb-mount
git commit -m "feat: add udev rule and helper for USB backup auto-mount (Issue #15)"
```

---

## Chunk 2: Setup Script

### Task 6: Create the idempotent setup script

**Files:**
- Create: `bin/setup_kiosk`

This is the main script. It's long but each section is idempotent and clearly separated. The script is run by `andre` with sudo access on the Pi.

- [ ] **Step 1: Create `bin/setup_kiosk`**

```bash
#!/usr/bin/env bash
# Idempotent kiosk setup script for Raffle Entry Collector
# Run as 'andre' user with sudo access on the Raspberry Pi
# Usage: bin/setup_kiosk

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

step() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}WARNING:${NC} $1"; }
fail() { echo -e "${RED}ERROR:${NC} $1"; exit 1; }

APP_SOURCE="$(cd "$(dirname "$0")/.." && pwd)"
APP_DEST="/opt/raffle"
RUBY_VERSION=$(cat "$APP_SOURCE/.ruby-version")

# ─── Preflight checks ───────────────────────────────────────────────

if [ "$(whoami)" = "root" ]; then
    fail "Do not run as root. Run as 'andre' — the script uses sudo where needed."
fi

if [ "$(whoami)" != "andre" ]; then
    fail "This script must be run as the 'andre' user."
fi

if ! sudo -n true 2>/dev/null; then
    fail "User 'andre' does not have passwordless sudo. Run 'sudo echo test' first."
fi

if [ ! -f "$APP_SOURCE/Gemfile" ]; then
    fail "Run this script from the RaffleEntryCollector directory (or its bin/ subdirectory)."
fi

step "Starting kiosk setup from $APP_SOURCE"

# ─── Step 1: Install system packages ────────────────────────────────

step "Installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    build-essential \
    libsqlite3-dev \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libyaml-dev \
    libffi-dev \
    sqlite3 \
    curl \
    git \
    chromium \
    wayfire

# ─── Step 2: Create raffle system user ──────────────────────────────

if ! id -u raffle >/dev/null 2>&1; then
    step "Creating 'raffle' system user..."
    sudo useradd --system --create-home --home-dir "$APP_DEST" --shell /usr/sbin/nologin raffle
else
    step "'raffle' user already exists, skipping."
fi

# ─── Step 3: Create kiosk user ──────────────────────────────────────

if ! id -u kiosk >/dev/null 2>&1; then
    step "Creating 'kiosk' user..."
    sudo useradd --create-home --shell /bin/bash kiosk
    # Lock password so kiosk user can't sudo or login with password
    sudo passwd -l kiosk
else
    step "'kiosk' user already exists, skipping."
fi

# ─── Step 4: Lock root account ──────────────────────────────────────

step "Locking root account..."
sudo passwd -l root

# ─── Step 5: Harden SSH ─────────────────────────────────────────────

step "Hardening SSH..."
if grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
    sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
else
    echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config >/dev/null
fi
sudo systemctl reload sshd 2>/dev/null || sudo systemctl reload ssh 2>/dev/null || true

# ─── Step 6: Harden VNC ─────────────────────────────────────────────

step "Restricting VNC to localhost..."
WAYVNC_DIR="/home/andre/.config/wayvnc"
WAYVNC_CONF="$WAYVNC_DIR/config"
if [ -d "$WAYVNC_DIR" ] || command -v wayvnc >/dev/null 2>&1; then
    sudo -u andre mkdir -p "$WAYVNC_DIR"
    if [ -f "$WAYVNC_CONF" ]; then
        if grep -q "^address=" "$WAYVNC_CONF"; then
            sed -i 's/^address=.*/address=127.0.0.1/' "$WAYVNC_CONF"
        else
            echo "address=127.0.0.1" >> "$WAYVNC_CONF"
        fi
    else
        echo "address=127.0.0.1" > "$WAYVNC_CONF"
    fi
else
    warn "wayvnc not found, skipping VNC hardening."
fi

# ─── Step 7: Install rbenv + Ruby for raffle user ───────────────────

if [ ! -d "$APP_DEST/.rbenv" ]; then
    step "Installing rbenv for raffle user..."
    sudo -u raffle -s /bin/bash -c "
        git clone https://github.com/rbenv/rbenv.git $APP_DEST/.rbenv
        git clone https://github.com/rbenv/ruby-build.git $APP_DEST/.rbenv/plugins/ruby-build
    "
else
    step "rbenv already installed, skipping."
fi

RBENV="$APP_DEST/.rbenv/bin/rbenv"
if ! sudo -u raffle -s /bin/bash -c "$RBENV versions --bare 2>/dev/null | grep -q '$RUBY_VERSION'"; then
    step "Installing Ruby $RUBY_VERSION (this will take a while on Pi)..."
    sudo -u raffle -s /bin/bash -c "
        export PATH=$APP_DEST/.rbenv/bin:$APP_DEST/.rbenv/shims:\$PATH
        rbenv install $RUBY_VERSION
        rbenv global $RUBY_VERSION
    "
else
    step "Ruby $RUBY_VERSION already installed, skipping."
fi

# ─── Step 8: Deploy app ─────────────────────────────────────────────

step "Deploying app to $APP_DEST..."
sudo rsync -a --delete \
    --exclude='.git' \
    --exclude='tmp/' \
    --exclude='log/' \
    --exclude='db/*.sqlite3' \
    --exclude='storage/' \
    --exclude='node_modules/' \
    --exclude='.rbenv/' \
    --exclude='.env' \
    --exclude='.bundle/' \
    --exclude='vendor/bundle/' \
    "$APP_SOURCE/" "$APP_DEST/"

# Ensure writable directories exist
sudo -u raffle mkdir -p "$APP_DEST/tmp" "$APP_DEST/log" "$APP_DEST/db"
sudo chown -R raffle:raffle "$APP_DEST"

step "Installing gems..."
sudo -u raffle -s /bin/bash -c "
    export PATH=$APP_DEST/.rbenv/bin:$APP_DEST/.rbenv/shims:\$PATH
    cd $APP_DEST
    bundle install --deployment --without development test
"

# ─── Step 9: Generate .env file ─────────────────────────────────────

if [ ! -f "$APP_DEST/.env" ]; then
    step "Generating .env file with auto-generated SECRET_KEY_BASE..."
    SECRET=$(openssl rand -hex 64)
    sudo -u raffle bash -c "cat > $APP_DEST/.env" <<EOF
RAILS_ENV=production
SECRET_KEY_BASE=$SECRET
ADMIN_PASSWORD=CHANGE_ME
EOF
    sudo chmod 600 "$APP_DEST/.env"
    sudo chown raffle:raffle "$APP_DEST/.env"
    warn ".env created — you MUST change ADMIN_PASSWORD before going live!"
else
    step ".env already exists, skipping (won't overwrite your secrets)."
fi

# ─── Step 10: Setup database ────────────────────────────────────────

step "Setting up production database..."
sudo -u raffle -s /bin/bash -c "
    export PATH=$APP_DEST/.rbenv/bin:$APP_DEST/.rbenv/shims:\$PATH
    cd $APP_DEST
    RAILS_ENV=production bundle exec rails db:create 2>/dev/null || true
    RAILS_ENV=production bundle exec rails db:migrate
"

# ─── Step 11: Precompile assets ─────────────────────────────────────

step "Precompiling assets..."
sudo -u raffle -s /bin/bash -c "
    export PATH=$APP_DEST/.rbenv/bin:$APP_DEST/.rbenv/shims:\$PATH
    cd $APP_DEST
    RAILS_ENV=production bundle exec rails assets:precompile
"

# ─── Step 12: Install systemd services ──────────────────────────────

step "Installing systemd services..."
sudo cp "$APP_DEST/config/systemd/raffle-kiosk.service" /etc/systemd/system/
sudo cp "$APP_DEST/config/systemd/raffle-backup.service" /etc/systemd/system/
sudo cp "$APP_DEST/config/systemd/raffle-backup.timer" /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable raffle-kiosk.service
sudo systemctl enable raffle-backup.timer

# ─── Step 13: Configure auto-login for kiosk user ───────────────────

step "Configuring auto-login for kiosk user on tty1..."
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<'AUTOLOGIN' | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin kiosk --noclear %I $TERM
AUTOLOGIN

# ─── Step 14: Install Wayfire config ─────────────────────────────────

step "Installing Wayfire config and login profile for kiosk user..."
sudo -u kiosk mkdir -p /home/kiosk/.config
sudo cp "$APP_DEST/config/kiosk/wayfire.ini" /home/kiosk/.config/wayfire.ini
sudo chown kiosk:kiosk /home/kiosk/.config/wayfire.ini
sudo cp "$APP_DEST/config/kiosk/bash_profile" /home/kiosk/.bash_profile
sudo chown kiosk:kiosk /home/kiosk/.bash_profile

# ─── Step 15: Install Chromium launcher ──────────────────────────────

step "Installing Chromium kiosk launcher..."
sudo cp "$APP_DEST/config/kiosk/chromium-kiosk.sh" /home/kiosk/chromium-kiosk.sh
sudo chmod +x /home/kiosk/chromium-kiosk.sh
sudo chown kiosk:kiosk /home/kiosk/chromium-kiosk.sh

# ─── Step 16: Install udev rule and mount helper ────────────────────

step "Installing udev rule for USB backup..."
sudo cp "$APP_DEST/config/kiosk/99-raffle-backup.rules" /etc/udev/rules.d/
sudo cp "$APP_DEST/config/kiosk/raffle-usb-mount" /usr/local/bin/raffle-usb-mount
sudo chmod 755 /usr/local/bin/raffle-usb-mount
sudo chown root:root /usr/local/bin/raffle-usb-mount
sudo udevadm control --reload-rules

# ─── Done ────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN} Kiosk setup complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo "  1. Edit /opt/raffle/.env to set ADMIN_PASSWORD"
echo "     (SECRET_KEY_BASE was auto-generated)"
echo "  2. Reboot the Pi: sudo reboot"
echo ""
echo "After reboot:"
echo "  - Rails starts automatically via systemd"
echo "  - Kiosk user auto-logins and launches Chromium"
echo "  - USB backup runs every 5 minutes (plug in RAFFLE_BACKUP drive)"
echo ""
echo "Emergency access:"
echo "  - Ctrl+Alt+F2 for TTY login as 'andre'"
echo "  - SSH: ssh andre@<pi-ip>"
echo "  - VNC: ssh -L 5900:localhost:5900 andre@<pi-ip>"
echo ""
```

- [ ] **Step 2: Make executable**

Run: `chmod +x bin/setup_kiosk`

- [ ] **Step 3: Verify with shellcheck**

Run: `shellcheck bin/setup_kiosk || true`

Fix any real issues (SC2086 quoting warnings, etc.). Some warnings about sudo invocations are expected.

- [ ] **Step 4: Commit**

```bash
git add bin/setup_kiosk
git commit -m "feat: add idempotent kiosk setup script (Issue #15)"
```

---

## Chunk 3: Final Verification and Cleanup

### Task 7: Run quality checks and close issue

- [ ] **Step 1: Run the full test suite**

Run: `bin/rails test`

Expected: All tests pass. The new files are config/scripts, not Ruby code, so existing tests should be unaffected.

- [ ] **Step 2: Run rubocop**

Run: `bundle exec rubocop`

Expected: No new offenses from config/script files (rubocop doesn't lint `.sh` or `.ini` files).

- [ ] **Step 3: Run brakeman**

Run: `bundle exec brakeman --no-pager -q`

Expected: No new warnings.

- [ ] **Step 4: Run shellcheck on all scripts**

Run: `shellcheck bin/setup_kiosk config/kiosk/chromium-kiosk.sh config/kiosk/raffle-usb-mount`

Fix any issues found.

- [ ] **Step 5: Comment on GitHub issue**

```bash
gh issue comment 15 -b "Implementation complete. Created:
- \`config/systemd/raffle-kiosk.service\` — Rails/Puma systemd unit with hardening
- \`config/systemd/raffle-backup.service\` + \`raffle-backup.timer\` — USB backup on 5-min interval
- \`config/kiosk/chromium-kiosk.sh\` — Chromium launcher with health check and crash recovery
- \`config/kiosk/wayfire.ini\` — Wayfire lockdown config
- \`config/kiosk/99-raffle-backup.rules\` + \`raffle-usb-mount\` — udev USB auto-mount
- \`bin/setup_kiosk\` — idempotent setup script (19 steps)

Key design decisions:
- Three-user model: kiosk (display), raffle (service), andre (admin)
- systemd timer instead of cron (raffle user has nologin shell)
- udev rule for hot-plug USB backup
- Root locked, SSH hardened, VNC localhost-only

Closes #15"
```

- [ ] **Step 6: Close the issue**

Run: `gh issue close 15`

- [ ] **Step 7: Update implementation plan**

Mark Task 15 as completed in `docs/plans/2026-03-14-implementation-plan.md`.
