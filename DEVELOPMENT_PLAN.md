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

**Ruby on Rails**

Reasons: - Fast to build reliable forms and admin interfaces - Excellent
SQLite support - Easy CSV export - Mature ecosystem - Clean separation
of models, views, controllers

## Database

**SQLite**

Reasons: - Reliable embedded database - Perfect for single-device
usage - No network dependencies - Easy backup and export

SQLite should run in **WAL mode**.

## Frontend

Local Rails web application rendered in **Chromium kiosk mode**.

Advantages: - Modern UI - Easy responsive layout - Touchscreen
friendly - Easy form handling

## Deployment Model

The system runs:

    Rails app (localhost)
    ↓
    SQLite database
    ↓
    Chromium kiosk browser

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

Footer button:

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
    first_name
    last_name
    email
    company
    job_title
    interest_areas (array or join table)
    eligibility_confirmed (boolean)
    created_at
    updated_at
    eligibility_status
    exclusion_reason

## eligibility_status values

    eligible
    self_attested_ineligible
    duplicate_review
    excluded_admin
    reinstated_admin
    winner
    alternate_winner

------------------------------------------------------------------------

# 7. Admin Console

Hidden access (password or keyboard shortcut).

Capabilities:

-   View entries
-   Search entries
-   Export CSV
-   Flag duplicates
-   Mark exclusions
-   Reinstate entries
-   View eligible entry count
-   Run raffle drawing
-   Display winner
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

Primary storage:

SQLite database on Raspberry Pi.

Backup layers:

1.  Local database
2.  Append-only submission log
3.  Periodic database copy to USB drive (if present)

USB mounted via **filesystem UUID**.

Admin dashboard must display:

    Last backup time
    Backup status
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

-   Raspberry Pi 4
-   Raspberry Pi OS (64‑bit)
-   Chromium kiosk mode

Boot sequence:

1.  System boots
2.  Rails server starts
3.  Chromium launches in kiosk mode
4.  Browser loads localhost app

No navigation controls.

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
