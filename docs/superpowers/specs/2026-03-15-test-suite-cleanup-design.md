# Test Suite Run and Cleanup — Design Spec

**Task:** GitHub Issue #17 — Full Test Suite Run and Cleanup
**Date:** 2026-03-15
**Approach:** Comprehensive hardening (fix failures + fill coverage gaps + edge cases)

---

## Current State

- 103 tests, 1 failure (`UsbBackupTest#test_copies_JSONL_log_if_it_exists`)
- Rubocop: clean (0 offenses)
- Brakeman: clean (0 warnings)
- Good coverage across models, controllers, services, and system tests
- Key gaps: untested scopes, pagination, input edge cases, service stubbing

## Related Issues Filed

- **#22** — Restrict text fields to standard US characters (future work)
- **#23** — Strip whitespace from email before validation (future work)

---

## Section 1: Fix Failing UsbBackup Test

**Problem:** `UsbBackup.perform` calls the `sqlite3` CLI to do a `.backup` command. In parallel test execution, the test DB may be locked or inaccessible to the CLI tool. The JSONL copy test doesn't care about the sqlite3 backup — it just wants to verify the log file gets copied.

**Fix:**
- Extract the sqlite3 backup step into a private method (`backup_database`) on `UsbBackup`
- In tests that aren't specifically testing the backup command, stub `backup_database` to return `true`
- The "performs backup when target dir exists" and "sqlite3 failure" tests keep the real CLI call
- The JSONL test stubs the backup so it can focus on log file copying behavior in isolation

---

## Section 2: Model Test Gaps

### Entrant Scopes
- Test `Entrant.duplicates` returns only `duplicate_review` entries
- Test `Entrant.excluded` returns only `excluded_admin` entries
- Verify neither scope leaks other statuses

### Entrant Association
- Test `has_many :raffle_draws` — create an entrant, draw them, confirm `entrant.raffle_draws` returns the draw

### RaffleDraw Validations
- Test `validates :draw_type, inclusion:` rejects invalid values
- Test `validates :eligible_count` rejects nil/missing values

---

## Section 3: Controller Test Gaps

### Pagination (Admin::EntriesController)
- Page 1 returns first batch of results
- Page 2 returns next batch
- Out-of-range page handles gracefully
- Page param combined with search filters

### Entries Edge Cases
- Show for non-existent entry (404/redirect behavior)
- Sorting by invalid column falls back to default
- Search with special characters works (quotes, ampersands return results normally)
- Search input is properly sanitized — verify no raw HTML/SQL passes through to the response (XSS/injection protection)

### Raffle Controller
- Draw with 0 eligible entries shows appropriate error
- Draw when only 1 eligible entry remaining — that entry becomes winner, then next draw attempt fails (no remaining eligible entries for alternates)

---

## Section 4: System Test Additions

### Form Validation Errors
- Submit entry form with missing required fields, verify error messages appear
- Submit with invalid email format, verify rejection
- Verify form retains entered values after validation failure

### Interest Area Selection
- Check interest area boxes, submit, verify they're persisted on the created entrant

### Eligibility Gate Edge Cases
- Check eligibility, fill form, uncheck eligibility — verify fields disable and submit button is disabled

---

## Section 5: Service Test Hardening

### UsbBackup
- Stub `find_usb_mount` returning a valid path — verify `perform` attempts backup
- Stub `find_usb_mount` returning nil — verify `perform` returns failure cleanly
- Backup succeeds when JSONL log doesn't exist (only DB is copied)
- Backup file target already exists — verify no error (overwrite behavior)

### SubmissionLogger
- Logged JSON contains all expected fields (full field list check)
- Handles standard US characters correctly (alphanumeric, common symbols like `@`, `-`, `'`, `.`, `&`)

### DuplicateDetector
- Whitespace in email is handled (trimmed before comparison)
- Nil/blank company doesn't cause false name+company match

### CSV Export (via controller tests)
- Special characters in entry data (commas, quotes) produce valid CSV
- Empty result set returns CSV with just headers
- Large dataset (200+ entries) exports without error

---

## Out of Scope

- Input character restriction (tracked in #22)
- Email whitespace stripping (tracked in #23)
- Performance/load testing
- Accessibility/screen reader testing
- Hardware-specific testing (actual Pi touchscreen)
