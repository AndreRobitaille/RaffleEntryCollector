# Kiosk Setup Script and Deployment Config — Design Spec

**Issue:** #15
**Date:** 2026-03-15
**Status:** Draft

## Overview

Idempotent setup script and deployment configuration for the Raspberry Pi 4 kiosk running the Raffle Entry Collector at CypherCon. The design prioritizes privilege separation and security hardening appropriate for a kiosk at a security conference.

## Deviations from Original Plan

The original issue (#15) and implementation plan specified a two-user model (`kiosk` + `andre`) with Rails running as `andre`. This design upgrades to a three-user model for stronger privilege separation:

- `andre` no longer runs any services — reserved for admin/SSH only
- New `raffle` system user owns the app, DB, and runs Rails
- App deployed to `/opt/raffle` instead of `/home/andre/RaffleEntryCollector`

These changes improve the security posture for a kiosk at a security conference, where the audience is adversarial by nature.

## User & Permission Architecture

Three-user model separating display, service, and admin concerns:

| User | Purpose | Login | Shell | Sudo | Home |
|------|---------|-------|-------|------|------|
| `andre` | Admin/maintenance | SSH + TTY (Ctrl+Alt+F2) + VNC (via SSH tunnel) | `/bin/bash` | Full | `/home/andre` |
| `raffle` | Rails service account | No login | `/usr/sbin/nologin` | None | `/opt/raffle` |
| `kiosk` | Chromium display | Auto-login on tty1 | `/bin/bash` | None | `/home/kiosk` |

**Root account:** Locked via `passwd -l root`. SSH root login disabled.

**File ownership:**
- `/opt/raffle/` — app code, DB, logs all owned by `raffle:raffle`
- `/home/kiosk/` — only Wayfire config and Chromium launcher, owned by `kiosk:kiosk`
- `kiosk` user has no read access to `/opt/raffle/db/` or `/opt/raffle/log/`

**App location:** `/opt/raffle` — a deployed copy of the repo (not the development checkout). The setup script copies the app there and sets ownership.

**Running commands as `raffle`:** Since `raffle` has `/usr/sbin/nologin`, all commands that need to run as `raffle` during setup use `sudo -u raffle -s /bin/bash -c '...'`. Systemd services and timers don't need a login shell — they set `User=raffle` directly.

## Systemd Service & Boot Sequence

### Boot Order

1. Pi powers on
2. systemd starts `raffle-kiosk.service` (Rails/Puma) early in boot
3. Getty auto-logins `kiosk` user on tty1
4. Wayfire starts, runs autostart section from `wayfire.ini`
5. Chromium kiosk script waits for Rails to be ready (curl loop), then launches

### Service Configuration (`config/systemd/raffle-kiosk.service`)

- `User=raffle`, `Group=raffle`
- `WorkingDirectory=/opt/raffle`
- `Environment=RAILS_ENV=production`
- `EnvironmentFile=/opt/raffle/.env` — contains `SECRET_KEY_BASE` and `ADMIN_PASSWORD` (owned by `raffle:raffle`, mode 600)
- `Restart=always`, `RestartSec=5`
- `ExecStart=/opt/raffle/.rbenv/shims/bundle exec puma -C config/puma.rb`
- `After=local-fs.target`
- `StandardOutput=journal`, `StandardError=journal`

**Production robustness (48-hour runtime):**
- Single-mode Puma (no workers, default 3 threads per `config/puma.rb`) — keeps memory footprint small for Pi 4.
- `MemoryMax=512M` in systemd — kills and restarts if a memory leak develops. Pi 4 has 4GB; Chromium takes ~400-600MB, Wayfire ~50MB, leaving plenty of room.
- `Restart=always` — automatic recovery from any crash within 5 seconds

**Hardening directives:**
- `NoNewPrivileges=true`
- `ProtectSystem=strict`
- `ProtectHome=true`
- `ReadWritePaths=/opt/raffle/db /opt/raffle/log /opt/raffle/tmp`

### Auto-Login

systemd getty override at `/etc/systemd/system/getty@tty1.service.d/autologin.conf` — auto-logins `kiosk` user on tty1. This override is always applied (not gated on user creation) to ensure idempotency.

### Chromium Health Check

The Chromium launch script polls `curl --silent --fail http://127.0.0.1:3000/` in a loop with 1-second sleep, timing out after 60 seconds. If Rails never comes up, Chromium doesn't launch (avoids a confusing error page on screen).

## USB Backup & udev

### udev Rule (`/etc/udev/rules.d/99-raffle-backup.rules`)

Triggers on any block device with filesystem label `RAFFLE_BAK`. Expects a FAT32-formatted USB drive (most common for USB sticks and maximally portable).

The udev rule calls a helper script (`/usr/local/bin/raffle-usb-mount`) that handles mount/unmount:

**On add:**
- Creates `/mnt/raffle_backup` if it doesn't exist
- Mounts with `-t vfat -o uid=raffle,gid=raffle,umask=022`

**On remove:**
- Runs `umount /mnt/raffle_backup` (filesystem is already gone, this cleans up the stale mount point)
- Removes the mount point directory

**Permissions:** The helper script must be owned by root and mode 755 (not writable by others), since udev scripts run as root and are a privilege escalation vector.

### Systemd Timer (runs as `raffle`, every 5 minutes)

Uses a systemd timer + service pair (`raffle-backup.timer` / `raffle-backup.service`) instead of cron, because the `raffle` user has nologin shell and cron requires a valid shell.

**`raffle-backup.service`:**
- `User=raffle`, `Group=raffle`
- `WorkingDirectory=/opt/raffle`
- `Environment=RAILS_ENV=production`
- `Environment=PATH=/opt/raffle/.rbenv/shims:/opt/raffle/.rbenv/bin:/usr/bin:/bin`
- `ExecStart=/opt/raffle/bin/backup_to_usb`

**`raffle-backup.timer`:**
- `OnBootSec=5min` — first run 5 minutes after boot
- `OnUnitActiveSec=5min` — then every 5 minutes
- `[Install] WantedBy=timers.target`

**Backup logic:**
1. Checks if `/mnt/raffle_backup` is mounted
2. If not mounted, silently exits
3. If mounted, calls `bin/backup_to_usb` which uses the existing `UsbBackup` service

### What Gets Backed Up

- `db/production.sqlite3` (the database)
- `log/submissions.jsonl` (append-only submission log)

## Wayfire & Chromium Kiosk Lockdown

### Wayfire Config (`/home/kiosk/.config/wayfire.ini`)

- Disables: `binding_close`, `binding_terminal`, Alt+F4, Ctrl+W, Ctrl+Q
- Leaves Ctrl+Alt+F2 unblocked for emergency TTY switch to `andre`
- `[core]` section sets `plugins = autostart` explicitly — prevents workspace switcher, app switcher, etc.
- No panel, no dock, no wallpaper — Chromium fills the screen
- Contains `[autostart]` section that launches `chromium-kiosk.sh` directly (Wayfire reads autostart from `wayfire.ini`, not a separate file)

```ini
[autostart]
chromium = /home/kiosk/chromium-kiosk.sh
```

### Chromium Launch Script (`config/kiosk/chromium-kiosk.sh`)

The script runs in a loop: wait for Rails, launch Chromium, and if Chromium crashes, wait and relaunch. This ensures the kiosk recovers from Chromium crashes without manual intervention.

```
while true:
  wait for Rails (curl loop, 60s timeout)
  launch Chromium with kiosk flags
  (Chromium blocks here until it exits/crashes)
  sleep 2 (brief pause before relaunch)
```

### Chromium Flags

- `--kiosk` — fullscreen, no URL bar, no tabs, no browser UI
- `--ozone-platform=wayland` — required for Chromium on Wayfire (Wayland compositor)
- `--noerrdialogs` — suppress error popups
- `--disable-translate`, `--disable-features=TranslateUI` — no translate prompts
- `--no-first-run` — skip welcome screen
- `--disable-infobars` — no "Chrome is being controlled" bar
- `--disable-session-crashed-bubble` — no crash recovery dialog
- `--disable-component-update`, `--check-for-update-interval=31536000` — don't try to update (offline anyway)
- `--autoplay-policy=no-user-gesture-required` — just in case
- `--password-store=basic` — bypass gnome-keyring prompt

## Security Hardening

### Root Account

- `passwd -l root` — locks root login (password disabled)
- `/etc/ssh/sshd_config`: `PermitRootLogin no`

### SSH

- Only `andre` can SSH in
- Root login disabled
- Existing key-based auth configuration left as-is

### VNC

- Restricted to localhost only — access via SSH tunnel (`ssh -L 5900:localhost:5900 andre@pi`)
- Never exposed on the network

### Emergency Access

- Ctrl+Alt+F2 switches to TTY (left unblocked in Wayfire)
- SSH as `andre`
- VNC via SSH tunnel

## Setup Script Structure

**`bin/setup_kiosk`** — run once by `andre` with sudo. Idempotent (safe to re-run). Each step checks if it's already done before acting and prints what it's doing.

1. **Preflight checks** — verify running as `andre` (not root), verify sudo access, verify we're in the app directory
2. **Install system packages** — apt install build-essential, libsqlite3-dev, libssl-dev, libreadline-dev, zlib1g-dev, libyaml-dev, libffi-dev, sqlite3, curl, git, chromium, wayfire
3. **Create `raffle` system user** — no login shell, home at `/opt/raffle`, if not exists
4. **Create `kiosk` user** — no sudo, no password, if not exists
5. **Lock root account** — `passwd -l root`
6. **Harden SSH** — set `PermitRootLogin no` in sshd_config
7. **Harden VNC** — bind to localhost only
8. **Install rbenv + ruby-build** under `/opt/raffle/.rbenv` using `sudo -u raffle -s /bin/bash -c '...'`, install pinned Ruby version from `.ruby-version`
9. **Deploy app** — copy app files to `/opt/raffle`, set ownership to `raffle:raffle`, run `bundle install --deployment --without development test` as `raffle`
10. **Generate `.env` file** — auto-generates `SECRET_KEY_BASE` via `openssl rand -hex 64`, sets `ADMIN_PASSWORD=CHANGE_ME` placeholder. Mode 600, owned by `raffle`. Only created if `.env` doesn't already exist, to avoid overwriting user-set values.
11. **Setup database** — `db:create db:migrate` as `raffle` in production
12. **Precompile assets** — `assets:precompile` as `raffle`
13. **Install systemd service** — copy `raffle-kiosk.service`, enable it
14. **Install backup timer** — copy `raffle-backup.service` and `raffle-backup.timer`, enable timer
15. **Configure auto-login** — getty override for `kiosk` on tty1 (always applied, not gated on user creation)
16. **Install Wayfire config** — copy to `/home/kiosk/.config/wayfire.ini`
17. **Install Chromium launcher** — copy to `/home/kiosk/chromium-kiosk.sh`, make executable
18. **Install udev rule + mount helper** — copy rule and helper script, reload udev
19. **Print next steps** — "Edit `/opt/raffle/.env` to set ADMIN_PASSWORD (SECRET_KEY_BASE was auto-generated), then reboot"

## Files to Create

| File | Purpose |
|------|---------|
| `bin/setup_kiosk` | Idempotent setup script (executable) |
| `config/systemd/raffle-kiosk.service` | systemd unit for Rails/Puma |
| `config/systemd/raffle-backup.service` | systemd unit for USB backup |
| `config/systemd/raffle-backup.timer` | systemd timer for 5-minute backup interval |
| `config/kiosk/chromium-kiosk.sh` | Chromium launcher with health check and crash recovery loop |
| `config/kiosk/wayfire.ini` | Wayfire desktop config for kiosk user (includes autostart) |
| `config/kiosk/99-raffle-backup.rules` | udev rule for USB auto-mount |
| `config/kiosk/raffle-usb-mount` | udev helper script for mount/unmount |

## Acceptance Criteria

- [ ] `bin/setup_kiosk` is executable and idempotent
- [ ] systemd service file is correct with full ExecStart path
- [ ] Chromium launch script waits for Rails then starts kiosk, with crash recovery loop
- [ ] Wayfire config blocks common escape shortcuts and includes autostart section
- [ ] Setup script prints next steps on completion
- [ ] Three-user privilege separation (kiosk, raffle, andre)
- [ ] Root account locked, SSH root login disabled
- [ ] VNC restricted to localhost
- [ ] USB backup auto-mounts via udev rule with FAT32 support
- [ ] Backup runs via systemd timer (not cron)
