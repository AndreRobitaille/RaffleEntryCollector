# CSV Export Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add CSV export to the admin console with two modes — eligible entries only and all entries — with interest areas as individual boolean columns.

**Architecture:** New `Admin::ExportsController` with `index` (HTML page) and `download` (CSV stream) actions. CSV generated in-memory using Ruby's stdlib `CSV` library. Interest area columns derived dynamically from `Entrant::INTEREST_AREA_OPTIONS`.

**Tech Stack:** Ruby on Rails, Minitest, Ruby stdlib `csv`

**Spec:** `docs/superpowers/specs/2026-03-15-csv-export-design.md`

---

## File Structure

| File | Purpose |
|------|---------|
| **Create:** `app/controllers/admin/exports_controller.rb` | Controller with `index` and `download` actions |
| **Create:** `app/views/admin/exports/index.html.erb` | Export page with download buttons and entry counts |
| **Create:** `test/controllers/admin/exports_controller_test.rb` | Controller tests for both export modes and auth |
| **Modify:** `config/routes.rb` | Add export routes in admin namespace |
| **Modify:** `app/views/layouts/admin.html.erb` | Wire up the disabled Export nav link |
| **Modify:** `app/assets/stylesheets/admin.css` | Export page styles |
| **Modify:** `test/fixtures/entrants.yml` | Add reinstated_admin fixture for testing |

---

## Chunk 1: Routes, Fixture, and Controller

### Task 1: Add reinstated_admin fixture

**Files:**
- Modify: `test/fixtures/entrants.yml`

- [ ] **Step 1: Add reinstated fixture to entrants.yml**

Add this fixture at the end of the file:

```yaml
reinstated_diana:
  first_name: Diana
  last_name: Prince
  email: diana@example.com
  company: Themyscira Corp
  job_title: Security Analyst
  eligibility_confirmed: true
  eligibility_status: reinstated_admin
  interest_areas:
    - "Cloud & Infrastructure Security"
    - "Space Systems Security"
```

- [ ] **Step 2: Run existing tests to confirm fixture doesn't break anything**

Run: `bin/rails test`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add test/fixtures/entrants.yml
git commit -m "test: add reinstated_admin fixture for CSV export tests"
```

---

### Task 2: Add export routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Add export routes inside the admin namespace**

In `config/routes.rb`, inside the `namespace :admin do` block, after the `resources :entries` block, add:

```ruby
    get "export", to: "exports#index", as: :export
    get "export/download", to: "exports#download", as: :export_download
```

The full admin namespace block should look like:

```ruby
  namespace :admin do
    root "entries#index"
    get "login", to: "sessions#new"
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy"

    resources :entries, only: [ :index, :show ] do
      member do
        patch :exclude
        patch :reinstate
      end
    end

    get "export", to: "exports#index", as: :export
    get "export/download", to: "exports#download", as: :export_download
  end
```

- [ ] **Step 2: Verify routes exist**

Run: `bin/rails routes | grep export`
Expected output includes:
```
admin_export          GET  /admin/export(.:format)           admin/exports#index
admin_export_download GET  /admin/export/download(.:format)  admin/exports#download
```

- [ ] **Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "feat: add admin export routes"
```

---

### Task 3: Write controller tests and implement controller

**Files:**
- Create: `test/controllers/admin/exports_controller_test.rb`
- Create: `app/controllers/admin/exports_controller.rb`

- [ ] **Step 1: Write the failing tests**

Create `test/controllers/admin/exports_controller_test.rb`:

```ruby
require "test_helper"
require "csv"

class Admin::ExportsControllerTest < ActionDispatch::IntegrationTest
  test "GET /admin/export without auth redirects to login" do
    get admin_export_path
    assert_redirected_to admin_login_path
  end

  test "GET /admin/export/download without auth redirects to login" do
    get admin_export_download_path
    assert_redirected_to admin_login_path
  end

  test "GET /admin/export renders export page" do
    login_as_admin
    get admin_export_path
    assert_response :success
  end

  test "GET /admin/export/download with type=eligible returns CSV with only eligible and reinstated entries" do
    login_as_admin
    get admin_export_download_path, params: { type: "eligible" }
    assert_response :success
    assert_equal "text/csv", response.content_type.split(";").first

    csv = CSV.parse(response.body, headers: true)
    statuses = csv.map { |row| row["eligibility_status"] }
    assert_includes statuses, "eligible"
    assert_includes statuses, "reinstated_admin"
    refute_includes statuses, "excluded_admin"
    refute_includes statuses, "duplicate_review"
    refute_includes statuses, "self_attested_ineligible"
    refute_includes statuses, "winner"
  end

  test "GET /admin/export/download with type=all returns CSV with all entries" do
    login_as_admin
    get admin_export_download_path, params: { type: "all" }
    assert_response :success

    csv = CSV.parse(response.body, headers: true)
    assert_equal Entrant.count, csv.length
  end

  test "GET /admin/export/download without type defaults to eligible" do
    login_as_admin
    get admin_export_download_path
    assert_response :success

    csv = CSV.parse(response.body, headers: true)
    statuses = csv.map { |row| row["eligibility_status"] }.uniq
    statuses.each do |status|
      assert_includes %w[eligible reinstated_admin], status
    end
  end

  test "GET /admin/export/download with invalid type defaults to eligible" do
    login_as_admin
    get admin_export_download_path, params: { type: "garbage" }
    assert_response :success

    csv = CSV.parse(response.body, headers: true)
    statuses = csv.map { |row| row["eligibility_status"] }.uniq
    statuses.each do |status|
      assert_includes %w[eligible reinstated_admin], status
    end
  end

  test "CSV has correct Content-Disposition with filename and timestamp" do
    login_as_admin
    get admin_export_download_path, params: { type: "all" }
    disposition = response.headers["Content-Disposition"]
    assert_match(/attachment/, disposition)
    assert_match(/raffle-entries-all-\d{8}-\d{6}\.csv/, disposition)
  end

  test "CSV header row contains expected column names in correct order" do
    login_as_admin
    get admin_export_download_path, params: { type: "eligible" }

    csv = CSV.parse(response.body, headers: true)
    expected_headers = %w[
      first_name last_name email company job_title created_at eligibility_status
      penetration_testing red_team app_security cloud_infra_security
      hardware_iot_security space_systems_security security_training
    ]
    assert_equal expected_headers, csv.headers
  end

  test "interest area columns contain 1 or 0 values" do
    login_as_admin
    get admin_export_download_path, params: { type: "eligible" }

    csv = CSV.parse(response.body, headers: true)
    interest_columns = %w[
      penetration_testing red_team app_security cloud_infra_security
      hardware_iot_security space_systems_security security_training
    ]

    csv.each do |row|
      interest_columns.each do |col|
        assert_includes %w[0 1], row[col], "Expected 0 or 1 for #{col}, got #{row[col]}"
      end
    end
  end

  test "interest area columns reflect entrant data correctly" do
    login_as_admin
    get admin_export_download_path, params: { type: "eligible" }

    csv = CSV.parse(response.body, headers: true)
    ada_row = csv.find { |row| row["email"] == "ada@example.com" }
    assert_equal "1", ada_row["penetration_testing"]
    assert_equal "1", ada_row["app_security"]
    assert_equal "0", ada_row["red_team"]
    assert_equal "0", ada_row["security_training"]

    diana_row = csv.find { |row| row["email"] == "diana@example.com" }
    assert_equal "1", diana_row["cloud_infra_security"]
    assert_equal "1", diana_row["space_systems_security"]
    assert_equal "0", diana_row["penetration_testing"]
  end

  private

  def login_as_admin
    post admin_login_path, params: { password: admin_password }
  end

  def admin_password
    Rails.application.credentials.admin_password || ENV.fetch("ADMIN_PASSWORD", "changeme")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/exports_controller_test.rb`
Expected: All tests fail (controller doesn't exist yet)

- [ ] **Step 3: Implement the controller**

Create `app/controllers/admin/exports_controller.rb`:

```ruby
require "csv"

class Admin::ExportsController < Admin::BaseController
  INTEREST_AREA_COLUMNS = {
    "Penetration Testing" => "penetration_testing",
    "Red Team / Adversary Simulation" => "red_team",
    "Application Security" => "app_security",
    "Cloud & Infrastructure Security" => "cloud_infra_security",
    "Hardware / IoT Security" => "hardware_iot_security",
    "Space Systems Security" => "space_systems_security",
    "Security Training" => "security_training"
  }.freeze

  CSV_FIXED_HEADERS = %w[first_name last_name email company job_title created_at eligibility_status].freeze

  def index
    @total_count = Entrant.count
    @eligible_count = Entrant.eligible.count
  end

  def download
    entries = export_scope
    csv_data = generate_csv(entries)
    filename = "raffle-entries-#{export_type}-#{Time.current.strftime('%Y%m%d-%H%M%S')}.csv"

    send_data csv_data, filename: filename, type: "text/csv", disposition: "attachment"
  end

  private

  def export_type
    %w[eligible all].include?(params[:type]) ? params[:type] : "eligible"
  end

  def export_scope
    export_type == "all" ? Entrant.all : Entrant.eligible
  end

  def generate_csv(entries)
    headers = CSV_FIXED_HEADERS + INTEREST_AREA_COLUMNS.values

    CSV.generate do |csv|
      csv << headers
      entries.find_each do |entrant|
        row = [
          entrant.first_name,
          entrant.last_name,
          entrant.email,
          entrant.company,
          entrant.job_title,
          entrant.created_at,
          entrant.eligibility_status
        ]
        INTEREST_AREA_COLUMNS.each_key do |area_name|
          row << (entrant.interest_areas.include?(area_name) ? 1 : 0)
        end
        csv << row
      end
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/admin/exports_controller_test.rb`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add test/controllers/admin/exports_controller_test.rb app/controllers/admin/exports_controller.rb
git commit -m "feat: add CSV export controller with eligible and all modes (Issue #10)"
```

---

## Chunk 2: UI (View, Layout, Styles)

### Task 4: Create export page view and wire up nav link

**Files:**
- Create: `app/views/admin/exports/index.html.erb`
- Modify: `app/views/layouts/admin.html.erb`
- Modify: `app/assets/stylesheets/admin.css`

- [ ] **Step 1: Create the export page view**

Create `app/views/admin/exports/index.html.erb`:

```erb
<h2 class="admin-export__title">Export Entries</h2>

<div class="admin-stats" style="max-width: 320px;">
  <div class="admin-stat">
    <span class="admin-stat__label">Total</span>
    <span class="admin-stat__count"><%= @total_count %></span>
  </div>
  <div class="admin-stat">
    <span class="admin-stat__label">Eligible</span>
    <span class="admin-stat__count admin-stat__count--eligible"><%= @eligible_count %></span>
  </div>
</div>

<div class="admin-export__options">
  <div class="admin-export__option">
    <h3 class="admin-export__option-title">Eligible Entries</h3>
    <p class="admin-export__option-description">
      Download entries eligible for the raffle only. Excludes entries marked as
      ineligible, excluded, or flagged for duplicate review.
    </p>
    <p class="admin-export__option-count"><%= @eligible_count %> entries</p>
    <%= link_to "Download CSV", admin_export_download_path(type: "eligible"), class: "admin-btn admin-btn--success" %>
  </div>

  <div class="admin-export__option">
    <h3 class="admin-export__option-title">All Entries</h3>
    <p class="admin-export__option-description">
      Download all entries including excluded, duplicates, and ineligible.
    </p>
    <p class="admin-export__option-count"><%= @total_count %> entries</p>
    <%= link_to "Download CSV", admin_export_download_path(type: "all"), class: "admin-btn admin-btn--primary" %>
  </div>
</div>
```

- [ ] **Step 2: Wire up the Export nav link in the admin layout**

In `app/views/layouts/admin.html.erb`, replace the disabled Export span:

```erb
        <span class="admin-header__link" style="opacity: 0.4; cursor: default;">Export</span>
```

with:

```erb
        <%= link_to "Export", admin_export_path, class: "admin-header__link #{'admin-header__link--active' if controller_name == 'exports'}" %>
```

- [ ] **Step 3: Add export page styles to admin.css**

Append to `app/assets/stylesheets/admin.css`:

```css
/* Export page */
.admin-export__title {
  font-size: 22px;
  font-weight: 700;
  color: var(--white);
  margin-bottom: 20px;
}

.admin-export__options {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  max-width: 700px;
}

.admin-export__option {
  background: var(--brand-deep);
  border-radius: var(--radius-lg);
  padding: 20px;
}

.admin-export__option-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--white);
  margin-bottom: 8px;
}

.admin-export__option-description {
  color: var(--text-muted);
  font-size: 13px;
  line-height: 1.5;
  margin-bottom: 12px;
}

.admin-export__option-count {
  color: var(--sky);
  font-size: 13px;
  font-weight: 600;
  margin-bottom: 14px;
}

.admin-btn--primary {
  background: var(--blue);
  color: var(--bg);
}

.admin-btn--primary:hover {
  background: #6e9bd8;
}
```

- [ ] **Step 4: Run all tests to verify nothing is broken**

Run: `bin/rails test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add app/views/admin/exports/index.html.erb app/views/layouts/admin.html.erb app/assets/stylesheets/admin.css
git commit -m "feat: add export page UI with download buttons (Issue #10)"
```

---

### Task 5: Final verification and issue close

- [ ] **Step 1: Run the full test suite**

Run: `bin/rails test`
Expected: All tests pass

- [ ] **Step 2: Start the dev server and manually verify**

Run: `bin/rails server -b 0.0.0.0`

Verify:
1. Navigate to `/admin/login`, log in
2. Export nav link is active and clickable
3. Export page shows correct counts
4. "Download CSV" for eligible entries downloads a CSV with correct columns and only eligible/reinstated rows
5. "Download CSV" for all entries downloads a CSV with all rows
6. Interest area columns show 1/0 values correctly

- [ ] **Step 3: Close the GitHub issue**

```bash
gh issue close 10 --comment "CSV export implemented with eligible/all modes and individual interest area columns."
```
