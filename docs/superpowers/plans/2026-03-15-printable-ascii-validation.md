# Printable ASCII Validation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restrict `first_name`, `last_name`, `company`, and `job_title` fields on the Entrant model to printable ASCII characters only (space `0x20` through tilde `0x7E`).

**Architecture:** Add a `format:` validation with a constant regex and message to 4 existing `validates` lines in the Entrant model. Add tests covering valid symbols, emoji, accented characters, CJK, control characters, and newlines.

**Tech Stack:** Ruby on Rails, Minitest

**Spec:** `docs/superpowers/specs/2026-03-15-printable-ascii-validation-design.md`

---

## Chunk 1: Printable ASCII Validation

### Task 1: Add validation and tests

**Files:**
- Modify: `app/models/entrant.rb:1-10` (add constants), `app/models/entrant.rb:22-26` (add format to validates lines)
- Modify: `test/models/entrant_test.rb` (add test cases at end of file)

- [ ] **Step 1: Write failing tests**

Add these tests to the end of `test/models/entrant_test.rb` (before the final `end`):

```ruby
# Printable ASCII validation tests
test "valid with standard symbols in company and job_title" do
  entrant = Entrant.new(
    first_name: "Mary-Jane",
    last_name: "O'Brien",
    email: "mj@example.com",
    company: "AT&T (Corp.)",
    job_title: "Sr. Engineer / Team Lead",
    eligibility_confirmed: true
  )
  assert entrant.valid?
end

test "rejects emoji in first_name" do
  entrant = Entrant.new(
    first_name: "Ada \u{1F600}",
    last_name: "Lovelace",
    email: "ada@example.com",
    company: "X",
    job_title: "X",
    eligibility_confirmed: true
  )
  assert_not entrant.valid?
  assert_includes entrant.errors[:first_name], "may only contain standard characters (letters, numbers, and common symbols)"
end

test "rejects accented characters in last_name" do
  entrant = Entrant.new(
    first_name: "Rene",
    last_name: "Descartes\u00E9",
    email: "rene@example.com",
    company: "X",
    job_title: "X",
    eligibility_confirmed: true
  )
  assert_not entrant.valid?
  assert_includes entrant.errors[:last_name], "may only contain standard characters (letters, numbers, and common symbols)"
end

test "rejects CJK characters in company" do
  entrant = Entrant.new(
    first_name: "Test",
    last_name: "User",
    email: "test@example.com",
    company: "\u4E2D\u6587\u516C\u53F8",
    job_title: "X",
    eligibility_confirmed: true
  )
  assert_not entrant.valid?
  assert_includes entrant.errors[:company], "may only contain standard characters (letters, numbers, and common symbols)"
end

test "rejects null byte in job_title" do
  entrant = Entrant.new(
    first_name: "Test",
    last_name: "User",
    email: "test@example.com",
    company: "X",
    job_title: "Engineer\x00Admin",
    eligibility_confirmed: true
  )
  assert_not entrant.valid?
  assert_includes entrant.errors[:job_title], "may only contain standard characters (letters, numbers, and common symbols)"
end

test "rejects newline in first_name" do
  entrant = Entrant.new(
    first_name: "Ada\nLovelace",
    last_name: "X",
    email: "ada@example.com",
    company: "X",
    job_title: "X",
    eligibility_confirmed: true
  )
  assert_not entrant.valid?
  assert_includes entrant.errors[:first_name], "may only contain standard characters (letters, numbers, and common symbols)"
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/entrant_test.rb`
Expected: 5 new failures (the "valid with standard symbols" test should pass since those are already accepted, the other 5 should fail because no format validation exists yet).

- [ ] **Step 3: Add constants and format validation to Entrant model**

In `app/models/entrant.rb`, add constants after `INTEREST_AREA_OPTIONS`:

```ruby
PRINTABLE_ASCII = /\A[ -~]*\z/
PRINTABLE_ASCII_MESSAGE = "may only contain standard characters (letters, numbers, and common symbols)"
```

Then update the 4 validates lines to include the format option:

```ruby
validates :first_name, presence: true, format: { with: PRINTABLE_ASCII, message: PRINTABLE_ASCII_MESSAGE }
validates :last_name, presence: true, format: { with: PRINTABLE_ASCII, message: PRINTABLE_ASCII_MESSAGE }
validates :company, presence: true, format: { with: PRINTABLE_ASCII, message: PRINTABLE_ASCII_MESSAGE }
validates :job_title, presence: true, format: { with: PRINTABLE_ASCII, message: PRINTABLE_ASCII_MESSAGE }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/models/entrant_test.rb`
Expected: All tests pass (0 failures, 0 errors).

- [ ] **Step 5: Run full quality checks**

Run all three quality gates:

```bash
bin/rails test
bundle exec rubocop
bundle exec brakeman --no-pager -q
```

Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add app/models/entrant.rb test/models/entrant_test.rb
git commit -m "feat: restrict text fields to printable ASCII (Issue #22)"
```

- [ ] **Step 7: Close GitHub issue**

```bash
gh issue comment 22 -b "Added printable ASCII validation (space through tilde, 0x20-0x7E) to first_name, last_name, company, and job_title fields. Rejects emoji, accented characters, CJK, control characters, and null bytes with a clear error message. Tests cover all rejection categories plus valid symbol input."
gh issue close 22
```
