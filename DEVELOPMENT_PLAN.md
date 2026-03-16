# Final Frontier Security -- CypherCon Raffle Lead Collection Kiosk

Development Plan

## 1. Purpose

Create a kiosk-based lead collection application for the Final Frontier
Security booth at CypherCon.

Primary goals: - Collect high‑quality business leads. - Enter attendees
into a raffle for a **Commodore 64 Ultimate**. - Ensure **data integrity
and reliability**. - Provide a **clean, modern, easy-to-use touchscreen
UI**. - Operate **fully offline** during the conference.

The system will run on:

-   **Raspberry Pi 4**
-   **Raspberry Pi OS (64‑bit, Debian Trixie)**
-   **10.1" touchscreen**
-   **Wireless keyboard with trackpad**
-   **No internet connectivity during the event**

The application must function entirely locally.

------------------------------------------------------------------------

# 2. Technology Stack

## Backend Framework

**Ruby on Rails 8** with **Ruby 4.0** (managed via rbenv)

Reasons: - Fast to build reliable forms and admin interfaces - Excellent
SQLite support - Easy CSV export - Mature ecosystem - Clean separation
of models, views, controllers

## Database

**SQLite** in **WAL mode**

Reasons: - Reliable embedded database - Perfect for single-device
usage - No network dependencies - Easy backup and export - WAL mode
provides crash resilience and concurrent read support

## Frontend

**Hotwire (Turbo + Stimulus)** rendered in **Chromium kiosk mode**.

- Turbo Frames for screen transitions (attract → form → success)
- Stimulus controllers for eligibility gating, idle timeout, and modals
- **No JavaScript build pipeline** — uses importmap-rails

## Deployment Model

The system runs:

    Rails app (localhost:3000)
    ↓
    SQLite database (WAL mode)
    ↓
    Chromium kiosk browser (fullscreen)

No network access required.

------------------------------------------------------------------------

# 3. Core System Principles

1.  **Local-first design**
2.  **Simple architecture**
3.  **High data integrity**
4.  **Fast kiosk UX**
5.  **Clear audit trail**
6.  **Explainable raffle fairness**
7.  **No CRM functionality**

The kiosk is strictly **lead collection**.

------------------------------------------------------------------------

# 4. User Experience Flow

## Screen 1 -- Attract Screen

Purpose: signal that the device is interactive.

Display:

    Win a Commodore 64 Ultimate

    Enter the raffle below.

    • No purchase required
    • Winner does NOT need to be present
    • Prize will be shipped if necessary

Button:

    Enter the Raffle

No rotating marketing slides.

This device is **only for raffle entry**.

------------------------------------------------------------------------

# Screen 2 -- Entry Form

Top element:

    ☐ I confirm that I am not employed by CypherCon or a CypherCon sponsor
      and am eligible under the raffle rules.

Until checked: - All fields disabled - Submit disabled

Fields:

Required:

-   First Name
-   Last Name
-   Work Email
-   Company (or School / Independent)
-   Job Title (or Student / Researcher / etc.)

Optional:

Interest Areas (multi-select checkboxes)

Options:

-   Penetration Testing
-   Red Team / Adversary Simulation
-   Application Security
-   Cloud & Infrastructure Security
-   Hardware / IoT Security
-   Space Systems Security
-   Security Training

Form behavior:

-   Large touch-friendly fields
-   Large tap targets
-   Clear spacing

Header button (upper-right):

    Rules & Drawing Info

Opens modal overlay.

------------------------------------------------------------------------

# Screen 3 -- Rules & Drawing Info Modal

Content:

## Raffle Rules

• One entry per person\
• Entrants must provide accurate contact information\
• Employees of CypherCon and CypherCon sponsors are not eligible\
• Winner does not need to be present\
• Prize will be shipped after the event if necessary\
• Winner must respond within **2 business days** of notification\
• Fraudulent or duplicate entries may be disqualified\
• Void where prohibited by law

## Winner Selection

After CypherCon, Final Frontier Security will perform the drawing from
the pool of eligible entries.

The winner will be selected using the operating system's
**cryptographically secure random number generator**, ensuring the
selection is unbiased and unpredictable.

The draw event and eligible entry count are recorded.

------------------------------------------------------------------------

# Screen 4 -- Success Screen

Displayed after submission.

    You're entered in the raffle.

    The winner will be contacted by email after CypherCon.
    The prize will be shipped if you are not present.

Button:

    Start New Entry

No auto-dismiss.

------------------------------------------------------------------------

# 5. Form Behavior Rules

## Duplicate Policy

Public rule:

    One entry per person.

Backend duplicate detection should flag:

-   identical email
-   name + company combinations

Duplicates are **flagged but not blocked**.

Blocking at kiosk could create awkward interactions.

------------------------------------------------------------------------

# 6. Data Model

## entrants table

Fields:

    id
    first_name          (string, required)
    last_name           (string, required)
    email               (string, required, indexed)
    company             (string, required)
    job_title           (string, required)
    interest_areas      (JSON array column, default: [])
    eligibility_confirmed (boolean, default: false)
    eligibility_status  (string, default: "eligible", indexed)
    exclusion_reason    (string, nullable)
    created_at
    updated_at

Composite index on `(first_name, last_name, company)` for duplicate detection.

## raffle_draws table

Audit log of draw events:

    id
    winner_id           (foreign key → entrants)
    eligible_count      (integer, snapshot at draw time)
    draw_type           (string: "winner" or "alternate_winner")
    admin_note          (text, nullable)
    created_at
    updated_at

## eligibility_status values

    eligible                — default on submission
    self_attested_ineligible — checkbox not confirmed (edge case guard)
    duplicate_review        — auto-flagged by duplicate detection
    excluded_admin          — manually excluded by admin
    reinstated_admin        — manually reinstated by admin
    winner                  — selected by raffle draw
    alternate_winner        — selected as alternate

------------------------------------------------------------------------

# 7. Admin Console

Password-protected at `/admin`. Session-based authentication with no user
model — a single shared password stored in Rails encrypted credentials
(falls back to `dev-password` in development).

Hidden access from kiosk screens:
- **Tap target** — tap the dot in the bottom-right corner 5 times within 1.5 seconds
- **Keyboard shortcut** — `Ctrl+Shift+A`

Capabilities:

-   View entries (sortable, searchable)
-   Export CSV (eligible entries, all entries, or winners/alternates)
-   Flag duplicates
-   Mark exclusions (with preset reason buttons)
-   Reinstate entries
-   View eligible entry count
-   Run raffle drawing (winner + alternates)
-   Display winner with celebration overlay
-   View backup status

------------------------------------------------------------------------

# 8. Raffle Drawing Process

Admin interface should show:

    Total entries
    Eligible entries
    Excluded entries

Steps:

1.  Staff review eligibility list
2.  Staff initiate drawing
3.  System freezes eligible pool
4.  System selects winner

Random selection method:

Use **OS cryptographically secure RNG**.

Implementation examples:

Ruby:

    SecureRandom.random_number

or equivalent OS entropy source.

Log:

-   timestamp
-   eligible entry count
-   selected entrant ID

Winner record flagged.

------------------------------------------------------------------------

# 9. Data Integrity Strategy

Three layers:

1.  **SQLite in WAL mode** — crash resilience, concurrent read support
2.  **Append-only JSONL submission log** (`log/submissions.jsonl`) — one JSON
    line per submission, flushed immediately. Allows full DB reconstruction
    if the database is lost.
3.  **USB backup** — systemd timer every 5 minutes copies the database
    (via SQLite `.backup` command) and the JSONL log to a USB drive labeled
    `RAFFLE_BACKUP`. The drive auto-mounts via udev rules.

Admin dashboard displays:

    Last backup time
    Backup status (success / drive missing / error)
    Total entries

------------------------------------------------------------------------

# 10. Export

Admin can export:

CSV file containing:

    first_name
    last_name
    email
    company
    job_title
    interest_areas
    created_at
    eligibility_status

Two export modes recommended:

1.  Clean export (business use)
2.  Raw archival export

------------------------------------------------------------------------

# 11. Offline Operation

The system must work **without internet**.

No external APIs.

No authentication providers.

All functionality local.

------------------------------------------------------------------------

# 12. Kiosk Behavior

Form auto-reset rules:

If no input for **90 seconds**:

-   clear form
-   return to attract screen

Prevents abandoned entries.

------------------------------------------------------------------------

# 13. Raspberry Pi Deployment

Environment:

-   Raspberry Pi 4 (4 GB RAM)
-   Raspberry Pi OS 64‑bit (Debian Trixie)
-   Wayfire compositor
-   Chromium kiosk mode

### User Separation

-   **`kiosk` user** — no sudo, no password, auto-login. Runs only the
    Wayfire compositor and Chromium. Escaping Chromium lands in an
    unprivileged session with no access to the database or sudo.
-   **`andre` user** — runs the Rails app via systemd, owns the database,
    SSH access, sudo.

### Boot Sequence

1.  Pi auto-logins `kiosk` user to Wayfire desktop
2.  Wayfire config blocks keyboard shortcuts (Alt+F4, Ctrl+W, Ctrl+Q, etc.)
3.  systemd service starts Rails on `127.0.0.1:3000` under `andre` user
4.  Wayfire autostart launches Chromium kiosk pointing to localhost:3000

No navigation controls.

### Setup Script

`bin/setup_kiosk` is an idempotent bash script that configures a fresh Pi:

-   Installs system packages via apt
-   Creates `kiosk` user (auto-login, no privileges)
-   Installs rbenv + Ruby
-   Deploys the app (bundle install, db:migrate, asset precompile)
-   Installs systemd services (Rails app + USB backup timer)
-   Configures Wayfire compositor lockdown
-   Sets up Chromium kiosk launch
-   Installs udev rules for USB auto-mount

### Emergency Access

-   SSH into Pi as `andre`
-   Or `Ctrl+Alt+F2` to TTY, login as `andre`
-   VNC via SSH tunnel (bound to localhost only)

------------------------------------------------------------------------

# 14. Security Considerations

Because CypherCon attendees include security professionals:

System should minimize attack surface.

Key protections:

-   No network services exposed
-   Rails bound to localhost only
-   Browser kiosk mode
-   Disabled autofill
-   Disabled password storage
-   Automatic form reset

Data integrity more important than secrecy.

------------------------------------------------------------------------

# 15. Non-Goals

The application is NOT:

-   a CRM
-   a marketing display
-   a lead scoring system
-   a cloud system

It is strictly:

**Raffle entry and lead capture.**

------------------------------------------------------------------------

# 16. Project Tracking

Implementation tasks are tracked as **GitHub Issues** on the repository.

All work should reference and update the corresponding GitHub issue:
- Reference issues in commit messages (e.g., `Closes #3`)
- Close issues when the task is complete
- Add comments to issues for progress notes or decisions made during implementation

Issue list: https://github.com/AndreRobitaille/RaffleEntryCollector/issues

------------------------------------------------------------------------

# 17. References

- `docs/plans/2026-03-14-architecture-design.md` — Architecture decisions
- `docs/plans/2026-03-14-implementation-plan.md` — Step-by-step implementation plan
- `CLAUDE.md` — Development guide for AI-assisted coding

------------------------------------------------------------------------

End of development plan.
