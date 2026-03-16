# Sponsor / Vendor Exclusion Modal Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a modal dialog for "Sponsor / Vendor" exclusions that offers individual or company-wide exclusion/reinstatement, with index state persistence.

**Architecture:** Stimulus controller + native `<dialog>` for the modal. New JSON endpoint for company match data. Session-based persistence for index search/sort state. All actions use standard form submissions (no AJAX for mutations).

**Tech Stack:** Rails 8, Stimulus, native HTML `<dialog>`, SQLite

**Spec:** `docs/superpowers/specs/2026-03-16-sponsor-exclusion-modal-design.md`

---

## Chunk 1: Fixtures and Index State Persistence

### Task 1: Add test fixtures for company-peer scenarios

The current fixtures don't have multiple entries from the same company. Add fixtures now so all subsequent tests can rely on them.

**Files:**
- Modify: `test/fixtures/entrants.yml`

- [ ] **Step 1: Add fixtures**

Add to `test/fixtures/entrants.yml`:

```yaml
sponsor_frank:
  first_name: Frank
  last_name: Vendor
  email: frank@sponsor.com
  company: CypherCon Sponsor LLC
  job_title: Account Executive
  eligibility_confirmed: true
  eligibility_status: eligible
  interest_areas: []

sponsor_gina:
  first_name: Gina
  last_name: Sales
  email: gina@sponsor.com
  company: CypherCon Sponsor LLC
  job_title: Sales Manager
  eligibility_confirmed: true
  eligibility_status: excluded_admin
  exclusion_reason: Sponsor / Vendor
  interest_areas: []
```

- [ ] **Step 2: Run full test suite to verify fixtures don't break anything**

Run: `bin/rails test`
Expected: All existing tests pass

- [ ] **Step 3: Commit**

```bash
git add test/fixtures/entrants.yml
git commit -m "test: add sponsor company peer fixtures for modal testing"
```

### Task 2: Session-based index state persistence

This task adds session storage for the entries index search/sort params so the admin's view is preserved when navigating away and back. This is a prerequisite for the modal redirect behavior.

**Files:**
- Modify: `app/controllers/admin/entries_controller.rb` (index action)
- Test: `test/controllers/admin/entries_controller_test.rb`

- [ ] **Step 1: Write failing tests for session persistence**

Add these tests to `test/controllers/admin/entries_controller_test.rb`:

```ruby
test "index stores search query in session" do
  login_as_admin
  get admin_entries_path, params: { q: "Ada" }
  assert_equal "Ada", session[:admin_entries_search]
end

test "index stores sort params in session" do
  login_as_admin
  get admin_entries_path, params: { sort: "last_name", dir: "desc" }
  assert_equal "last_name", session[:admin_entries_sort]
  assert_equal "desc", session[:admin_entries_direction]
end

test "index restores search from session when no params given" do
  login_as_admin
  get admin_entries_path, params: { q: "Ada" }
  get admin_entries_path
  assert_select "table tr td", text: "Ada"
  assert_select "table tr td", text: "Grace", count: 0
end

test "index restores sort from session when no params given" do
  login_as_admin
  get admin_entries_path, params: { sort: "last_name", dir: "desc" }
  get admin_entries_path
  # Should still be sorted by last_name desc
  rows = css_select("table tbody tr td:nth-child(3)")
  last_names = rows.map(&:text).map(&:strip)
  assert_equal last_names, last_names.sort.reverse
end

test "index explicit params override session state" do
  login_as_admin
  get admin_entries_path, params: { q: "Ada" }
  get admin_entries_path, params: { q: "Grace" }
  assert_select "table tr td", text: "Grace"
  assert_select "table tr td", text: "Ada", count: 0
end

test "index clears session search when visiting with empty search" do
  login_as_admin
  get admin_entries_path, params: { q: "Ada" }
  get admin_entries_path, params: { q: "" }
  assert_nil session[:admin_entries_search]
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb`
Expected: New tests fail (session keys not set, no restoration)

- [ ] **Step 3: Implement session persistence in index action**

In `app/controllers/admin/entries_controller.rb`, modify the `index` method. Add this logic at the top of the method, before the existing query/sort code:

```ruby
def index
  # Restore from session if no explicit params
  if params[:q].nil? && params[:sort].nil? && params[:dir].nil?
    params[:q] = session[:admin_entries_search] if session[:admin_entries_search].present?
    params[:sort] = session[:admin_entries_sort] if session[:admin_entries_sort].present?
    params[:dir] = session[:admin_entries_direction] if session[:admin_entries_direction].present?
  end

  # Store current state in session
  session[:admin_entries_search] = params[:q].presence
  session[:admin_entries_sort] = params[:sort].presence
  session[:admin_entries_direction] = params[:dir].presence

  # ... rest of existing index code unchanged ...
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb`
Expected: All tests pass, including existing ones

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/entries_controller.rb test/controllers/admin/entries_controller_test.rb
git commit -m "feat: persist admin entries index search/sort state in session"
```

### Task 3: Clear session state on logout

**Files:**
- Modify: `app/controllers/admin/sessions_controller.rb` (destroy action)
- Test: `test/controllers/admin/sessions_controller_test.rb`

- [ ] **Step 1: Write failing test**

Add to `test/controllers/admin/sessions_controller_test.rb` (create this file if it doesn't exist — check first):

```ruby
test "logout clears all session state including search params" do
  login_as_admin
  get admin_entries_path, params: { q: "Ada", sort: "last_name", dir: "desc" }
  delete admin_logout_path
  # Session should be fully reset
  assert_nil session[:admin_authenticated]
  assert_nil session[:admin_entries_search]
  assert_nil session[:admin_entries_sort]
  assert_nil session[:admin_entries_direction]
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/admin/sessions_controller_test.rb`
Expected: FAIL — session keys still present after logout

- [ ] **Step 3: Update destroy action to reset full session**

In `app/controllers/admin/sessions_controller.rb`, change `destroy`:

```ruby
def destroy
  reset_session
  redirect_to root_path
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/controllers/admin/sessions_controller_test.rb`
Expected: PASS

- [ ] **Step 5: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass (verify `reset_session` doesn't break anything)

- [ ] **Step 6: Commit**

```bash
git add app/controllers/admin/sessions_controller.rb test/controllers/admin/sessions_controller_test.rb
git commit -m "feat: clear all session state on admin logout"
```

---

## Chunk 2: Company Matches Endpoint

### Task 4: Add company_matches route and endpoint

This endpoint powers the modal preview — it returns matching entries from the same company.

**Files:**
- Modify: `config/routes.rb` (add member route)
- Modify: `app/controllers/admin/entries_controller.rb` (add company_matches action)
- Test: `test/controllers/admin/entries_controller_test.rb`

- [ ] **Step 1: Write failing tests for the endpoint**

Add to `test/controllers/admin/entries_controller_test.rb`:

```ruby
test "GET company_matches without auth redirects to login" do
  get company_matches_admin_entry_path(entrants(:ada))
  assert_redirected_to admin_login_path
end

test "GET company_matches for exclude context returns eligible entries from same company" do
  login_as_admin
  # Create additional entries from same company as ada (Babbage Inc)
  peer = Entrant.create!(
    first_name: "Charles", last_name: "Babbage", email: "charles@babbage.com",
    company: "Babbage Inc", job_title: "Inventor", eligibility_confirmed: true
  )
  get company_matches_admin_entry_path(entrants(:ada)), params: { context: "exclude" }
  assert_response :success
  json = JSON.parse(response.body)
  assert_equal "Babbage Inc", json["company"]
  assert_equal 2, json["count"]
  assert json["entries"].any? { |e| e["first_name"] == "Ada" }
  assert json["entries"].any? { |e| e["first_name"] == "Charles" }
end

test "GET company_matches for exclude context excludes already-excluded entries" do
  login_as_admin
  # excluded_eve is excluded_admin — should not appear in exclude context
  # sponsor_frank is eligible (same company), sponsor_gina is excluded_admin
  get company_matches_admin_entry_path(entrants(:excluded_eve)), params: { context: "exclude" }
  assert_response :success
  json = JSON.parse(response.body)
  assert_equal 1, json["count"]  # only sponsor_frank (eligible)
  assert json["entries"].any? { |e| e["first_name"] == "Frank" }
end

test "GET company_matches for reinstate context returns excluded entries from same company" do
  login_as_admin
  # excluded_eve and sponsor_gina are both excluded_admin from CypherCon Sponsor LLC
  get company_matches_admin_entry_path(entrants(:excluded_eve)), params: { context: "reinstate" }
  assert_response :success
  json = JSON.parse(response.body)
  assert_equal "CypherCon Sponsor LLC", json["company"]
  assert_equal 2, json["count"]  # excluded_eve + sponsor_gina
end

test "GET company_matches uses case-insensitive company matching" do
  login_as_admin
  Entrant.create!(
    first_name: "Lower", last_name: "Case", email: "lower@babbage.com",
    company: "babbage inc", job_title: "Tester", eligibility_confirmed: true
  )
  get company_matches_admin_entry_path(entrants(:ada)), params: { context: "exclude" }
  json = JSON.parse(response.body)
  assert_equal 2, json["count"]  # ada + the lowercase entry
end

test "GET company_matches limits entries array to 3" do
  login_as_admin
  4.times do |i|
    Entrant.create!(
      first_name: "Person#{i}", last_name: "Test", email: "p#{i}@babbage.com",
      company: "Babbage Inc", job_title: "Tester", eligibility_confirmed: true
    )
  end
  get company_matches_admin_entry_path(entrants(:ada)), params: { context: "exclude" }
  json = JSON.parse(response.body)
  assert_equal 5, json["count"]  # ada + 4 new
  assert_equal 3, json["entries"].length
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb -n /company_matches/`
Expected: All fail with routing error (route doesn't exist yet)

- [ ] **Step 3: Add route**

In `config/routes.rb`, add `company_matches` to the entries member routes:

```ruby
resources :entries, only: [ :index, :show ] do
  member do
    patch :exclude
    patch :reinstate
    get :company_matches
  end
end
```

- [ ] **Step 4: Implement the company_matches action**

Add to `app/controllers/admin/entries_controller.rb`:

```ruby
def company_matches
  @entrant = Entrant.find(params[:id])
  company = @entrant.company

  matches = case params[:context]
  when "reinstate"
    Entrant.where("LOWER(company) = LOWER(?)", company)
           .where(eligibility_status: "excluded_admin")
  else
    Entrant.where("LOWER(company) = LOWER(?)", company)
           .where(eligibility_status: %w[eligible duplicate_review reinstated_admin])
  end

  render json: {
    company: company,
    count: matches.count,
    entries: matches.limit(3).map { |e|
      { id: e.id, first_name: e.first_name, last_name: e.last_name, email: e.email }
    }
  }
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb -n /company_matches/`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/controllers/admin/entries_controller.rb test/controllers/admin/entries_controller_test.rb
git commit -m "feat: add company_matches JSON endpoint for exclusion modal preview"
```

---

## Chunk 3: Bulk Exclude and Reinstate Actions

### Task 5: Add bulk exclude action

**Files:**
- Modify: `config/routes.rb` (add bulk_exclude member route)
- Modify: `app/controllers/admin/entries_controller.rb` (add bulk_exclude action)
- Test: `test/controllers/admin/entries_controller_test.rb`

- [ ] **Step 1: Write failing tests**

Add to `test/controllers/admin/entries_controller_test.rb`:

```ruby
test "PATCH bulk_exclude without auth redirects to login" do
  patch bulk_exclude_admin_entry_path(entrants(:ada))
  assert_redirected_to admin_login_path
end

test "PATCH bulk_exclude excludes all eligible entries from same company" do
  login_as_admin
  peer = Entrant.create!(
    first_name: "Charles", last_name: "Babbage", email: "charles@babbage.com",
    company: "Babbage Inc", job_title: "Inventor", eligibility_confirmed: true
  )
  patch bulk_exclude_admin_entry_path(entrants(:ada))
  assert_redirected_to admin_entries_path(q: "Babbage")
  entrants(:ada).reload
  peer.reload
  assert_equal "excluded_admin", entrants(:ada).eligibility_status
  assert_equal "Sponsor / Vendor", entrants(:ada).exclusion_reason
  assert_equal "excluded_admin", peer.eligibility_status
  assert_equal "Sponsor / Vendor", peer.exclusion_reason
end

test "PATCH bulk_exclude uses case-insensitive company match" do
  login_as_admin
  peer = Entrant.create!(
    first_name: "Lower", last_name: "Case", email: "lower@babbage.com",
    company: "babbage inc", job_title: "Tester", eligibility_confirmed: true
  )
  patch bulk_exclude_admin_entry_path(entrants(:ada))
  peer.reload
  assert_equal "excluded_admin", peer.eligibility_status
end

test "PATCH bulk_exclude does not touch winners" do
  login_as_admin
  patch bulk_exclude_admin_entry_path(entrants(:winner_carol))
  entrants(:winner_carol).reload
  assert_equal "winner", entrants(:winner_carol).eligibility_status
end

test "PATCH bulk_exclude does not touch self_attested_ineligible" do
  login_as_admin
  # Make ineligible_bob share a company with ada
  entrants(:ineligible_bob).update_columns(company: "Babbage Inc")
  patch bulk_exclude_admin_entry_path(entrants(:ada))
  entrants(:ineligible_bob).reload
  assert_equal "self_attested_ineligible", entrants(:ineligible_bob).eligibility_status
end

test "PATCH bulk_exclude flash includes count and company name" do
  login_as_admin
  patch bulk_exclude_admin_entry_path(entrants(:ada))
  follow_redirect!
  assert_select ".admin-flash--notice", text: /1 entry from Babbage Inc excluded/
end

test "PATCH bulk_exclude redirects with first-word company search" do
  login_as_admin
  patch bulk_exclude_admin_entry_path(entrants(:ada))
  assert_redirected_to admin_entries_path(q: "Babbage")
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb -n /bulk_exclude/`
Expected: All fail (route/action doesn't exist)

- [ ] **Step 3: Add route**

In `config/routes.rb`, add to the entries member block:

```ruby
patch :bulk_exclude
```

- [ ] **Step 4: Implement bulk_exclude action**

Add to `app/controllers/admin/entries_controller.rb`:

```ruby
def bulk_exclude
  @entrant = Entrant.find(params[:id])
  company = @entrant.company

  matches = Entrant.where("LOWER(company) = LOWER(?)", company)
                   .where(eligibility_status: %w[eligible duplicate_review reinstated_admin])

  count = 0
  ActiveRecord::Base.transaction do
    count = matches.update_all(
      eligibility_status: "excluded_admin",
      exclusion_reason: "Sponsor / Vendor"
    )
  end

  search_term = company.split.first
  flash[:notice] = "#{count} #{count == 1 ? 'entry' : 'entries'} from #{company} excluded. Searching for other entries that may be related."
  redirect_to admin_entries_path(q: search_term)
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb -n /bulk_exclude/`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/controllers/admin/entries_controller.rb test/controllers/admin/entries_controller_test.rb
git commit -m "feat: add bulk_exclude action for company-wide sponsor exclusion"
```

### Task 6: Add bulk reinstate action

**Files:**
- Modify: `config/routes.rb` (add bulk_reinstate member route)
- Modify: `app/controllers/admin/entries_controller.rb` (add bulk_reinstate action)
- Test: `test/controllers/admin/entries_controller_test.rb`

- [ ] **Step 1: Write failing tests**

Add to `test/controllers/admin/entries_controller_test.rb`:

```ruby
test "PATCH bulk_reinstate without auth redirects to login" do
  patch bulk_reinstate_admin_entry_path(entrants(:excluded_eve))
  assert_redirected_to admin_login_path
end

test "PATCH bulk_reinstate reinstates all excluded entries from same company" do
  login_as_admin
  # excluded_eve and sponsor_gina are both excluded_admin from CypherCon Sponsor LLC
  patch bulk_reinstate_admin_entry_path(entrants(:excluded_eve))
  assert_redirected_to admin_entries_path(q: "CypherCon")
  entrants(:excluded_eve).reload
  entrants(:sponsor_gina).reload
  assert_equal "reinstated_admin", entrants(:excluded_eve).eligibility_status
  assert_nil entrants(:excluded_eve).exclusion_reason
  assert_equal "reinstated_admin", entrants(:sponsor_gina).eligibility_status
  assert_nil entrants(:sponsor_gina).exclusion_reason
end

test "PATCH bulk_reinstate uses case-insensitive company match" do
  login_as_admin
  peer = Entrant.create!(
    first_name: "Lower", last_name: "Case", email: "lower@sponsor.com",
    company: "cyphercon sponsor llc", job_title: "Tester", eligibility_confirmed: true,
    eligibility_status: "excluded_admin", exclusion_reason: "Sponsor / Vendor"
  )
  patch bulk_reinstate_admin_entry_path(entrants(:excluded_eve))
  peer.reload
  assert_equal "reinstated_admin", peer.eligibility_status
end

test "PATCH bulk_reinstate flash includes count and company name" do
  login_as_admin
  # excluded_eve + sponsor_gina = 2 excluded entries from same company
  patch bulk_reinstate_admin_entry_path(entrants(:excluded_eve))
  follow_redirect!
  assert_select ".admin-flash--notice", text: /2 entries from CypherCon Sponsor LLC reinstated/
end

test "PATCH bulk_reinstate redirects with first-word company search" do
  login_as_admin
  patch bulk_reinstate_admin_entry_path(entrants(:excluded_eve))
  assert_redirected_to admin_entries_path(q: "CypherCon")
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb -n /bulk_reinstate/`
Expected: All fail

- [ ] **Step 3: Add route and implement action**

In `config/routes.rb`, add to the entries member block:

```ruby
patch :bulk_reinstate
```

In `app/controllers/admin/entries_controller.rb`:

```ruby
def bulk_reinstate
  @entrant = Entrant.find(params[:id])
  company = @entrant.company

  matches = Entrant.where("LOWER(company) = LOWER(?)", company)
                   .where(eligibility_status: "excluded_admin")

  count = 0
  ActiveRecord::Base.transaction do
    count = matches.update_all(
      eligibility_status: "reinstated_admin",
      exclusion_reason: nil
    )
  end

  search_term = company.split.first
  flash[:notice] = "#{count} #{count == 1 ? 'entry' : 'entries'} from #{company} reinstated. Searching for other entries that may still be excluded."
  redirect_to admin_entries_path(q: search_term)
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb -n /bulk_reinstate/`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add config/routes.rb app/controllers/admin/entries_controller.rb test/controllers/admin/entries_controller_test.rb
git commit -m "feat: add bulk_reinstate action for company-wide sponsor reinstatement"
```

### Task 7: Update single exclude/reinstate redirects for Sponsor / Vendor

When the "Sponsor / Vendor" exclusion or its reinstatement is done as a single-entry action (from the modal), redirect to the index with session state instead of the show page.

**Files:**
- Modify: `app/controllers/admin/entries_controller.rb` (exclude and reinstate actions)
- Test: `test/controllers/admin/entries_controller_test.rb`

- [ ] **Step 1: Write failing tests**

Add to `test/controllers/admin/entries_controller_test.rb`:

```ruby
test "PATCH exclude with Sponsor / Vendor reason redirects to index" do
  login_as_admin
  entrant = entrants(:ada)
  patch exclude_admin_entry_path(entrant), params: { exclusion_reason: "Sponsor / Vendor" }
  assert_redirected_to admin_entries_path
end

test "PATCH exclude with non-sponsor reason still redirects to show" do
  login_as_admin
  entrant = entrants(:ada)
  patch exclude_admin_entry_path(entrant), params: { exclusion_reason: "Event Staff" }
  assert_redirected_to admin_entry_path(entrant)
end

test "PATCH reinstate for sponsor-excluded entry redirects to index" do
  login_as_admin
  entrant = entrants(:excluded_eve)  # exclusion_reason is "CypherCon sponsor employee"
  # First re-set to "Sponsor / Vendor" for this test
  entrant.update_columns(exclusion_reason: "Sponsor / Vendor")
  patch reinstate_admin_entry_path(entrant)
  assert_redirected_to admin_entries_path
end

test "PATCH reinstate for non-sponsor-excluded entry still redirects to show" do
  login_as_admin
  entrant = entrants(:excluded_eve)
  entrant.update_columns(exclusion_reason: "Event Staff")
  patch reinstate_admin_entry_path(entrant)
  assert_redirected_to admin_entry_path(entrant)
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb -n /redirects_to_index\|still_redirects_to_show/`
Expected: Fail — currently always redirects to show

- [ ] **Step 3: Update exclude and reinstate actions**

In `app/controllers/admin/entries_controller.rb`, modify `exclude`:

```ruby
def exclude
  @entrant = Entrant.find(params[:id])
  if @entrant.eligibility_status.in?(%w[winner alternate_winner])
    redirect_to admin_entry_path(@entrant), alert: "Cannot modify a winner's status."
    return
  end
  @entrant.update!(
    eligibility_status: "excluded_admin",
    exclusion_reason: params[:exclusion_reason].presence
  )
  if params[:exclusion_reason] == "Sponsor / Vendor"
    redirect_to admin_entries_path, notice: "Entry excluded."
  else
    redirect_to admin_entry_path(@entrant), notice: "Entry excluded."
  end
end
```

Modify `reinstate`:

```ruby
def reinstate
  @entrant = Entrant.find(params[:id])
  unless @entrant.eligibility_status.in?(%w[excluded_admin duplicate_review])
    redirect_to admin_entry_path(@entrant), alert: "Cannot reinstate from this status."
    return
  end
  was_sponsor = @entrant.exclusion_reason == "Sponsor / Vendor"
  @entrant.update!(
    eligibility_status: "reinstated_admin",
    exclusion_reason: nil
  )
  if was_sponsor
    redirect_to admin_entries_path, notice: "Entry reinstated."
  else
    redirect_to admin_entry_path(@entrant), notice: "Entry reinstated."
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb`
Expected: All pass. Note: existing tests for `exclude` and `reinstate` that assert `assert_redirected_to admin_entry_path(entrant)` should still pass because they use non-sponsor reasons (e.g., "Sponsor employee", "FFS Employee", or no reason). Check that `test "PATCH exclude updates status and saves reason"` still passes — it uses "Sponsor employee" not "Sponsor / Vendor".

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/entries_controller.rb test/controllers/admin/entries_controller_test.rb
git commit -m "feat: redirect sponsor/vendor exclusion and reinstatement to index"
```

---

## Chunk 4: Stimulus Controller and Modal UI

### Task 8: Create the exclusion-modal Stimulus controller

**Files:**
- Create: `app/javascript/controllers/exclusion_modal_controller.js`

- [ ] **Step 1: Create the Stimulus controller**

Create `app/javascript/controllers/exclusion_modal_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Controls the Sponsor / Vendor exclusion and reinstatement modal dialogs.
// Fetches company match data, shows preview, and handles "type all" confirmation.
export default class extends Controller {
  static targets = ["dialog", "preview", "count", "list", "more",
                     "confirmInput", "bulkButton", "companyName"]
  static values = {
    matchesUrl: String,
    context: String
  }

  open() {
    this.fetchMatches()
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
    this.resetConfirmation()
  }

  backdropClick(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }

  disconnect() {
    if (this.dialogTarget.open) {
      this.dialogTarget.close()
    }
  }

  async fetchMatches() {
    try {
      const url = `${this.matchesUrlValue}?context=${this.contextValue}`
      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })
      const data = await response.json()
      this.populatePreview(data)
    } catch (error) {
      // If fetch fails, hide the bulk section — single action still works
      this.previewTarget.style.display = "none"
    }
  }

  populatePreview(data) {
    if (data.count <= 1) {
      // Only the current entry (or none) — hide bulk section
      this.previewTarget.style.display = "none"
      return
    }

    this.previewTarget.style.display = ""
    this.countTarget.textContent = `${data.count} entries from ${data.company}`

    // Populate the names list
    this.listTarget.innerHTML = ""
    data.entries.forEach(entry => {
      const li = document.createElement("li")
      li.textContent = `${entry.first_name} ${entry.last_name} — ${entry.email}`
      this.listTarget.appendChild(li)
    })

    // Show "+ N more" if there are more than 3
    if (data.count > 3) {
      this.moreTarget.textContent = `+ ${data.count - 3} more`
      this.moreTarget.style.display = ""
    } else {
      this.moreTarget.style.display = "none"
    }

    // Update company name in bulk button
    if (this.hasCompanyNameTarget) {
      this.companyNameTargets.forEach(el => {
        el.textContent = data.company
      })
    }
  }

  validateConfirmation() {
    const input = this.confirmInputTarget.value.trim().toLowerCase()
    if (input === "all") {
      this.bulkButtonTarget.disabled = false
      this.bulkButtonTarget.classList.remove("admin-btn--disabled")
    } else {
      this.bulkButtonTarget.disabled = true
      this.bulkButtonTarget.classList.add("admin-btn--disabled")
    }
  }

  resetConfirmation() {
    if (this.hasConfirmInputTarget) {
      this.confirmInputTarget.value = ""
    }
    if (this.hasBulkButtonTarget) {
      this.bulkButtonTarget.disabled = true
      this.bulkButtonTarget.classList.add("admin-btn--disabled")
    }
  }
}
```

- [ ] **Step 2: Verify controller loads**

Run: `bin/rails server -b 0.0.0.0` and check browser console for errors on an admin entry show page. The controller won't be wired up yet, but it should load without syntax errors.

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/exclusion_modal_controller.js
git commit -m "feat: add exclusion-modal Stimulus controller"
```

### Task 9: Add exclusion modal dialog to show template

**Files:**
- Modify: `app/views/admin/entries/show.html.erb`
- Modify: `app/assets/stylesheets/admin.css`
- Test: `test/controllers/admin/entries_controller_test.rb`

- [ ] **Step 1: Write failing tests for modal presence**

Add to `test/controllers/admin/entries_controller_test.rb`:

```ruby
test "show displays sponsor/vendor button as modal trigger for eligible entry" do
  login_as_admin
  get admin_entry_path(entrants(:ada))
  # Sponsor / Vendor should be a button (not a form), wired to open a dialog
  assert_select "button[data-action*='exclusion-modal#open']", text: "Sponsor / Vendor"
  # Other reasons should still be regular button_to forms
  assert_select ".admin-exclude-reasons form", 4  # was 5, now 4 forms + 1 button
end

test "show displays exclusion dialog for eligible entry" do
  login_as_admin
  get admin_entry_path(entrants(:ada))
  assert_select "dialog.admin-exclusion-modal"
  assert_select "dialog.admin-exclusion-modal form[action*='exclude']"
  assert_select "dialog.admin-exclusion-modal form[action*='bulk_exclude']"
end

test "show displays reinstate modal for sponsor-excluded entry with company peers" do
  login_as_admin
  # Add another excluded entry from same company
  Entrant.create!(
    first_name: "Mallory", last_name: "Sponsor", email: "mallory@sponsor.com",
    company: "CypherCon Sponsor LLC", job_title: "Sales", eligibility_confirmed: true,
    eligibility_status: "excluded_admin", exclusion_reason: "Sponsor / Vendor"
  )
  get admin_entry_path(entrants(:excluded_eve))
  assert_select "dialog.admin-reinstate-modal"
  assert_select "button[data-action*='exclusion-modal#open']", text: "Reinstate"
end

test "show displays regular reinstate button when no company peers excluded" do
  login_as_admin
  get admin_entry_path(entrants(:excluded_eve))
  # excluded_eve is the only one from CypherCon Sponsor LLC
  assert_select "dialog.admin-reinstate-modal", count: 0
  assert_select ".admin-action--reinstate form"  # regular button_to
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb -n /modal_trigger\|exclusion_dialog\|reinstate_modal\|regular_reinstate/`
Expected: Fail

- [ ] **Step 3: Update show template**

Replace the full content of `app/views/admin/entries/show.html.erb`. The key changes:
1. "Sponsor / Vendor" becomes a `<button>` with Stimulus action instead of `button_to`
2. Add `<dialog>` for exclusion modal
3. Conditionally add reinstate modal when entry is sponsor-excluded and has company peers

```erb
<div class="admin-show">
  <%= link_to "← Back to Entries", admin_entries_path, class: "admin-back-link" %>

  <div class="admin-show__header">
    <h2><%= @entrant.first_name %> <%= @entrant.last_name %></h2>
    <span class="admin-status-pill admin-status-pill--<%= @entrant.eligibility_status %>">
      <%= @entrant.eligibility_status %>
    </span>
  </div>

  <div class="admin-detail-card">
    <div class="admin-detail-grid">
      <div class="admin-detail__field">
        <span class="admin-detail__label">First Name</span>
        <span class="admin-detail__value"><%= @entrant.first_name %></span>
      </div>
      <div class="admin-detail__field">
        <span class="admin-detail__label">Last Name</span>
        <span class="admin-detail__value"><%= @entrant.last_name %></span>
      </div>
      <div class="admin-detail__field">
        <span class="admin-detail__label">Email</span>
        <span class="admin-detail__value"><%= @entrant.email %></span>
      </div>
      <div class="admin-detail__field">
        <span class="admin-detail__label">Company</span>
        <span class="admin-detail__value"><%= @entrant.company %></span>
      </div>
      <div class="admin-detail__field">
        <span class="admin-detail__label">Job Title</span>
        <span class="admin-detail__value"><%= @entrant.job_title %></span>
      </div>
      <div class="admin-detail__field">
        <span class="admin-detail__label">Entered</span>
        <span class="admin-detail__value"><%= @entrant.created_at.strftime("%b %d, %Y at %l:%M %p") %></span>
      </div>
    </div>

    <% if @entrant.interest_areas.any? %>
      <div class="admin-detail__section">
        <span class="admin-detail__label">Interest Areas</span>
        <div class="admin-interest-tags">
          <% @entrant.interest_areas.each do |area| %>
            <span class="admin-interest-tag"><%= area %></span>
          <% end %>
        </div>
      </div>
    <% end %>

    <% if @entrant.exclusion_reason.present? %>
      <div class="admin-detail__section">
        <span class="admin-detail__label">Exclusion Reason</span>
        <span class="admin-detail__value admin-detail__value--excluded"><%= @entrant.exclusion_reason %></span>
      </div>
    <% end %>
  </div>

  <%# Action area — contextual based on eligibility status %>
  <% case @entrant.eligibility_status %>
  <% when "eligible", "reinstated_admin", "duplicate_review" %>
    <div class="admin-action admin-action--exclude">
      <span class="admin-action__title">Exclude This Entry</span>
      <div class="admin-exclude-reasons"
           data-controller="exclusion-modal"
           data-exclusion-modal-matches-url-value="<%= company_matches_admin_entry_path(@entrant) %>"
           data-exclusion-modal-context-value="exclude">
        <button type="button" class="admin-btn admin-btn--danger"
                data-action="exclusion-modal#open">Sponsor / Vendor</button>
        <% %w[Event\ Staff Duplicate FFS\ Employee Other].each do |reason| %>
          <%= button_to reason, exclude_admin_entry_path(@entrant),
              method: :patch,
              params: { exclusion_reason: reason },
              class: "admin-btn admin-btn--danger" %>
        <% end %>

        <%# Exclusion modal dialog %>
        <dialog class="admin-exclusion-modal"
                data-exclusion-modal-target="dialog"
                data-action="click->exclusion-modal#backdropClick">
          <div class="admin-modal__content">
            <div class="admin-modal__header">
              <h3 class="admin-modal__title">Exclude as Sponsor / Vendor</h3>
              <button type="button" class="admin-modal__close" data-action="exclusion-modal#close">&times;</button>
            </div>
            <div class="admin-modal__body">
              <p class="admin-modal__description">
                <strong><%= @entrant.first_name %> <%= @entrant.last_name %></strong>
                is from <strong><%= @entrant.company %></strong>.
              </p>

              <%= button_to "Exclude #{@entrant.first_name} #{@entrant.last_name}",
                  exclude_admin_entry_path(@entrant),
                  method: :patch,
                  params: { exclusion_reason: "Sponsor / Vendor" },
                  class: "admin-btn admin-btn--danger admin-modal__primary-btn" %>

              <div class="admin-modal__bulk-section" data-exclusion-modal-target="preview">
                <div class="admin-modal__divider"><span>or exclude the whole company</span></div>

                <div class="admin-modal__preview">
                  <div class="admin-modal__preview-title" data-exclusion-modal-target="count"></div>
                  <ul class="admin-modal__preview-list" data-exclusion-modal-target="list"></ul>
                  <div class="admin-modal__preview-more" data-exclusion-modal-target="more"></div>
                </div>

                <div class="admin-modal__confirm-group">
                  <label class="admin-modal__confirm-label">
                    Type <strong>all</strong> to enable bulk exclusion
                  </label>
                  <div class="admin-modal__confirm-row">
                    <input type="text" class="admin-modal__confirm-input"
                           placeholder="all"
                           autocomplete="off"
                           data-exclusion-modal-target="confirmInput"
                           data-action="input->exclusion-modal#validateConfirmation">
                    <%= button_to "Exclude All",
                        bulk_exclude_admin_entry_path(@entrant),
                        method: :patch,
                        class: "admin-btn admin-btn--danger-outline admin-btn--disabled",
                        disabled: true,
                        data: { exclusion_modal_target: "bulkButton" } %>
                  </div>
                </div>
              </div>

              <button type="button" class="admin-btn admin-btn--ghost admin-modal__cancel-btn"
                      data-action="exclusion-modal#close">Cancel</button>
            </div>
          </div>
        </dialog>
      </div>
    </div>

    <% if @entrant.eligibility_status == "duplicate_review" %>
      <div class="admin-action admin-action--reinstate">
        <div class="admin-action__info">
          <span class="admin-action__title">Reinstate This Entry</span>
          <span class="admin-action__description">Clears the duplicate flag and restores to eligible</span>
        </div>
        <%= button_to "Reinstate", reinstate_admin_entry_path(@entrant), method: :patch, class: "admin-btn admin-btn--success" %>
      </div>
    <% end %>

  <% when "excluded_admin" %>
    <%
      # Check if this is a sponsor exclusion with company peers
      sponsor_excluded = @entrant.exclusion_reason == "Sponsor / Vendor"
      company_peer_count = sponsor_excluded ? Entrant.where("LOWER(company) = LOWER(?)", @entrant.company)
                                                      .where(eligibility_status: "excluded_admin")
                                                      .where.not(id: @entrant.id)
                                                      .count : 0
      show_reinstate_modal = sponsor_excluded && company_peer_count > 0
    %>
    <% if show_reinstate_modal %>
      <div class="admin-action admin-action--reinstate"
           data-controller="exclusion-modal"
           data-exclusion-modal-matches-url-value="<%= company_matches_admin_entry_path(@entrant) %>"
           data-exclusion-modal-context-value="reinstate">
        <div class="admin-action__info">
          <span class="admin-action__title">Reinstate This Entry</span>
          <span class="admin-action__description">Returns status to eligible and clears exclusion reason</span>
        </div>
        <button type="button" class="admin-btn admin-btn--success"
                data-action="exclusion-modal#open">Reinstate</button>

        <dialog class="admin-reinstate-modal"
                data-exclusion-modal-target="dialog"
                data-action="click->exclusion-modal#backdropClick">
          <div class="admin-modal__content">
            <div class="admin-modal__header">
              <h3 class="admin-modal__title">Reinstate Entry</h3>
              <button type="button" class="admin-modal__close" data-action="exclusion-modal#close">&times;</button>
            </div>
            <div class="admin-modal__body">
              <p class="admin-modal__description">
                <strong><%= @entrant.first_name %> <%= @entrant.last_name %></strong>
                was excluded as Sponsor / Vendor.
              </p>

              <%= button_to "Reinstate #{@entrant.first_name} #{@entrant.last_name}",
                  reinstate_admin_entry_path(@entrant),
                  method: :patch,
                  class: "admin-btn admin-btn--success admin-modal__primary-btn" %>

              <div class="admin-modal__bulk-section" data-exclusion-modal-target="preview">
                <div class="admin-modal__divider"><span>or reinstate the whole company</span></div>

                <div class="admin-modal__preview">
                  <div class="admin-modal__preview-title" data-exclusion-modal-target="count"></div>
                  <ul class="admin-modal__preview-list" data-exclusion-modal-target="list"></ul>
                  <div class="admin-modal__preview-more" data-exclusion-modal-target="more"></div>
                </div>

                <div class="admin-modal__confirm-group">
                  <label class="admin-modal__confirm-label">
                    Type <strong>all</strong> to enable bulk reinstatement
                  </label>
                  <div class="admin-modal__confirm-row">
                    <input type="text" class="admin-modal__confirm-input"
                           placeholder="all"
                           autocomplete="off"
                           data-exclusion-modal-target="confirmInput"
                           data-action="input->exclusion-modal#validateConfirmation">
                    <%= button_to "Reinstate All",
                        bulk_reinstate_admin_entry_path(@entrant),
                        method: :patch,
                        class: "admin-btn admin-btn--success-outline admin-btn--disabled",
                        disabled: true,
                        data: { exclusion_modal_target: "bulkButton" } %>
                  </div>
                </div>
              </div>

              <button type="button" class="admin-btn admin-btn--ghost admin-modal__cancel-btn"
                      data-action="exclusion-modal#close">Cancel</button>
            </div>
          </div>
        </dialog>
      </div>
    <% else %>
      <div class="admin-action admin-action--reinstate">
        <div class="admin-action__info">
          <span class="admin-action__title">Reinstate This Entry</span>
          <span class="admin-action__description">Returns status to eligible and clears exclusion reason</span>
        </div>
        <%= button_to "Reinstate", reinstate_admin_entry_path(@entrant), method: :patch, class: "admin-btn admin-btn--success" %>
      </div>
    <% end %>

  <% when "self_attested_ineligible" %>
    <div class="admin-action admin-action--info">
      <p>This person did not confirm eligibility.</p>
    </div>

  <%# winner, alternate_winner — no actions %>
  <% end %>
</div>
```

- [ ] **Step 4: Update existing tests that expect 5 forms**

Two existing tests assert 5 forms in `.admin-exclude-reasons` — now it's 4 forms + 1 Stimulus button. Update both:

```ruby
test "show displays exclusion reason buttons for eligible entry" do
  login_as_admin
  get admin_entry_path(entrants(:ada))
  assert_select ".admin-exclude-reasons"
  assert_select ".admin-exclude-reasons form", 4
  assert_select ".admin-exclude-reasons button[data-action*='exclusion-modal#open']", 1
end

test "show displays exclusion reason buttons for duplicate_review entry" do
  login_as_admin
  get admin_entry_path(entrants(:duplicate_alan))
  assert_select ".admin-exclude-reasons"
  assert_select ".admin-exclude-reasons form", 4
  assert_select ".admin-exclude-reasons button[data-action*='exclusion-modal#open']", 1
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add app/views/admin/entries/show.html.erb test/controllers/admin/entries_controller_test.rb
git commit -m "feat: add exclusion/reinstatement modal dialogs to entry show page"
```

### Task 10: Add modal CSS styles

**Files:**
- Modify: `app/assets/stylesheets/admin.css`

- [ ] **Step 1: Add modal styles**

Add to `app/assets/stylesheets/admin.css` after the existing exclusion reason styles (after line 778):

```css
/* ==========================================================================
   Exclusion / Reinstatement Modal
   ========================================================================== */

.admin-exclusion-modal,
.admin-reinstate-modal {
  border: none;
  border-radius: 12px;
  background: var(--surface-solid);
  color: var(--text);
  padding: 0;
  max-width: 480px;
  width: calc(100vw - 40px);
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
  overflow: visible;
}

.admin-exclusion-modal::backdrop,
.admin-reinstate-modal::backdrop {
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(2px);
}

.admin-modal__content {
  padding: 0;
}

.admin-modal__header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: 20px 24px 0;
}

.admin-modal__title {
  font-size: 18px;
  font-weight: 700;
  color: var(--white);
  margin: 0;
}

.admin-modal__close {
  background: none;
  border: none;
  color: var(--text-muted);
  font-size: 22px;
  cursor: pointer;
  padding: 0 4px;
  line-height: 1;
  transition: color var(--transition);
}

.admin-modal__close:hover {
  color: var(--white);
}

.admin-modal__body {
  padding: 16px 24px 24px;
}

.admin-modal__description {
  color: var(--text-muted);
  font-size: 14px;
  margin-bottom: 16px;
}

.admin-modal__description strong {
  color: var(--ice);
}

.admin-modal__primary-btn {
  width: 100%;
  margin-bottom: 4px;
}

.admin-modal__bulk-section {
  margin-top: 4px;
}

.admin-modal__divider {
  display: flex;
  align-items: center;
  gap: 12px;
  color: var(--text-muted);
  font-size: 13px;
  margin: 16px 0;
}

.admin-modal__divider::before,
.admin-modal__divider::after {
  content: "";
  flex: 1;
  height: 1px;
  background: var(--border);
}

.admin-modal__preview {
  background: rgba(0, 0, 0, 0.2);
  border: 1px solid rgba(91, 139, 205, 0.15);
  border-radius: var(--radius);
  padding: 12px 16px;
  margin-bottom: 16px;
}

.admin-modal__preview-title {
  font-size: 13px;
  color: var(--text-muted);
  font-weight: 600;
  margin-bottom: 8px;
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

.admin-modal__preview-list {
  list-style: none;
  padding: 0;
  margin: 0;
}

.admin-modal__preview-list li {
  font-size: 14px;
  color: var(--ice);
  padding: 3px 0;
}

.admin-modal__preview-list li::before {
  content: "• ";
  color: var(--text-muted);
}

.admin-modal__preview-more {
  font-size: 13px;
  color: var(--text-muted);
  margin-top: 6px;
  font-style: italic;
}

.admin-modal__confirm-group {
  margin-bottom: 16px;
}

.admin-modal__confirm-label {
  font-size: 13px;
  color: var(--text-muted);
  margin-bottom: 6px;
  display: block;
}

.admin-modal__confirm-label strong {
  color: var(--ice);
}

.admin-modal__confirm-row {
  display: flex;
  gap: 8px;
  align-items: center;
}

.admin-modal__confirm-input {
  flex: 1;
  background: var(--brand-deep);
  border: 1px solid var(--brand);
  color: var(--white);
  padding: 8px 12px;
  border-radius: var(--radius);
  font-size: 15px;
  font-family: inherit;
  outline: none;
}

.admin-modal__confirm-input:focus {
  border-color: var(--sky);
}

.admin-modal__confirm-input::placeholder {
  color: rgba(174, 234, 253, 0.3);
}

.admin-btn--danger-outline {
  background: transparent;
  border: 1px solid rgba(255, 107, 107, 0.4);
  color: var(--error);
}

.admin-btn--danger-outline:hover:not(:disabled) {
  background: rgba(255, 107, 107, 0.1);
}

.admin-btn--success-outline {
  background: transparent;
  border: 1px solid rgba(166, 218, 116, 0.4);
  color: var(--accent);
}

.admin-btn--success-outline:hover:not(:disabled) {
  background: rgba(166, 218, 116, 0.1);
}

.admin-btn--ghost {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-muted);
}

.admin-btn--ghost:hover {
  border-color: var(--text-muted);
  color: var(--text);
}

.admin-modal__cancel-btn {
  width: 100%;
  margin-top: 4px;
}
```

- [ ] **Step 2: Visually verify in browser**

Run the dev server and navigate to an entry detail page. Click "Sponsor / Vendor" and verify the modal opens with correct styling. Check that the preview populates, the "type all" input works, and the cancel button closes.

- [ ] **Step 3: Commit**

```bash
git add app/assets/stylesheets/admin.css
git commit -m "feat: add CSS styles for exclusion/reinstatement modal dialogs"
```

---

## Chunk 5: Quality Checks

### Task 11: Final quality checks

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass

- [ ] **Step 2: Run rubocop**

Run: `bundle exec rubocop`
Expected: No new offenses. Fix any that appear.

- [ ] **Step 3: Run brakeman**

Run: `bundle exec brakeman --no-pager -q`
Expected: No new warnings. Pay attention to the `update_all` calls and raw SQL in `LOWER()` — Brakeman may flag these. The `LOWER(?)` parameterized query is safe; if Brakeman flags it, verify it's a false positive.

- [ ] **Step 4: Manual browser verification**

Test the full flow in a browser:
1. Log into admin, go to entries
2. Click an entry, click "Sponsor / Vendor" — modal opens
3. Click "Exclude [Name]" — redirected to index with previous search/sort
4. Navigate to entry, click "Sponsor / Vendor", type "all", click "Exclude All" — redirected with company search
5. Find an excluded sponsor entry, click "Reinstate" — modal shows with company peers
6. Test both single and bulk reinstate
7. Verify logout clears session state

- [ ] **Step 5: Commit any remaining fixes**

```bash
git add -A
git commit -m "chore: quality check fixes for exclusion modal feature"
```
