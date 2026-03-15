# Test Suite Cleanup Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the flaky UsbBackup test, fill coverage gaps across models/controllers/services/system tests, and harden edge cases — bringing the suite to zero failures with comprehensive coverage.

**Architecture:** All changes are test-only except two small production code changes: (1) extract `backup_database` method in `UsbBackup` for testability, (2) add `numericality` validation to `RaffleDraw#eligible_count`. Tests use Minitest + fixtures + parallel execution.

**Tech Stack:** Ruby 4.0, Rails 8.1, Minitest, Capybara (system tests), SQLite3

**Spec:** `docs/superpowers/specs/2026-03-15-test-suite-cleanup-design.md`

---

## Chunk 1: UsbBackup Fix + Service Test Hardening

### Task 1: Extract `backup_database` method in UsbBackup

**Files:**
- Modify: `app/services/usb_backup.rb:12-17`

- [ ] **Step 1: Extract backup_database private method**

In `app/services/usb_backup.rb`, replace the inline `system()` call with a method:

```ruby
def self.perform(target_dir: find_usb_mount)
  return failure("No backup target found") unless target_dir && Dir.exist?(target_dir.to_s)

  db_path = ActiveRecord::Base.connection_db_config.database
  backup_db_path = File.join(target_dir, "raffle.sqlite3")

  unless backup_database(db_path, backup_db_path)
    return failure("sqlite3 backup command failed")
  end

  log_path = Rails.root.join("log", "submissions.jsonl")
  if log_path.exist?
    FileUtils.cp(log_path, File.join(target_dir, "submissions.jsonl"))
  end

  record_status(success: true)
  { success: true, backed_up_at: Time.current }
rescue => e
  record_status(success: false, error: e.message)
  failure(e.message)
end

def self.backup_database(db_path, backup_db_path)
  system("sqlite3", db_path, ".backup '#{backup_db_path}'")
end
private_class_method :backup_database
```

- [ ] **Step 2: Run existing UsbBackup tests to confirm no regression**

Run: `bin/rails test test/services/usb_backup_test.rb`
Expected: All 7 existing tests pass (the extraction is a pure refactor).

- [ ] **Step 3: Commit**

```bash
git add app/services/usb_backup.rb
git commit -m "refactor: extract backup_database method in UsbBackup for testability (Issue #17)"
```

### Task 2: Fix flaky JSONL test + add UsbBackup coverage

**Files:**
- Modify: `test/services/usb_backup_test.rb`

- [ ] **Step 1: Rewrite the JSONL test to stub backup_database**

Replace the existing "copies JSONL log if it exists" test:

```ruby
test "copies JSONL log if it exists" do
  log_path = Rails.root.join("log", "submissions.jsonl")
  File.write(log_path, "{\"test\": true}\n")

  UsbBackup.stub(:backup_database, true) do
    result = UsbBackup.perform(target_dir: @backup_dir)
    assert result[:success]
    assert File.exist?(File.join(@backup_dir, "submissions.jsonl"))
  end
ensure
  log_path.delete if log_path.exist?
end
```

- [ ] **Step 2: Run the fixed test**

Run: `bin/rails test test/services/usb_backup_test.rb:21`
Expected: PASS (no more sqlite3 interference)

- [ ] **Step 3: Add test for backup when JSONL log doesn't exist**

```ruby
test "succeeds without JSONL log file" do
  log_path = Rails.root.join("log", "submissions.jsonl")
  log_path.delete if log_path.exist?

  UsbBackup.stub(:backup_database, true) do
    result = UsbBackup.perform(target_dir: @backup_dir)
    assert result[:success]
    assert_not File.exist?(File.join(@backup_dir, "submissions.jsonl"))
  end
end
```

- [ ] **Step 4: Add test for find_usb_mount returning nil**

```ruby
test "returns failure when find_usb_mount returns nil" do
  UsbBackup.stub(:find_usb_mount, nil) do
    result = UsbBackup.perform
    assert_not result[:success]
    assert_equal "No backup target found", result[:error]
  end
end
```

- [ ] **Step 5: Add test for find_usb_mount returning a valid path**

```ruby
test "uses find_usb_mount result as target_dir when not specified" do
  UsbBackup.stub(:find_usb_mount, @backup_dir) do
    UsbBackup.stub(:backup_database, true) do
      result = UsbBackup.perform
      assert result[:success]
    end
  end
end
```

- [ ] **Step 6: Add test for overwriting existing backup file**

```ruby
test "overwrites existing backup file without error" do
  File.write(File.join(@backup_dir, "raffle.sqlite3"), "old data")

  UsbBackup.stub(:backup_database, true) do
    result = UsbBackup.perform(target_dir: @backup_dir)
    assert result[:success]
  end
end
```

- [ ] **Step 7: Run all UsbBackup tests**

Run: `bin/rails test test/services/usb_backup_test.rb`
Expected: All 11 tests pass (7 existing + 4 new)

- [ ] **Step 8: Commit**

```bash
git add test/services/usb_backup_test.rb
git commit -m "test: fix flaky JSONL test and add UsbBackup coverage (Issue #17)"
```

### Task 3: SubmissionLogger test hardening

**Files:**
- Modify: `test/services/submission_logger_test.rb`

- [ ] **Step 1: Add full field list test**

```ruby
test "logged JSON contains all expected fields" do
  entrant = Entrant.create!(
    first_name: "Ada", last_name: "Lovelace", email: "ada@example.com",
    company: "Babbage", job_title: "Eng", eligibility_confirmed: true,
    interest_areas: ["Application Security"]
  )

  SubmissionLogger.log(entrant, log_path: @log_path)

  data = JSON.parse(@log_path.readlines.first)
  expected_keys = %w[id first_name last_name email company job_title interest_areas eligibility_confirmed created_at logged_at]
  assert_equal expected_keys.sort, data.keys.sort
end
```

- [ ] **Step 2: Add standard US characters test**

```ruby
test "handles standard US characters in fields" do
  entrant = Entrant.create!(
    first_name: "O'Brien", last_name: "Smith-Jones", email: "ob@example.com",
    company: "AT&T Corp.", job_title: "Sr. Engineer", eligibility_confirmed: true
  )

  SubmissionLogger.log(entrant, log_path: @log_path)

  data = JSON.parse(@log_path.readlines.first)
  assert_equal "O'Brien", data["first_name"]
  assert_equal "Smith-Jones", data["last_name"]
  assert_equal "AT&T Corp.", data["company"]
  assert_equal "Sr. Engineer", data["job_title"]
end
```

- [ ] **Step 3: Run SubmissionLogger tests**

Run: `bin/rails test test/services/submission_logger_test.rb`
Expected: All 4 tests pass

- [ ] **Step 4: Commit**

```bash
git add test/services/submission_logger_test.rb
git commit -m "test: add SubmissionLogger field coverage and character handling tests (Issue #17)"
```

### Task 4: DuplicateDetector whitespace documentation test

**Files:**
- Modify: `test/services/duplicate_detector_test.rb`

- [ ] **Step 1: Add whitespace documentation test**

This test documents that whitespace-padded emails do NOT currently match, confirming Issue #23 is needed:

```ruby
test "whitespace-padded email does not match trimmed counterpart (see Issue #23)" do
  Entrant.create!(first_name: "Ada", last_name: "Lovelace", email: "ada@example.com",
                  company: "Babbage", job_title: "Eng", eligibility_confirmed: true)
  padded = Entrant.create!(first_name: "X", last_name: "Y", email: " ada@example.com ",
                           company: "Other", job_title: "Dev", eligibility_confirmed: true)

  DuplicateDetector.check(padded)

  # This SHOULD flag a duplicate but doesn't because email isn't stripped.
  # When Issue #23 is resolved, change this assertion to assert_equal "duplicate_review"
  assert_equal "eligible", Entrant.find_by(email: "ada@example.com").eligibility_status
end
```

- [ ] **Step 2: Run DuplicateDetector tests**

Run: `bin/rails test test/services/duplicate_detector_test.rb`
Expected: All 10 tests pass

- [ ] **Step 3: Commit**

```bash
git add test/services/duplicate_detector_test.rb
git commit -m "test: document whitespace email gap in DuplicateDetector (Issue #17, see #23)"
```

---

## Chunk 2: Model Test Gaps

### Task 5: Entrant scope tests

**Files:**
- Modify: `test/models/entrant_test.rb`

- [ ] **Step 1: Add duplicates scope test**

```ruby
test "scope duplicates returns only duplicate_review entries" do
  attrs = { company: "X", job_title: "X", eligibility_confirmed: true }
  duplicate = Entrant.create!(first_name: "A", last_name: "A", email: "a@x.com", eligibility_status: "duplicate_review", **attrs)
  eligible = Entrant.create!(first_name: "B", last_name: "B", email: "b@x.com", eligibility_status: "eligible", **attrs)
  excluded = Entrant.create!(first_name: "C", last_name: "C", email: "c@x.com", eligibility_status: "excluded_admin", **attrs)

  result = Entrant.duplicates
  assert_includes result, duplicate
  assert_not_includes result, eligible
  assert_not_includes result, excluded
end
```

- [ ] **Step 2: Add excluded scope test**

```ruby
test "scope excluded returns only excluded_admin entries" do
  attrs = { company: "X", job_title: "X", eligibility_confirmed: true }
  excluded = Entrant.create!(first_name: "A", last_name: "A", email: "a@x.com", eligibility_status: "excluded_admin", **attrs)
  eligible = Entrant.create!(first_name: "B", last_name: "B", email: "b@x.com", eligibility_status: "eligible", **attrs)
  duplicate = Entrant.create!(first_name: "C", last_name: "C", email: "c@x.com", eligibility_status: "duplicate_review", **attrs)

  result = Entrant.excluded
  assert_includes result, excluded
  assert_not_includes result, eligible
  assert_not_includes result, duplicate
end
```

- [ ] **Step 3: Add association test**

```ruby
test "has_many raffle_draws returns draws where entrant is winner" do
  attrs = { company: "X", job_title: "X", eligibility_confirmed: true }
  entrant = Entrant.create!(first_name: "A", last_name: "A", email: "a@x.com", **attrs)
  draw = RaffleDraw.create!(winner: entrant, eligible_count: 5, draw_type: "winner")

  assert_includes entrant.raffle_draws, draw
end
```

- [ ] **Step 4: Run Entrant tests**

Run: `bin/rails test test/models/entrant_test.rb`
Expected: All 17 tests pass (14 existing + 3 new)

- [ ] **Step 5: Commit**

```bash
git add test/models/entrant_test.rb
git commit -m "test: add Entrant scope and association tests (Issue #17)"
```

### Task 6: RaffleDraw validation tests + eligible_count numericality

**Files:**
- Modify: `app/models/raffle_draw.rb:6`
- Modify: `test/models/raffle_draw_test.rb`

- [ ] **Step 1: Write failing test for eligible_count: 0**

Add to `test/models/raffle_draw_test.rb`:

```ruby
test "rejects eligible_count of zero" do
  entrant = Entrant.create!(first_name: "A", last_name: "A", email: "a@x.com",
                            company: "X", job_title: "X", eligibility_confirmed: true)
  draw = RaffleDraw.new(winner: entrant, eligible_count: 0, draw_type: "winner")
  assert_not draw.valid?
  assert_includes draw.errors[:eligible_count], "must be greater than 0"
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `bin/rails test test/models/raffle_draw_test.rb -n "test_rejects_eligible_count_of_zero"`
Expected: FAIL — current validation only checks `presence: true`, and `0` is present.

- [ ] **Step 3: Add numericality validation to RaffleDraw**

In `app/models/raffle_draw.rb`, change line 6:

```ruby
validates :eligible_count, presence: true, numericality: { greater_than: 0 }
```

- [ ] **Step 4: Run to verify it passes**

Run: `bin/rails test test/models/raffle_draw_test.rb -n "test_rejects_eligible_count_of_zero"`
Expected: PASS

- [ ] **Step 5: Add draw_type validation test**

```ruby
test "rejects invalid draw_type" do
  entrant = Entrant.create!(first_name: "A", last_name: "A", email: "a@x.com",
                            company: "X", job_title: "X", eligibility_confirmed: true)
  draw = RaffleDraw.new(winner: entrant, eligible_count: 5, draw_type: "invalid")
  assert_not draw.valid?
  assert_includes draw.errors[:draw_type], "is not included in the list"
end
```

- [ ] **Step 6: Add eligible_count nil test**

```ruby
test "rejects nil eligible_count" do
  entrant = Entrant.create!(first_name: "A", last_name: "A", email: "a@x.com",
                            company: "X", job_title: "X", eligibility_confirmed: true)
  draw = RaffleDraw.new(winner: entrant, eligible_count: nil, draw_type: "winner")
  assert_not draw.valid?
  assert draw.errors[:eligible_count].any?
end
```

- [ ] **Step 7: Run all RaffleDraw tests**

Run: `bin/rails test test/models/raffle_draw_test.rb`
Expected: All 9 tests pass (6 existing + 3 new)

- [ ] **Step 8: Commit**

```bash
git add app/models/raffle_draw.rb test/models/raffle_draw_test.rb
git commit -m "feat: add eligible_count numericality validation + RaffleDraw test coverage (Issue #17)"
```

---

## Chunk 3: Controller Test Gaps

### Task 7: Entries pagination tests

**Files:**
- Modify: `test/controllers/admin/entries_controller_test.rb`

Note: `PER_PAGE = 50` and fixtures provide 7 entries. We'll create enough entries to test pagination boundaries.

- [ ] **Step 1: Add pagination helper method and tests**

Add these tests to `test/controllers/admin/entries_controller_test.rb`:

```ruby
test "GET /admin/entries page 1 returns entries" do
  login_as_admin
  get admin_entries_path, params: { page: 1 }
  assert_response :success
  assert_select "table tbody tr", minimum: 1
end

test "GET /admin/entries page 2 returns next batch after creating enough entries" do
  login_as_admin
  51.times do |i|
    Entrant.create!(first_name: "Page#{i}", last_name: "Test", email: "page#{i}@x.com",
                    company: "X", job_title: "X", eligibility_confirmed: true)
  end
  get admin_entries_path, params: { page: 2 }
  assert_response :success
  # Page 2 should have the overflow entries (total > 50, so page 2 is non-empty)
  assert_select "table tbody tr", minimum: 1
end

test "GET /admin/entries out-of-range page returns empty table body" do
  login_as_admin
  get admin_entries_path, params: { page: 999 }
  assert_response :success
  assert_select "table tbody tr", count: 0
end

test "GET /admin/entries page param combined with search" do
  login_as_admin
  get admin_entries_path, params: { q: "Ada", page: 1 }
  assert_response :success
  assert_select "table tr td", text: "Ada"
end
```

- [ ] **Step 2: Run pagination tests**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add test/controllers/admin/entries_controller_test.rb
git commit -m "test: add pagination tests for Admin::EntriesController (Issue #17)"
```

### Task 8: Entries edge case tests

**Files:**
- Modify: `test/controllers/admin/entries_controller_test.rb`

- [ ] **Step 1: Add non-existent entry test**

```ruby
test "GET /admin/entries/:id for non-existent entry raises RecordNotFound" do
  login_as_admin
  assert_raises(ActiveRecord::RecordNotFound) do
    get admin_entry_path(id: 999999)
  end
end
```

- [ ] **Step 2: Add invalid sort column test**

```ruby
test "GET /admin/entries with invalid sort column falls back to default" do
  login_as_admin
  get admin_entries_path, params: { sort: "DROP TABLE entrants", dir: "asc" }
  assert_response :success
  # Falls back to default sort (company) — page renders without error
  assert_select "table tbody tr", minimum: 1
end
```

- [ ] **Step 3: Add special characters in search test**

```ruby
test "GET /admin/entries search with special characters returns safely" do
  login_as_admin
  get admin_entries_path, params: { q: "O'Brien & \"Co\" <script>" }
  assert_response :success
  # No error, no unescaped HTML in response
  refute_includes response.body, "<script>"
end
```

- [ ] **Step 4: Run entries controller tests**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add test/controllers/admin/entries_controller_test.rb
git commit -m "test: add entries edge case tests for sort, search, 404 (Issue #17)"
```

### Task 9: Raffle controller — exhaust eligible pool

**Files:**
- Modify: `test/controllers/admin/raffle_controller_test.rb`

- [ ] **Step 1: Add exhaust-pool test**

```ruby
test "draw last eligible entry then fail on next draw" do
  # Exclude all but one eligible entry
  Entrant.eligible.where.not(id: entrants(:ada).id).update_all(eligibility_status: "excluded_admin")

  post draw_admin_raffle_path
  assert_redirected_to admin_raffle_path
  follow_redirect!
  assert_equal 1, RaffleDraw.count
  assert_equal "winner", entrants(:ada).reload.eligibility_status

  # Now no eligible entries remain
  post draw_admin_raffle_path
  assert_redirected_to admin_raffle_path
  follow_redirect!
  assert_select ".admin-flash--alert", /no eligible/i
  assert_equal 1, RaffleDraw.count
end
```

- [ ] **Step 2: Run raffle controller tests**

Run: `bin/rails test test/controllers/admin/raffle_controller_test.rb`
Expected: All 9 tests pass (8 existing + 1 new)

- [ ] **Step 3: Commit**

```bash
git add test/controllers/admin/raffle_controller_test.rb
git commit -m "test: add raffle pool exhaustion test (Issue #17)"
```

### Task 10: CSV export edge case tests

**Files:**
- Modify: `test/controllers/admin/exports_controller_test.rb`

- [ ] **Step 1: Add special characters CSV test**

```ruby
test "CSV handles special characters in entry data" do
  login_as_admin
  Entrant.create!(
    first_name: "O'Brien", last_name: 'Smith, Jr.', email: "ob@example.com",
    company: 'Acme "Corp"', job_title: "Engineer", eligibility_confirmed: true
  )

  get admin_export_download_path, params: { type: "all" }
  csv = CSV.parse(response.body, headers: true)
  row = csv.find { |r| r["email"] == "ob@example.com" }

  assert_equal "O'Brien", row["first_name"]
  assert_equal "Smith, Jr.", row["last_name"]
  assert_equal 'Acme "Corp"', row["company"]
end
```

- [ ] **Step 2: Add empty result set CSV test**

```ruby
test "CSV export with no eligible entries returns headers only" do
  login_as_admin
  Entrant.update_all(eligibility_status: "excluded_admin")

  get admin_export_download_path, params: { type: "eligible" }
  assert_response :success
  csv = CSV.parse(response.body, headers: true)
  assert_equal 0, csv.length
  assert csv.headers.include?("first_name")
end
```

- [ ] **Step 3: Add moderate dataset CSV test**

```ruby
test "CSV export handles 100 entries" do
  login_as_admin
  100.times do |i|
    Entrant.create!(
      first_name: "User#{i}", last_name: "Test", email: "user#{i}@load.com",
      company: "LoadCo", job_title: "Dev", eligibility_confirmed: true
    )
  end

  get admin_export_download_path, params: { type: "all" }
  assert_response :success
  csv = CSV.parse(response.body, headers: true)
  assert csv.length >= 100
end
```

- [ ] **Step 4: Run export controller tests**

Run: `bin/rails test test/controllers/admin/exports_controller_test.rb`
Expected: All 15 tests pass (12 existing + 3 new)

- [ ] **Step 5: Commit**

```bash
git add test/controllers/admin/exports_controller_test.rb
git commit -m "test: add CSV edge case tests for special chars, empty set, large dataset (Issue #17)"
```

---

## Chunk 4: System Test Additions

### Task 11: Form validation error system tests

**Files:**
- Modify: `test/system/kiosk_flow_test.rb`

- [ ] **Step 1: Add missing fields validation test**

```ruby
test "submitting with missing fields shows validation errors" do
  visit enter_path

  check "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules."
  fill_in "First name", with: "Ada"
  # Leave other fields blank
  click_button "Submit Entry"

  assert_selector ".form-field--error", minimum: 1
  # Form retains the value we entered
  assert_field "First name", with: "Ada"
end
```

- [ ] **Step 2: Add invalid email validation test**

```ruby
test "submitting with invalid email shows error" do
  visit enter_path

  check "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules."
  fill_in "First name", with: "Ada"
  fill_in "Last name", with: "Lovelace"
  fill_in "Work Email", with: "notanemail"
  fill_in "Company", with: "Babbage"
  fill_in "Job Title", with: "Engineer"
  click_button "Submit Entry"

  assert_selector ".form-field--error"
  assert_text "is invalid"
end
```

- [ ] **Step 3: Add interest area persistence test**

```ruby
test "selected interest areas persist after submission" do
  visit enter_path

  check "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules."
  fill_in "First name", with: "Ada"
  fill_in "Last name", with: "Lovelace"
  fill_in "Work Email", with: "ada-interest@example.com"
  fill_in "Company", with: "Babbage"
  fill_in "Job Title", with: "Engineer"
  check "Penetration Testing"
  check "Application Security"
  click_button "Submit Entry"

  assert_text "You're entered in the raffle"
  entrant = Entrant.find_by(email: "ada-interest@example.com")
  assert_includes entrant.interest_areas, "Penetration Testing"
  assert_includes entrant.interest_areas, "Application Security"
end
```

- [ ] **Step 4: Add eligibility uncheck test**

```ruby
test "unchecking eligibility after filling form disables fields and submit" do
  visit enter_path

  check "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules."
  fill_in "First name", with: "Ada"
  fill_in "Last name", with: "Lovelace"

  uncheck "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules."

  assert page.has_field?("entrant[first_name]", disabled: true)
  assert page.has_button?("Submit Entry", disabled: true)
end
```

- [ ] **Step 5: Run system tests**

Run: `bin/rails test:system`
Expected: All 11 system tests pass (7 existing + 4 new)

- [ ] **Step 6: Commit**

```bash
git add test/system/kiosk_flow_test.rb
git commit -m "test: add system tests for validation errors, interest areas, eligibility gate (Issue #17)"
```

---

## Chunk 5: Final Verification

### Task 12: Full suite run and quality checks

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass, 0 failures, 0 errors

- [ ] **Step 2: Run system tests**

Run: `bin/rails test:system`
Expected: All system tests pass

- [ ] **Step 3: Run rubocop**

Run: `bundle exec rubocop`
Expected: 0 offenses. Fix any new offenses before proceeding.

- [ ] **Step 4: Run brakeman**

Run: `bundle exec brakeman --no-pager -q`
Expected: 0 warnings

- [ ] **Step 5: Comment on GitHub issue**

```bash
gh issue comment 17 --body "All tests passing. Added coverage for: UsbBackup stubbing/isolation, Entrant scopes, RaffleDraw validations, pagination, entries edge cases (404, invalid sort, XSS), raffle pool exhaustion, CSV edge cases, system test validation errors/interest areas. Full suite green."
```

- [ ] **Step 6: Close GitHub issue**

```bash
gh issue close 17
```

- [ ] **Step 7: Final commit if any fixups needed**

Only if rubocop/brakeman required changes. Otherwise skip.
