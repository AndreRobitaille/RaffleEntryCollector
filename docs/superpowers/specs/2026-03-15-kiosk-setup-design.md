# Kiosk Setup Script and Deployment Config — Design Spec

**Issue:** #15
**Date:** 2026-03-15
**Status:** Draft

## Overview

Idempotent setup script and deployment configuration for the Raspberry Pi 4 kiosk running the Raffle Entry Collector at CypherCon. The design prioritizes privilege separation and security hardening appropriate for a kiosk at a security conference.

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

## Systemd Service & Boot Sequence

### Boot Order

1. Pi powers on
2. systemd starts `raffle-kiosk.service` (Rails/Puma) early in boot
3. Getty auto-logins `kiosk` user on tty1
4. Wayfire starts, runs autostart script
5. Chromium kiosk script waits for Rails to be ready (curl loop), then launches

### Service Configuration (`config/systemd/raffle-kiosk.service`)

- `User=raffle`, `Group=raffle`
- `WorkingDirectory=/opt/raffle`
- `Environment=RAILS_ENV=production`
- `EnvironmentFile=/opt/raffle/.env` — contains `SECRET_KEY_BASE` and `ADMIN_PASSWORD` (owned by `raffle:raffle`, mode 600)
- `Restart=always`, `RestartSec=5`
- `ExecStart` runs Puma via bundler

**Production robustness (48-hour runtime):**
- Single-mode Puma (no workers, just threads) — keeps memory footprint small for Pi 4
- `MemoryMax=256M` in systemd — kills and restarts if a memory leak develops
- `Restart=always` — automatic recovery from any crash within 5 seconds

**Hardening directives:**
- `NoNewPrivileges=true`
- `ProtectSystem=strict`
- `ProtectHome=true`
- `ReadWritePaths=/opt/raffle/db /opt/raffle/log /opt/raffle/storage /opt/raffle/tmp`

### Auto-Login

systemd getty override at `/etc/systemd/system/getty@tty1.service.d/autologin.conf` — auto-logins `kiosk` user on tty1.

### Chromium Health Check

The Chromium launch script polls `curl --silent --fail http://127.0.0.1:3000/` in a loop with 1-second sleep, timing out after 60 seconds. If Rails never comes up, Chromium doesn't launch (avoids a confusing error page on screen).

## USB Backup & udev

### udev Rule (`/etc/udev/rules.d/99-raffle-backup.rules`)

- Triggers on any block device with filesystem label `RAFFLE_BACKUP`
- Auto-mounts to `/mnt/raffle_backup` with ownership `raffle:raffle`
- Auto-unmounts on removal

### Cron Job (runs as `raffle`, every 5 minutes)

1. Checks if `/mnt/raffle_backup` is mounted
2. If not mounted, silently exits (no error, no log noise)
3. If mounted, calls `bin/backup_to_usb` which uses the existing `UsbBackup` service

### What Gets Backed Up

- `db/production.sqlite3` (the database)
- `log/submissions.jsonl` (append-only submission log)

## Wayfire & Chromium Kiosk Lockdown

### Wayfire Config (`/home/kiosk/.config/wayfire.ini`)

- Disables: `binding_close`, `binding_terminal`, Alt+F4, Ctrl+W, Ctrl+Q
- Leaves Ctrl+Alt+F2 unblocked for emergency TTY switch to `andre`
- Minimal plugins: just `autostart`
- No panel, no dock, no wallpaper — Chromium fills the screen

### Wayfire Autostart (`/home/kiosk/.config/wayfire-autostart`)

Launches `chromium-kiosk.sh` on login.

### Chromium Flags

- `--kiosk` — fullscreen, no URL bar, no tabs, no browser UI
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
2. **Install system packages** — apt install build-essential, libsqlite3-dev, libssl-dev, libreadline-dev, zlib1g-dev, libyaml-dev, sqlite3, curl, git, chromium-browser
3. **Create `raffle` system user** — no login shell, home at `/opt/raffle`, if not exists
4. **Create `kiosk` user** — no sudo, no password, if not exists
5. **Lock root account** — `passwd -l root`
6. **Harden SSH** — set `PermitRootLogin no` in sshd_config
7. **Harden VNC** — bind to localhost only
8. **Install rbenv + ruby-build** for `raffle` user, install pinned Ruby version
9. **Deploy app** — copy app files to `/opt/raffle`, set ownership to `raffle:raffle`, run `bundle install --deployment --without development test`
10. **Generate `.env` file** — with placeholder `SECRET_KEY_BASE` and `ADMIN_PASSWORD`, mode 600, owned by `raffle`
11. **Setup database** — `db:create db:migrate` as `raffle` in production
12. **Precompile assets** — `assets:precompile` as `raffle`
13. **Install systemd service** — copy `raffle-kiosk.service`, enable it
14. **Configure auto-login** — getty override for `kiosk` on tty1
15. **Install Wayfire config** — copy to `/home/kiosk/.config/`
16. **Install Chromium launcher** — copy to `/home/kiosk/`
17. **Install udev rule** — for `RAFFLE_BACKUP` auto-mount
18. **Install cron job** — backup every 5 minutes as `raffle`
19. **Print next steps** — "Edit `/opt/raffle/.env` to set SECRET_KEY_BASE and ADMIN_PASSWORD, then reboot"

## Files to Create

| File | Purpose |
|------|---------|
| `bin/setup_kiosk` | Idempotent setup script (executable) |
| `config/systemd/raffle-kiosk.service` | systemd unit for Rails/Puma |
| `config/kiosk/chromium-kiosk.sh` | Chromium launcher with health check |
| `config/kiosk/wayfire.ini` | Wayfire desktop config for kiosk user |
| `config/kiosk/autostart` | Wayfire autostart config |
| `config/kiosk/99-raffle-backup.rules` | udev rule for USB auto-mount |

## Acceptance Criteria

- [ ] `bin/setup_kiosk` is executable and idempotent
- [ ] systemd service file is correct
- [ ] Chromium launch script waits for Rails then starts kiosk
- [ ] Wayfire config blocks common escape shortcuts
- [ ] Setup script prints next steps on completion
- [ ] Three-user privilege separation (kiosk, raffle, andre)
- [ ] Root account locked, SSH root login disabled
- [ ] VNC restricted to localhost
- [ ] USB backup auto-mounts via udev rule
