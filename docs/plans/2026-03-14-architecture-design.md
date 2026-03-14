# Architecture & Deployment Design

## Decisions

### Deployment Strategy
- Develop on workstation, push to git, `git pull` on Pi, run idempotent setup script
- No Ansible, no SD card imaging, no Docker
- Update workflow: `git pull && bin/setup_kiosk && sudo systemctl restart raffle-kiosk`

### Runtime
- **rbenv** for Ruby version management on the Pi
- System packages via **apt** only (no Homebrew in the deployment path)
- No Docker (memory too tight alongside Chromium on 4GB Pi 4)

### User Separation
- **`kiosk` user** — no sudo, no password, auto-login, runs Chromium kiosk only
- **`andre` user** — runs Rails via systemd, owns the database, SSH access, sudo
- Tamper resistance: escaping Chromium lands in an unprivileged session with no access to DB or sudo

### Frontend
- **Hotwire (Turbo + Stimulus)** — no React, no Vue, no JS build pipeline
- Turbo Frames for screen transitions (attract -> form -> success)
- Stimulus controllers: eligibility checkbox gate, idle timeout, rules modal

### Admin Auth
- Simple session-based password on `/admin` route
- Password from environment variable or config file
- No user model, no Devise

---

## Application Architecture

### Models
- **`Entrant`** — single core model. `interest_areas` stored as JSON array column.
- **`RaffleDraw`** — audit log of draw events: timestamp, eligible count, winner entrant ID, admin note.

### Controllers
- **`KioskController`** — public-facing: attract screen, entry form submission, success screen
- **`Admin::` namespace** — password-protected: entries list/search, CSV export, duplicate review, exclusions/reinstatements, raffle drawing

### Stimulus Controllers
- `eligibility-controller` — enables/disables form fields based on confirmation checkbox
- `idle-timeout-controller` — 90-second countdown, resets to attract screen via Turbo
- `modal-controller` — rules overlay open/close

### Eligibility Statuses
```
eligible                — default on submission
self_attested_ineligible — checkbox not confirmed (form prevents this, edge case guard)
duplicate_review        — auto-flagged by duplicate detection
excluded_admin          — manually excluded by admin
reinstated_admin        — manually reinstated by admin
winner                  — selected by raffle draw
alternate_winner        — selected as alternate
```

### Duplicate Detection
- Runs inline after each submission (no background jobs)
- Flags on: identical email OR matching first_name + last_name + company
- Sets status to `duplicate_review`, does not block submission

---

## Data Integrity

### Three Layers
1. **SQLite in WAL mode** — crash resilience, concurrent read support
2. **JSONL append log** (`log/submissions.jsonl`) — one JSON line per submission, flushed immediately. Allows full DB reconstruction if needed.
3. **USB backup** — cron job every 5 minutes. Looks for drive labeled `RAFFLE_BACKUP`. Copies DB (via SQLite `.backup` command) and JSONL log. Admin dashboard shows last backup time/status.

---

## Raffle Drawing

1. Admin views eligible/excluded/total counts
2. Clicks "Run Drawing" with confirmation prompt
3. System snapshots eligible pool
4. Selects winner via `SecureRandom.random_number(eligible_count)`
5. Sets winner's `eligibility_status` to `winner`
6. Logs draw to `raffle_draws` table
7. Alternate draws possible, excluding previous winners

---

## Kiosk Deployment

### Boot Sequence
1. Pi auto-logins `kiosk` user to Wayfire desktop
2. Wayfire config blocks keyboard shortcuts (Alt+F4, Ctrl+W, Ctrl+Q, etc.)
3. systemd service starts Rails on `127.0.0.1:3000` under `andre` user
4. Wayfire autostart launches Chromium kiosk pointing to localhost:3000

### Chromium Flags
```
--kiosk --noerrdialogs --disable-translate --no-first-run
--disable-infobars --disable-session-crashed-bubble
--disable-features=TranslateUI --autoplay-policy=no-user-gesture-required
```

### Wayfire Shortcut Blocking
- Override keybindings in `~/.config/wayfire.ini` for the `kiosk` user
- Disable common escape combos
- Leave Ctrl+Alt+F2 (TTY switch) unblocked as emergency escape for `andre`

### Setup Script (`bin/setup_kiosk`)
Idempotent bash script that:
- Installs system deps via apt (build-essential, libsqlite3-dev, etc.)
- Creates `kiosk` user if not exists
- Installs rbenv + ruby-build, pins Ruby version
- Runs `bundle install`
- Runs `db:create db:migrate`
- Installs systemd service for Rails under `andre`
- Configures `kiosk` user auto-login
- Configures Wayfire autostart + shortcut blocking for `kiosk` user
- Configures Chromium kiosk launch
- Sets up USB backup cron job

### Emergency Access
- SSH into Pi as `andre`
- Or Ctrl+Alt+F2 to TTY, login as `andre`
- `andre` has sudo, can restart services, access DB, etc.
