# RaffleEntryCollector

Kiosk-based raffle entry and lead collection app for the Final Frontier Security booth at CypherCon. Runs offline on a Raspberry Pi 4 with a 10.1" touchscreen.

## Features

- **Kiosk entry form** — attendees enter name, email, company, job title, and select interest areas. 90-second idle timeout resets to the attract screen.
- **Duplicate detection** — flags matching emails or name+company pairs for admin review (never blocks the kiosk).
- **Admin console** (`/admin`) — password-protected dashboard for managing entries, excluding/reinstating entrants, and searching/sorting.
- **Raffle drawing** — cryptographically secure random selection with audit trail. Tracks winner and alternate.
- **CSV export** — download eligible or all entries with interest area columns.
- **USB backup** — automatic database and submission log backup to a labeled USB drive.
- **Three-layer data integrity** — SQLite (WAL mode), append-only JSONL submission log, and periodic USB backup.

## Setup

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

In development, the admin console falls back to a default dev password if credentials are not configured.

### 5. Boot the server

```bash
bin/rails server
```

### 6. Verify it works

```bash
# Quick test:
curl http://127.0.0.1:3000

# Or open Chromium in kiosk mode:
chromium-browser --kiosk http://127.0.0.1:3000
```

## USB Backup

The app backs up the SQLite database and JSONL submission log to a USB drive.

1. Format a USB drive and label it `RAFFLE_BACKUP`
2. Insert it into the Pi
3. Set up a cron job to run every 5 minutes:
   ```bash
   */5 * * * * cd /path/to/RaffleEntryCollector && bin/backup_to_usb
   ```

Backup status is displayed on the admin dashboard. You can also trigger a backup manually:

```bash
bin/rails runner "UsbBackup.perform"
```

## Deployment Checklist

- [ ] Set admin password via `rails credentials:edit`
- [ ] Back up `config/master.key` securely (it's not in the repo)
- [ ] Prepare USB drive labeled `RAFFLE_BACKUP`
- [ ] Set up cron job for `bin/backup_to_usb` (every 5 minutes)
- [ ] Configure Chromium to auto-launch in kiosk mode on boot
- [ ] Test offline operation (disable network before the event)
- [ ] Run `bin/rails test` before deploying

## Security

- **Localhost only** — Rails binds to 127.0.0.1, no network exposure
- **No autofill** — form inputs disable autocomplete (security conference audience)
- **Session-only auth** — no persistent tokens or cookies with credentials
- **Encrypted credentials** — admin password stored in Rails encrypted credentials, never in plaintext
- **Timing-safe comparison** — password checked with `ActiveSupport::SecurityUtils.secure_compare`
