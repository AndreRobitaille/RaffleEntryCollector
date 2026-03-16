# Admin Management Page Design

## Overview

A single admin page at `/admin/management` providing four operational actions for managing raffle state, demo data, and full resets. Accessible from the admin nav bar alongside Entries, Export, and Raffle.

## Actions

### 1. Reset Drawing

- Resets all `winner` and `alternate_winner` entrant statuses back to `eligible` (note: entrants who were `reinstated_admin` before the draw lose that distinction — acceptable since reinstatement history is not tracked)
- Deletes all `raffle_draws` records
- Both operations wrapped in a single database transaction
- Result: raffle page returns to pre-draw state, all entrants preserved
- **Confirmation:** standard browser confirm dialog ("Are you sure?")

### 2. Populate Demo Data

- Inserts 300 realistic, varied demo entrants into the database
- **Precondition:** database must be empty (no entrants exist) — button disabled client-side AND enforced server-side (return error if entrants exist at request time)
- Demo entrants should have varied names, companies, job titles, interest areas, and creation timestamps
- Runs through the normal Entrant model (validations apply, but skip duplicate detection and submission logging)
- **Confirmation:** standard browser confirm dialog

### 3. Clear Entrants

- Deletes all entrants and raffle_draws from the database (in a single transaction)
- Preserves submission logs and USB backups
- Before clearing: timestamps the current `log/submissions.jsonl` by renaming it to `log/submissions-YYYYMMDD-HHMMSS.jsonl` (prevents future submissions from appending to old data)
- Order of operations: rename log file first, then delete DB records in a transaction. If the DB delete fails after rename, the timestamped log is harmlessly preserved.
- **Confirmation:** typed confirmation — user must type "reset" into a text field

### 4. Factory Reset

- Deletes all entrants and raffle_draws from the database
- Deletes all submission log files in `log/submissions*.jsonl`
- Deletes USB backup files on the mounted USB: `raffle.sqlite3` and all `submissions*.jsonl` files (including any timestamped archives from prior Clear Entrants cycles)
- **Confirmation:** typed confirmation — user must type "delete everything" into a text field

## Log Timestamping Detail

The current `SubmissionLogger` writes to a fixed path `log/submissions.jsonl`. When "Clear Entrants" is triggered:

1. If `log/submissions.jsonl` exists and is non-empty, rename it to `log/submissions-YYYYMMDD-HHMMSS.jsonl`
2. Future submissions will create a fresh `log/submissions.jsonl`

This ensures old conference data is preserved in the log directory even after clearing the database. The USB backup service copies `submissions.jsonl` — timestamped archives stay in the log directory as additional safety.

## Page Layout

Single page, two sections:

**Raffle section:**
- Reset Drawing card — description + button

**Data section:**
- Populate Demo Data card — description + button (disabled if entrants exist)
- Clear Entrants card — description + typed confirmation + button, red-tinted border
- Factory Reset card — description + typed confirmation + button, stronger red styling

Destructive actions escalate visually down the page (neutral → light red → deep red).

## Route & Controller

- Route: `GET /admin/management` → `Admin::ManagementController#show`
- Actions as POST endpoints:
  - `POST /admin/management/reset_drawing`
  - `POST /admin/management/populate_demo`
  - `POST /admin/management/clear_entrants`
  - `POST /admin/management/factory_reset`
- Controller inherits from `Admin::BaseController` (gets admin auth for free)

## Demo Data Generation

A service class `DemoPopulator` generates 300 entrants with:
- Realistic first/last names from a hardcoded pool (diverse, varied)
- Realistic company names (mix of tech, security, consulting firms)
- Realistic job titles relevant to security/IT
- Random subsets of interest areas
- `eligibility_confirmed: true`, `eligibility_status: "eligible"`
- Spread of `created_at` timestamps across a plausible range
- Uses `insert_all` for performance on Pi 4 (single bulk insert, skip individual validations/callbacks)
- `interest_areas` must be manually JSON-serialized (e.g., `JSON.generate(array)`) in the `insert_all` payload since ActiveRecord serialization is bypassed

## Testing

- Controller tests for each action (happy path + precondition failures)
- Model/service tests for DemoPopulator
- Test that Clear Entrants timestamps the log file
- Test that Factory Reset removes log files and USB backup files
- Test that Reset Drawing clears both entrant statuses and raffle_draws records
