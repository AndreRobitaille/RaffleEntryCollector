# RaffleEntryCollector

Kiosk-based raffle entry and lead collection app for the Final Frontier Security booth at CypherCon. Runs offline on a Raspberry Pi 4 with a 10.1" touchscreen.

## Features

- **Kiosk entry form** — attendees enter name, email, company, job title, and select interest areas. 90-second idle timeout resets to the attract screen.
- **Duplicate detection** — flags matching emails or name+company pairs for admin review (never blocks the kiosk).
- **Admin console** (`/admin`) — password-protected dashboard for managing entries, excluding/reinstating entrants, and searching/sorting.
- **Raffle drawing** — cryptographically secure random selection draws winner + 2 alternates in one action, with full audit trail. Full-screen celebration overlay for announcing winners at the booth.
- **CSV export** — download eligible entries, all entries, or winners/alternates with contact info and draw order.
- **USB backup** — automatic database and submission log backup to a labeled USB drive.
- **Three-layer data integrity** — SQLite (WAL mode), append-only JSONL submission log, and periodic USB backup.

## Development Setup

### 1. Clone the repo

```bash
git clone https://github.com/AndreRobitaille/RaffleEntryCollector.git
cd RaffleEntryCollector
```

### 2. Install Ruby 4.0

On Trixie, the easiest route is [mise](https://mise.jdx.dev/) (or rbenv):

```bash
# If mise isn't installed yet:
curl https://mise.jdx.dev/install.sh | sh
mise install ruby@4.0.0
mise use ruby@4.0.0
```

Alternatively, if Trixie's system Ruby is recent enough, use that.

### 3. Install dependencies and set up the database

```bash
bundle install
bin/rails db:create db:migrate
```

### 4. Set the admin password

The admin console requires a password stored in Rails encrypted credentials. To set it:

```bash
EDITOR="nano" bin/rails credentials:edit
```

Add the following line:

```yaml
admin_password: your-secure-password-here
```

Save and exit. This encrypts the password into `config/credentials.yml.enc` (committed to the repo) using `config/master.key` (not committed — keep it safe).

In development, the admin console falls back to `dev-password` if credentials are not configured.

### 5. Boot the server

```bash
bin/rails server
```

### 6. Run the tests

```bash
bin/rails test
bundle exec rubocop
bundle exec brakeman --no-pager -q
```

### Accessing the Admin Console

The admin console lives at `/admin`. From the kiosk screens, there are two hidden ways to reach it:

- **Tap target** — tap the small dot in the bottom-right corner of any kiosk screen 5 times in quick succession (within 1.5 seconds).
- **Keyboard shortcut** — press `Ctrl+Shift+A` on any kiosk screen.

Both methods navigate to the admin login page. In development, the password is `dev-password`. In production, it uses the password set in Rails encrypted credentials (see step 4 above).

## Kiosk Deployment (Raspberry Pi)

The kiosk runs on a Raspberry Pi 4 with Raspberry Pi OS 64-bit (Debian Trixie). An idempotent setup script handles all deployment configuration.

### Prerequisites

- Raspberry Pi 4 with Raspberry Pi OS 64-bit installed
- An admin user with sudo access
- Network access during setup (for installing packages and Ruby)
- A FAT32-formatted USB drive labeled `RAFFLE_BACKUP` (for backups)

### Running the Setup Script

From the cloned repo on the Pi:

```bash
bin/setup_kiosk
```

The script is idempotent — safe to re-run. It will:

1. Install system packages (build tools, SQLite, Chromium, Wayfire)
2. Create a dedicated service user to run the Rails app
3. Create a dedicated kiosk user for the display (auto-login, no privileges)
4. Harden SSH and lock the root account
5. Restrict VNC to localhost (accessible via SSH tunnel only)
6. Install Ruby via rbenv
7. Deploy the app, install gems, set up the production database, and precompile assets
8. Install and enable systemd services (Rails app + USB backup timer)
9. Configure auto-login and Wayfire compositor lockdown for the kiosk display
10. Install udev rules for automatic USB backup drive mounting

After the script completes, it will print next steps for setting the admin password and rebooting.

### What Happens on Boot

1. The Rails app starts automatically via systemd
2. The kiosk user auto-logins and the Wayfire compositor launches
3. Chromium opens in fullscreen kiosk mode pointing at the app
4. USB backup runs every 5 minutes (if a backup drive is plugged in)

### USB Backup

Format a USB drive as FAT32 and label it `RAFFLE_BACKUP`. Plug it into the Pi at any time — it auto-mounts and backups begin automatically. Unplug it when you want to take the backup offsite. The backup includes:

- The SQLite database
- The append-only JSONL submission log

Backup status is displayed on the admin dashboard.

### Emergency Access

- Switch to a terminal TTY for admin login
- SSH into the Pi from another machine
- VNC via SSH tunnel

### Configuration Files

All deployment config lives in the repo:

| File | Purpose |
|------|---------|
| `bin/setup_kiosk` | Idempotent setup script |
| `config/systemd/raffle-kiosk.service` | systemd unit for the Rails app |
| `config/systemd/raffle-backup.service` | systemd unit for USB backup |
| `config/systemd/raffle-backup.timer` | Timer for 5-minute backup interval |
| `config/kiosk/chromium-kiosk.sh` | Chromium launcher with health check |
| `config/kiosk/wayfire.ini` | Wayfire compositor lockdown config |
| `config/kiosk/bash_profile` | Kiosk user login profile |
| `config/kiosk/99-raffle-backup.rules` | udev rule for USB auto-mount |
| `config/kiosk/raffle-usb-mount` | udev helper for mount/unmount |

## Deployment Checklist

- [ ] Set admin password (the setup script will tell you how)
- [ ] Back up `config/master.key` securely (it's not in the repo)
- [ ] Prepare USB drive: FAT32 format, label `RAFFLE_BACKUP`
- [ ] Reboot the Pi and verify the kiosk launches
- [ ] Test offline operation (disable network before the event)
- [ ] Run `bin/rails test` before deploying

## Security

- **Localhost only** — Rails binds to 127.0.0.1, no network exposure
- **Privilege separation** — separate users for display, app service, and admin
- **Root locked** — root account disabled, SSH root login denied
- **VNC restricted** — bound to localhost, accessible only via SSH tunnel
- **Compositor lockdown** — keyboard shortcuts disabled in Wayfire (close, terminal, app switcher)
- **No autofill** — form inputs disable autocomplete (security conference audience)
- **Session-only auth** — no persistent tokens or cookies with credentials
- **Encrypted credentials** — admin password stored in Rails encrypted credentials, never in plaintext
- **Timing-safe comparison** — password checked with `ActiveSupport::SecurityUtils.secure_compare`
- **Systemd hardening** — `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome`, memory limits
