# Admin Management Page Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an admin management page at `/admin/management` with four operations: reset drawing, populate demo data, clear entrants, and factory reset.

**Architecture:** Single controller (`Admin::ManagementController`) inheriting from `Admin::BaseController` with one GET action (show) and four POST actions. A `DemoPopulator` service handles bulk demo data insertion. All destructive operations use database transactions.

**Tech Stack:** Ruby on Rails, SQLite, Minitest

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `app/controllers/admin/management_controller.rb` | Show page + 4 POST actions |
| Create | `app/views/admin/management/show.html.erb` | Management page with action cards |
| Create | `app/services/demo_populator.rb` | Generate and insert 300 demo entrants |
| Modify | `config/routes.rb` | Add management routes |
| Modify | `app/views/layouts/admin.html.erb` | Add "Management" nav link |
| Modify | `app/assets/stylesheets/admin.css` | Management card styles |
| Create | `test/controllers/admin/management_controller_test.rb` | Controller integration tests |
| Create | `test/services/demo_populator_test.rb` | DemoPopulator unit tests |

---

## Chunk 1: Routes, Controller, and Reset Drawing

### Task 1: Add routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Add management routes to `config/routes.rb`**

Inside the `namespace :admin do` block, after the raffle resource, add:

```ruby
    resource :management, only: [:show], controller: "management" do
      post :reset_drawing
      post :populate_demo
      post :clear_entrants
      post :factory_reset
    end
```

- [ ] **Step 2: Verify routes compile**

Run: `bin/rails routes | grep management`

Expected output should show:
```
reset_drawing_admin_management POST /admin/management/reset_drawing
populate_demo_admin_management POST /admin/management/populate_demo
clear_entrants_admin_management POST /admin/management/clear_entrants
factory_reset_admin_management POST /admin/management/factory_reset
admin_management GET  /admin/management
```

### Task 2: Add nav link to admin layout

**Files:**
- Modify: `app/views/layouts/admin.html.erb:19`

- [ ] **Step 1: Add "Management" link after the Raffle link**

After the Raffle link (line 19), add:

```erb
<%= link_to "Management", admin_management_path, class: "admin-header__link #{'admin-header__link--active' if controller_name == 'management'}" %>
```

### Task 3: Create controller with show action and reset_drawing

**Files:**
- Create: `app/controllers/admin/management_controller.rb`

- [ ] **Step 1: Write failing test for show action**

Create `test/controllers/admin/management_controller_test.rb`:

```ruby
require "test_helper"

class Admin::ManagementControllerTest < ActionDispatch::IntegrationTest
  setup do
    login_as_admin
  end

  test "GET /admin/management without auth redirects to login" do
    reset!
    get admin_management_path
    assert_redirected_to admin_login_path
  end

  test "show displays management page" do
    get admin_management_path
    assert_response :success
    assert_select "h1", /Management/i
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/admin/management_controller_test.rb`
Expected: FAIL — controller does not exist yet.

- [ ] **Step 3: Create controller with show action**

Create `app/controllers/admin/management_controller.rb`:

```ruby
class Admin::ManagementController < Admin::BaseController
  def show
    @entrant_count = Entrant.count
    @draw_exists = RaffleDraw.exists?
  end
end
```

- [ ] **Step 4: Create minimal view**

Create `app/views/admin/management/show.html.erb`:

```erb
<h1>Management</h1>
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/admin/management_controller_test.rb`
Expected: PASS

### Task 4: Implement reset_drawing action

**Files:**
- Modify: `app/controllers/admin/management_controller.rb`
- Modify: `test/controllers/admin/management_controller_test.rb`

- [ ] **Step 1: Write failing tests for reset_drawing**

Append to the test file:

```ruby
  # --- Reset Drawing ---

  test "POST reset_drawing without auth redirects to login" do
    reset!
    post reset_drawing_admin_management_path
    assert_redirected_to admin_login_path
  end

  test "reset_drawing resets winner statuses to eligible" do
    # winner_carol fixture has eligibility_status: "winner"
    post reset_drawing_admin_management_path
    assert_redirected_to admin_management_path

    entrants(:winner_carol).reload
    assert_equal "eligible", entrants(:winner_carol).eligibility_status
  end

  test "reset_drawing deletes all raffle_draw records" do
    # Create a draw first
    RaffleDraw.perform_full_draw!
    assert RaffleDraw.exists?

    post reset_drawing_admin_management_path
    assert_not RaffleDraw.exists?
  end

  test "reset_drawing when no draw exists shows notice" do
    RaffleDraw.delete_all
    post reset_drawing_admin_management_path
    assert_redirected_to admin_management_path
    follow_redirect!
    assert_select ".admin-flash--notice"
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/management_controller_test.rb`
Expected: FAIL — `reset_drawing` action not defined.

- [ ] **Step 3: Implement reset_drawing in controller**

Add to `app/controllers/admin/management_controller.rb`:

```ruby
  def reset_drawing
    ActiveRecord::Base.transaction do
      Entrant.where(eligibility_status: %w[winner alternate_winner])
             .update_all(eligibility_status: "eligible")
      RaffleDraw.delete_all
    end
    redirect_to admin_management_path, notice: "Drawing has been reset. All winners restored to eligible."
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/admin/management_controller_test.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/management_controller.rb app/views/admin/management/show.html.erb config/routes.rb app/views/layouts/admin.html.erb test/controllers/admin/management_controller_test.rb
git commit -m "feat: add admin management page with reset drawing action"
```

---

## Chunk 2: DemoPopulator Service

### Task 5: Create DemoPopulator service

**Files:**
- Create: `app/services/demo_populator.rb`
- Create: `test/services/demo_populator_test.rb`

- [ ] **Step 1: Write failing tests for DemoPopulator**

Create `test/services/demo_populator_test.rb`:

```ruby
require "test_helper"

class DemoPopulatorTest < ActiveSupport::TestCase
  setup do
    # Clear fixtures so DB is empty
    RaffleDraw.delete_all
    Entrant.delete_all
  end

  test "populate! inserts 300 entrants" do
    DemoPopulator.populate!
    assert_equal 300, Entrant.count
  end

  test "all demo entrants are eligible" do
    DemoPopulator.populate!
    assert Entrant.where.not(eligibility_status: "eligible").empty?
  end

  test "demo entrants have varied interest areas" do
    DemoPopulator.populate!
    interest_counts = Entrant.all.map { |e| e.interest_areas.length }.uniq
    assert interest_counts.length > 1, "Expected varied interest area counts"
  end

  test "interest_areas round-trips correctly through insert_all" do
    DemoPopulator.populate!
    entrant = Entrant.first
    assert_kind_of Array, entrant.interest_areas
    entrant.interest_areas.each do |area|
      assert_includes Entrant::INTEREST_AREA_OPTIONS, area
    end
  end

  test "demo entrants have valid emails" do
    DemoPopulator.populate!
    Entrant.find_each do |e|
      assert_match URI::MailTo::EMAIL_REGEXP, e.email
    end
  end

  test "populate! raises if entrants exist" do
    Entrant.create!(
      first_name: "Test", last_name: "User", email: "test@example.com",
      company: "TestCo", job_title: "Tester", eligibility_confirmed: true
    )
    assert_raises(DemoPopulator::DatabaseNotEmpty) { DemoPopulator.populate! }
  end

  test "demo entrants have spread of created_at timestamps" do
    DemoPopulator.populate!
    timestamps = Entrant.pluck(:created_at)
    assert timestamps.min < timestamps.max, "Expected spread of timestamps"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/demo_populator_test.rb`
Expected: FAIL — `DemoPopulator` not defined.

- [ ] **Step 3: Implement DemoPopulator service**

Create `app/services/demo_populator.rb`:

```ruby
class DemoPopulator
  class DatabaseNotEmpty < StandardError; end

  FIRST_NAMES = %w[
    Alex Jordan Taylor Morgan Casey Riley Quinn Avery Parker Sawyer
    Dakota Hayden Charlie Emerson Blake Rowan Finley Sage Reese Peyton
    Jamie Skyler Cameron Phoenix Drew Kai Logan Harper Bailey Micah
    Elena Sofia Aria Nora Maya Chloe Lily Zara Mila Layla
    Marcus Ethan Liam Noah Owen Caleb Jude Felix Oscar Theo
    Priya Anika Ravi Arjun Sanjay Mei Lin Wei Chen Hiro
    Fatima Omar Amira Hassan Leila Yuki Kenji Soren Astrid Ingrid
    Diego Rosa Lucia Carlos Mateo Gabriela Rafael Valentina Andres Isabel
    Nneka Emeka Amara Kwame Zuri Tendai Chioma Farai Nalini Kofi
    Sasha Ivan Dmitri Katya Nikolai Alena Boris Marta Jakub Petra
  ].freeze

  LAST_NAMES = %w[
    Chen Patel Rodriguez Kim Nguyen Okafor Mueller Yamamoto Johansson Costa
    Singh Park Thompson Garcia Williams Brown Martinez Anderson Jackson Lee
    Hartley Reeves Bishop Vasquez Thornton Callahan Moreau Delgado Erikson Wolff
    Nakamura Fitzgerald Kaur Tanaka Stein Dubois Kowalski Rossi Lindgren Becker
    Shah Adeyemi Bergman Takahashi Molina Holmberg Fernandez Volkov Chandra Nystrom
    Okonkwo Torres Brennan Ishikawa Petrov Magnusson Herrera Kato Larsson Mendez
    Weber Sato Lindqvist Ramirez Akiyama Strand Gutierrez Fujita Berglund Santos
    Iwata Norberg Reyes Shimizu Engstrom Aguilar Hashimoto Hedlund Cruz Ogawa
    Karlsson Dominguez Matsuda Forsberg Castillo Ono Sandberg Guerrero Ueda Ekman
    Navarro Hayashi Sjoberg Medina Watanabe Lund Ortega Morimoto Dahlin Vega
  ].freeze

  COMPANIES = [
    "CrowdStrike", "Palo Alto Networks", "Mandiant", "Recorded Future", "Tenable",
    "Rapid7", "SentinelOne", "Fortinet", "Zscaler", "Snyk",
    "Trail of Bits", "NCC Group", "Bishop Fox", "Coalfire", "Secureworks",
    "Dragos", "Claroty", "Nozomi Networks", "Armis", "Phosphorus",
    "Accenture Security", "Deloitte Cyber", "PwC Cybersecurity", "KPMG Security", "EY Cybersecurity",
    "Google Security", "Microsoft Security", "AWS Security", "Apple Security", "Meta Security",
    "Northrop Grumman", "Raytheon", "Lockheed Martin", "Boeing Defense", "L3Harris",
    "Sandia National Labs", "MITRE", "APL Johns Hopkins", "MIT Lincoln Lab", "JPL",
    "University of Wisconsin", "UW-Milwaukee", "Marquette University", "MSOE", "Carthage College",
    "Northwestern Mutual", "Rockwell Automation", "Johnson Controls", "Harley-Davidson", "Kohl's",
    "Foxconn", "Generac", "Epic Systems", "Exact Sciences", "Oshkosh Corp",
    "Independent Consultant", "Freelance Researcher", "Self-Employed", "Student", "Retired"
  ].freeze

  JOB_TITLES = [
    "Security Engineer", "Senior Security Engineer", "Staff Security Engineer",
    "Penetration Tester", "Senior Penetration Tester", "Red Team Operator",
    "Security Analyst", "Senior Security Analyst", "SOC Analyst",
    "CISO", "VP of Security", "Director of Security", "Security Manager",
    "Application Security Engineer", "Cloud Security Engineer", "DevSecOps Engineer",
    "Threat Intelligence Analyst", "Incident Response Lead", "Forensic Analyst",
    "Security Architect", "Principal Security Architect", "Security Consultant",
    "GRC Analyst", "Compliance Manager", "Risk Analyst",
    "Firmware Engineer", "Embedded Systems Engineer", "IoT Security Researcher",
    "Malware Analyst", "Reverse Engineer", "Vulnerability Researcher",
    "Security Researcher", "Cryptographer", "Privacy Engineer",
    "Network Engineer", "Systems Administrator", "IT Director",
    "Software Engineer", "Full Stack Developer", "Platform Engineer",
    "Student", "Research Assistant", "Intern"
  ].freeze

  INTEREST_AREAS = Entrant::INTEREST_AREA_OPTIONS

  def self.populate!
    raise DatabaseNotEmpty, "Cannot populate: entrants already exist" if Entrant.exists?

    now = Time.current
    records = 300.times.map do |i|
      first = FIRST_NAMES.sample
      last = LAST_NAMES.sample
      company = COMPANIES.sample
      email_domain = company.downcase.gsub(/[^a-z0-9]/, "") + ".com"
      email = "#{first.downcase}.#{last.downcase}@#{email_domain}"

      # Spread created_at across last 2 days (simulating conference entries)
      created = now - rand(0..172_800)

      {
        first_name: first,
        last_name: last,
        email: email,
        company: company,
        job_title: JOB_TITLES.sample,
        interest_areas: JSON.generate(INTEREST_AREAS.sample(rand(1..4))),
        eligibility_confirmed: true,
        eligibility_status: "eligible",
        created_at: created,
        updated_at: created
      }
    end

    Entrant.insert_all(records)
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/demo_populator_test.rb`
Expected: PASS

### Task 6: Add populate_demo controller action

**Files:**
- Modify: `app/controllers/admin/management_controller.rb`
- Modify: `test/controllers/admin/management_controller_test.rb`

- [ ] **Step 1: Write failing tests for populate_demo**

Append to controller test file:

```ruby
  # --- Populate Demo ---

  test "POST populate_demo without auth redirects to login" do
    reset!
    post populate_demo_admin_management_path
    assert_redirected_to admin_login_path
  end

  test "populate_demo creates 300 entrants when DB is empty" do
    RaffleDraw.delete_all
    Entrant.delete_all

    post populate_demo_admin_management_path
    assert_redirected_to admin_management_path
    assert_equal 300, Entrant.count
  end

  test "populate_demo fails when entrants exist" do
    assert Entrant.exists? # fixtures loaded
    post populate_demo_admin_management_path
    assert_redirected_to admin_management_path
    follow_redirect!
    assert_select ".admin-flash--alert"
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/management_controller_test.rb`
Expected: FAIL — `populate_demo` not defined.

- [ ] **Step 3: Implement populate_demo in controller**

Add to `app/controllers/admin/management_controller.rb`:

```ruby
  def populate_demo
    DemoPopulator.populate!
    redirect_to admin_management_path, notice: "300 demo entrants created."
  rescue DemoPopulator::DatabaseNotEmpty
    redirect_to admin_management_path, alert: "Cannot populate: entrants already exist. Clear the database first."
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/admin/management_controller_test.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/demo_populator.rb test/services/demo_populator_test.rb app/controllers/admin/management_controller.rb test/controllers/admin/management_controller_test.rb
git commit -m "feat: add DemoPopulator service and populate_demo action"
```

---

## Chunk 3: Clear Entrants and Factory Reset

### Task 7: Implement clear_entrants action

**Files:**
- Modify: `app/controllers/admin/management_controller.rb`
- Modify: `test/controllers/admin/management_controller_test.rb`

- [ ] **Step 1: Write failing tests for clear_entrants**

Append to controller test file:

```ruby
  # --- Clear Entrants ---

  test "POST clear_entrants without auth redirects to login" do
    reset!
    post clear_entrants_admin_management_path, params: { confirmation: "reset" }
    assert_redirected_to admin_login_path
  end

  test "clear_entrants deletes all entrants and raffle_draws" do
    RaffleDraw.perform_full_draw!
    assert Entrant.exists?
    assert RaffleDraw.exists?

    post clear_entrants_admin_management_path, params: { confirmation: "reset" }
    assert_redirected_to admin_management_path

    assert_not Entrant.exists?
    assert_not RaffleDraw.exists?
  end

  test "clear_entrants timestamps the submission log" do
    log_dir = Dir.mktmpdir
    log_path = File.join(log_dir, "submissions.jsonl")
    File.write(log_path, '{"test":"data"}' + "\n")

    # Stub the log path used by the controller
    Admin::ManagementController.stub(:submission_log_dir, Pathname.new(log_dir)) do
      post clear_entrants_admin_management_path, params: { confirmation: "reset" }
    end

    assert_not File.exist?(log_path), "Original log should be renamed"
    timestamped = Dir.glob(File.join(log_dir, "submissions-*.jsonl"))
    assert timestamped.any?, "Should have a timestamped log file"
  ensure
    FileUtils.rm_rf(log_dir) if log_dir
  end

  test "clear_entrants rejects wrong confirmation" do
    post clear_entrants_admin_management_path, params: { confirmation: "wrong" }
    assert_redirected_to admin_management_path
    follow_redirect!
    assert_select ".admin-flash--alert"
    assert Entrant.exists?, "Entrants should not be deleted"
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/management_controller_test.rb`
Expected: FAIL — `clear_entrants` not defined.

- [ ] **Step 3: Implement clear_entrants in controller**

Add to `app/controllers/admin/management_controller.rb`:

```ruby
  def clear_entrants
    unless params[:confirmation] == "reset"
      redirect_to admin_management_path, alert: "Confirmation did not match. Type 'reset' to confirm."
      return
    end

    timestamp_submission_log

    ActiveRecord::Base.transaction do
      RaffleDraw.delete_all
      Entrant.delete_all
    end

    redirect_to admin_management_path, notice: "All entrants and draw history cleared. Logs preserved."
  end
```

Add private helper and class-level configuration:

```ruby
  class_attribute :submission_log_dir, default: Rails.root.join("log")

  private

  def timestamp_submission_log
    log_path = self.class.submission_log_dir.join("submissions.jsonl")
    return unless File.exist?(log_path) && File.size(log_path) > 0

    timestamp = Time.current.strftime("%Y%m%d-%H%M%S")
    archive_path = self.class.submission_log_dir.join("submissions-#{timestamp}.jsonl")
    File.rename(log_path, archive_path)
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/admin/management_controller_test.rb`
Expected: PASS

### Task 8: Implement factory_reset action

**Files:**
- Modify: `app/controllers/admin/management_controller.rb`
- Modify: `test/controllers/admin/management_controller_test.rb`

- [ ] **Step 1: Write failing tests for factory_reset**

Append to controller test file:

```ruby
  # --- Factory Reset ---

  test "POST factory_reset without auth redirects to login" do
    reset!
    post factory_reset_admin_management_path, params: { confirmation: "delete everything" }
    assert_redirected_to admin_login_path
  end

  test "factory_reset deletes entrants, draws, and logs" do
    log_dir = Dir.mktmpdir
    log_path = File.join(log_dir, "submissions.jsonl")
    archive_path = File.join(log_dir, "submissions-20260316-120000.jsonl")
    File.write(log_path, '{"test":"data"}' + "\n")
    File.write(archive_path, '{"old":"data"}' + "\n")

    Admin::ManagementController.stub(:submission_log_dir, Pathname.new(log_dir)) do
      post factory_reset_admin_management_path, params: { confirmation: "delete everything" }
    end
    assert_redirected_to admin_management_path

    assert_not Entrant.exists?
    assert_not RaffleDraw.exists?
    assert_not File.exist?(log_path)
    assert_not File.exist?(archive_path)
  ensure
    FileUtils.rm_rf(log_dir) if log_dir
  end

  test "factory_reset deletes USB backup files" do
    usb_dir = Dir.mktmpdir
    File.write(File.join(usb_dir, "raffle.sqlite3"), "fake db")
    File.write(File.join(usb_dir, "submissions.jsonl"), '{"data":"usb"}')

    UsbBackup.stub(:find_usb_mount, usb_dir) do
      Admin::ManagementController.stub(:submission_log_dir, Pathname.new(Dir.mktmpdir)) do
        post factory_reset_admin_management_path, params: { confirmation: "delete everything" }
      end
    end

    assert_not File.exist?(File.join(usb_dir, "raffle.sqlite3"))
    assert_not File.exist?(File.join(usb_dir, "submissions.jsonl"))
  ensure
    FileUtils.rm_rf(usb_dir) if usb_dir
  end

  test "factory_reset rejects wrong confirmation" do
    post factory_reset_admin_management_path, params: { confirmation: "wrong" }
    assert_redirected_to admin_management_path
    follow_redirect!
    assert_select ".admin-flash--alert"
    assert Entrant.exists?, "Entrants should not be deleted"
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/management_controller_test.rb`
Expected: FAIL — `factory_reset` not defined.

- [ ] **Step 3: Implement factory_reset in controller**

Add to `app/controllers/admin/management_controller.rb`:

```ruby
  def factory_reset
    unless params[:confirmation] == "delete everything"
      redirect_to admin_management_path, alert: "Confirmation did not match. Type 'delete everything' to confirm."
      return
    end

    ActiveRecord::Base.transaction do
      RaffleDraw.delete_all
      Entrant.delete_all
    end

    # Delete all submission logs
    Dir.glob(self.class.submission_log_dir.join("submissions*.jsonl")).each { |f| File.delete(f) }

    # Delete USB backup files if mounted
    usb_mount = UsbBackup.find_usb_mount
    if usb_mount
      Dir.glob(File.join(usb_mount, "submissions*.jsonl")).each { |f| File.delete(f) }
      db_backup = File.join(usb_mount, "raffle.sqlite3")
      File.delete(db_backup) if File.exist?(db_backup)
    end

    redirect_to admin_management_path, notice: "Factory reset complete. All data, logs, and backups deleted."
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/admin/management_controller_test.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/management_controller.rb test/controllers/admin/management_controller_test.rb
git commit -m "feat: add clear_entrants and factory_reset actions"
```

---

## Chunk 4: View and Styling

### Task 9: Build the management page view

**Files:**
- Modify: `app/views/admin/management/show.html.erb`

- [ ] **Step 1: Write the full management page view**

Replace `app/views/admin/management/show.html.erb` with:

```erb
<h1 class="admin-mgmt__title">Management</h1>

<%# === Raffle Section === %>
<div class="admin-mgmt__section">
  <h2 class="admin-mgmt__section-title">Raffle</h2>

  <div class="admin-mgmt__card">
    <div class="admin-mgmt__card-body">
      <div class="admin-mgmt__card-text">
        <h3 class="admin-mgmt__card-title">Reset Drawing</h3>
        <p class="admin-mgmt__card-desc">Undo the raffle drawing. Resets all winners and alternates back to eligible status and removes draw history. Entrants are not affected.</p>
      </div>
      <% if @draw_exists %>
        <%= button_to "Reset Drawing", reset_drawing_admin_management_path,
            class: "admin-btn admin-btn--primary",
            data: { turbo_confirm: "Are you sure you want to reset the drawing? This will restore all winners to eligible status." } %>
      <% else %>
        <button class="admin-btn admin-btn--primary admin-btn--disabled" disabled>No Drawing to Reset</button>
      <% end %>
    </div>
  </div>
</div>

<%# === Data Section === %>
<div class="admin-mgmt__section">
  <h2 class="admin-mgmt__section-title">Data</h2>

  <%# Populate Demo Data %>
  <div class="admin-mgmt__card">
    <div class="admin-mgmt__card-body">
      <div class="admin-mgmt__card-text">
        <h3 class="admin-mgmt__card-title">Populate Demo Data</h3>
        <p class="admin-mgmt__card-desc">Add 300 realistic demo entrants for testing and demonstrations. Requires an empty database.</p>
      </div>
      <% if @entrant_count == 0 %>
        <%= button_to "Populate", populate_demo_admin_management_path,
            class: "admin-btn admin-btn--primary",
            data: { turbo_confirm: "Add 300 demo entrants to the database?" } %>
      <% else %>
        <button class="admin-btn admin-btn--primary admin-btn--disabled" disabled>Database Not Empty (<%= @entrant_count %>)</button>
      <% end %>
    </div>
  </div>

  <%# Clear Entrants %>
  <div class="admin-mgmt__card admin-mgmt__card--danger-light">
    <div class="admin-mgmt__card-body admin-mgmt__card-body--stacked">
      <div class="admin-mgmt__card-text">
        <h3 class="admin-mgmt__card-title">Clear Entrants</h3>
        <p class="admin-mgmt__card-desc">Delete all entrants and draw history from the database. Logs and USB backups are preserved (log file timestamped to prevent overwrites).</p>
      </div>
      <%= form_with url: clear_entrants_admin_management_path, method: :post, class: "admin-mgmt__confirm-form" do |f| %>
        <div class="admin-mgmt__confirm-field">
          <%= f.label :confirmation, 'Type "reset" to confirm', class: "admin-mgmt__confirm-label" %>
          <%= f.text_field :confirmation, class: "admin-mgmt__confirm-input", autocomplete: "off", spellcheck: "false" %>
        </div>
        <%= f.submit "Clear All Entrants", class: "admin-btn admin-btn--danger" %>
      <% end %>
    </div>
  </div>

  <%# Factory Reset %>
  <div class="admin-mgmt__card admin-mgmt__card--danger-heavy">
    <div class="admin-mgmt__card-body admin-mgmt__card-body--stacked">
      <div class="admin-mgmt__card-text">
        <h3 class="admin-mgmt__card-title admin-mgmt__card-title--danger">Factory Reset</h3>
        <p class="admin-mgmt__card-desc">Delete everything — all entrants, draw history, submission logs, and USB backups. This cannot be undone.</p>
      </div>
      <%= form_with url: factory_reset_admin_management_path, method: :post, class: "admin-mgmt__confirm-form" do |f| %>
        <div class="admin-mgmt__confirm-field">
          <%= f.label :confirmation, 'Type "delete everything" to confirm', class: "admin-mgmt__confirm-label" %>
          <%= f.text_field :confirmation, class: "admin-mgmt__confirm-input", autocomplete: "off", spellcheck: "false" %>
        </div>
        <%= f.submit "Factory Reset", class: "admin-btn admin-btn--danger" %>
      <% end %>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Verify page renders**

Run: `bin/rails test test/controllers/admin/management_controller_test.rb`
Expected: PASS

### Task 10: Add management card styles

**Files:**
- Modify: `app/assets/stylesheets/admin.css`

- [ ] **Step 1: Append management page styles to admin.css**

Add at the end of `app/assets/stylesheets/admin.css`:

```css
/* ==========================================================================
   Management Page
   ========================================================================== */

.admin-mgmt__title {
  font-size: 24px;
  font-weight: 700;
  color: var(--white);
  margin-bottom: 24px;
}

.admin-mgmt__section {
  margin-bottom: 32px;
}

.admin-mgmt__section-title {
  font-size: 13px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 1.5px;
  color: var(--text-muted);
  border-bottom: 1px solid var(--brand);
  padding-bottom: 8px;
  margin-bottom: 16px;
}

.admin-mgmt__card {
  background: var(--brand-deep);
  border: 1px solid var(--brand);
  border-radius: var(--radius-lg);
  padding: 20px;
  margin-bottom: 12px;
}

.admin-mgmt__card--danger-light {
  border-color: rgba(255, 107, 107, 0.2);
}

.admin-mgmt__card--danger-heavy {
  border-color: rgba(255, 107, 107, 0.4);
}

.admin-mgmt__card-body {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 16px;
}

.admin-mgmt__card-body--stacked {
  flex-direction: column;
  align-items: stretch;
}

.admin-mgmt__card-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--white);
  margin-bottom: 4px;
}

.admin-mgmt__card-title--danger {
  color: var(--error);
}

.admin-mgmt__card-desc {
  font-size: 14px;
  color: var(--text-muted);
  line-height: 1.5;
}

.admin-mgmt__confirm-form {
  display: flex;
  align-items: flex-end;
  gap: 12px;
  margin-top: 12px;
}

.admin-mgmt__confirm-field {
  flex: 1;
  max-width: 280px;
}

.admin-mgmt__confirm-label {
  display: block;
  font-size: 13px;
  color: var(--text-muted);
  margin-bottom: 4px;
}

.admin-mgmt__confirm-input {
  width: 100%;
  background: rgba(26, 24, 53, 0.9);
  border: 1px solid var(--brand);
  color: var(--white);
  padding: 8px 12px;
  border-radius: var(--radius);
  font-size: 15px;
  font-family: inherit;
  outline: none;
  transition: border-color var(--transition);
}

.admin-mgmt__confirm-input:focus {
  border-color: var(--sky);
}
```

- [ ] **Step 2: Visually verify in browser**

Run: `bin/rails server -b 0.0.0.0` and visit `/admin/management` after logging in. Confirm:
- Two sections (Raffle, Data) with section headers
- Reset Drawing card with button (enabled/disabled based on draw state)
- Populate Demo card with button (disabled if entrants exist)
- Clear Entrants card with typed confirmation field, red-tinted border
- Factory Reset card with typed confirmation field, stronger red border

- [ ] **Step 3: Commit**

```bash
git add app/views/admin/management/show.html.erb app/assets/stylesheets/admin.css
git commit -m "feat: add management page view and styles"
```

---

## Chunk 5: Quality Checks and Final Commit

### Task 11: Run full quality checks

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass.

- [ ] **Step 2: Run rubocop**

Run: `bundle exec rubocop`
Expected: No offenses (fix any that appear).

- [ ] **Step 3: Run brakeman**

Run: `bundle exec brakeman --no-pager -q`
Expected: No warnings.

- [ ] **Step 4: Fix any issues found, re-run checks, and commit fixes**

If any quality check fails, fix the issue and re-run all three checks before committing.
