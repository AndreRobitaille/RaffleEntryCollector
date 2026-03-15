# Raffle Entry Collector — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a touchscreen kiosk app for raffle entry and lead collection at CypherCon, running offline on a Raspberry Pi 4.

**Architecture:** Rails 8 + SQLite (WAL mode) + Hotwire (Turbo + Stimulus). Single `Entrant` model with JSON interest_areas. `RaffleDraw` audit model. Two controller namespaces: `KioskController` (public) and `Admin::` (password-protected). Three-layer data integrity: SQLite, JSONL append log, USB backup.

**Tech Stack:** Ruby 4.0, Rails 8.1, SQLite3, Hotwire (Turbo + Stimulus), Minitest

**Reference docs:**
- `DEVELOPMENT_PLAN.md` — full product specification
- `docs/plans/2026-03-14-architecture-design.md` — architecture decisions

---

## Task 1: Rails Project Scaffold ✅ (completed 2026-03-14)

**Files:**
- Create: entire Rails project in current directory

**Step 1: Generate Rails app**

```bash
rails new . --database=sqlite3 --skip-action-mailer --skip-action-mailbox \
  --skip-action-text --skip-active-job --skip-active-storage \
  --skip-action-cable --skip-jbuilder --skip-hotwire --skip-bundle
```

We skip Hotwire in the generator so we can add just `turbo-rails` and `stimulus-rails` without Solid Cable/Queue dependencies. We skip bundle to configure Gemfile first.

**Step 2: Clean up Gemfile**

Remove gems we don't need (bootsnap is fine to keep). Ensure these gems are present:

```ruby
gem "rails", "~> 8.0"
gem "sqlite3"
gem "puma"
gem "propshaft"
gem "turbo-rails"
gem "stimulus-rails"
gem "importmap-rails"

group :development, :test do
  gem "debug"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
```

**Step 3: Bundle and install Hotwire**

```bash
bundle install
bin/rails turbo:install stimulus:install importmap:install
```

**Step 4: Configure SQLite WAL mode**

Modify `config/database.yml` — ensure the production and development configs include:

```yaml
default: &default
  adapter: sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000

development:
  <<: *default
  database: storage/development.sqlite3

test:
  <<: *default
  database: storage/test.sqlite3

production:
  <<: *default
  database: storage/production.sqlite3
```

Add an initializer `config/initializers/sqlite_wal.rb`:

```ruby
Rails.application.config.after_initialize do
  ActiveRecord::Base.connection.execute("PRAGMA journal_mode=WAL")
  ActiveRecord::Base.connection.execute("PRAGMA synchronous=NORMAL")
end
```

**Step 5: Configure Rails for localhost-only binding**

In `config/puma.rb`, ensure it binds to localhost:

```ruby
bind "tcp://127.0.0.1:#{ENV.fetch('PORT', 3000)}"
```

**Step 6: Run the app to verify it boots**

```bash
bin/rails server
```

Visit http://localhost:3000 — should see Rails welcome page.

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: scaffold Rails 8 app with SQLite WAL mode and Hotwire"
```

---

## Task 2: Entrant Model and Migration ✅ (completed 2026-03-14)

**Files:**
- Create: `db/migrate/TIMESTAMP_create_entrants.rb`
- Create: `app/models/entrant.rb`
- Create: `test/models/entrant_test.rb`

**Step 1: Write the model test**

Create `test/models/entrant_test.rb`:

```ruby
require "test_helper"

class EntrantTest < ActiveSupport::TestCase
  test "valid entrant with all required fields" do
    entrant = Entrant.new(
      first_name: "Ada",
      last_name: "Lovelace",
      email: "ada@example.com",
      company: "Babbage Inc",
      job_title: "Engineer",
      eligibility_confirmed: true
    )
    assert entrant.valid?
    assert_equal "eligible", entrant.eligibility_status
  end

  test "invalid without first_name" do
    entrant = Entrant.new(last_name: "X", email: "x@x.com", company: "X", job_title: "X", eligibility_confirmed: true)
    assert_not entrant.valid?
    assert_includes entrant.errors[:first_name], "can't be blank"
  end

  test "invalid without last_name" do
    entrant = Entrant.new(first_name: "X", email: "x@x.com", company: "X", job_title: "X", eligibility_confirmed: true)
    assert_not entrant.valid?
    assert_includes entrant.errors[:last_name], "can't be blank"
  end

  test "invalid without email" do
    entrant = Entrant.new(first_name: "X", last_name: "X", company: "X", job_title: "X", eligibility_confirmed: true)
    assert_not entrant.valid?
    assert_includes entrant.errors[:email], "can't be blank"
  end

  test "invalid without company" do
    entrant = Entrant.new(first_name: "X", last_name: "X", email: "x@x.com", job_title: "X", eligibility_confirmed: true)
    assert_not entrant.valid?
    assert_includes entrant.errors[:company], "can't be blank"
  end

  test "invalid without job_title" do
    entrant = Entrant.new(first_name: "X", last_name: "X", email: "x@x.com", company: "X", eligibility_confirmed: true)
    assert_not entrant.valid?
    assert_includes entrant.errors[:job_title], "can't be blank"
  end

  test "invalid without eligibility_confirmed" do
    entrant = Entrant.new(first_name: "X", last_name: "X", email: "x@x.com", company: "X", job_title: "X", eligibility_confirmed: false)
    assert_not entrant.valid?
  end

  test "email must look like an email" do
    entrant = Entrant.new(first_name: "X", last_name: "X", email: "notanemail", company: "X", job_title: "X", eligibility_confirmed: true)
    assert_not entrant.valid?
    assert_includes entrant.errors[:email], "is invalid"
  end

  test "interest_areas defaults to empty array" do
    entrant = Entrant.new
    assert_equal [], entrant.interest_areas
  end

  test "interest_areas stores array of strings" do
    entrant = Entrant.new(
      first_name: "X", last_name: "X", email: "x@x.com",
      company: "X", job_title: "X", eligibility_confirmed: true,
      interest_areas: ["Penetration Testing", "Application Security"]
    )
    assert entrant.valid?
    entrant.save!
    entrant.reload
    assert_equal ["Penetration Testing", "Application Security"], entrant.interest_areas
  end

  test "eligibility_status defaults to eligible" do
    entrant = Entrant.create!(
      first_name: "X", last_name: "X", email: "x@x.com",
      company: "X", job_title: "X", eligibility_confirmed: true
    )
    assert_equal "eligible", entrant.eligibility_status
  end

  test "eligibility_status validates inclusion" do
    entrant = Entrant.new(eligibility_status: "bogus")
    assert_not entrant.valid?
    assert_includes entrant.errors[:eligibility_status], "is not included in the list"
  end

  test "scope eligible returns only eligible and reinstated entries" do
    eligible = Entrant.create!(first_name: "A", last_name: "A", email: "a@x.com", company: "X", job_title: "X", eligibility_confirmed: true, eligibility_status: "eligible")
    reinstated = Entrant.create!(first_name: "B", last_name: "B", email: "b@x.com", company: "X", job_title: "X", eligibility_confirmed: true, eligibility_status: "reinstated_admin")
    excluded = Entrant.create!(first_name: "C", last_name: "C", email: "c@x.com", company: "X", job_title: "X", eligibility_confirmed: true, eligibility_status: "excluded_admin")

    result = Entrant.eligible
    assert_includes result, eligible
    assert_includes result, reinstated
    assert_not_includes result, excluded
  end
end
```

**Step 2: Run tests to verify they fail**

```bash
bin/rails test test/models/entrant_test.rb
```

Expected: failures (Entrant class doesn't exist yet).

**Step 3: Generate the migration**

```bash
bin/rails generate migration CreateEntrants \
  first_name:string last_name:string email:string \
  company:string job_title:string \
  eligibility_confirmed:boolean \
  eligibility_status:string exclusion_reason:string
```

Edit the generated migration to add the JSON column and defaults:

```ruby
class CreateEntrants < ActiveRecord::Migration[8.0]
  def change
    create_table :entrants do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :company, null: false
      t.string :job_title, null: false
      t.json :interest_areas, default: []
      t.boolean :eligibility_confirmed, null: false, default: false
      t.string :eligibility_status, null: false, default: "eligible"
      t.string :exclusion_reason

      t.timestamps
    end

    add_index :entrants, :email
    add_index :entrants, [:first_name, :last_name, :company]
    add_index :entrants, :eligibility_status
  end
end
```

**Step 4: Create the model**

Create `app/models/entrant.rb`:

```ruby
class Entrant < ApplicationRecord
  ELIGIBILITY_STATUSES = %w[
    eligible
    self_attested_ineligible
    duplicate_review
    excluded_admin
    reinstated_admin
    winner
    alternate_winner
  ].freeze

  INTEREST_AREA_OPTIONS = [
    "Penetration Testing",
    "Red Team / Adversary Simulation",
    "Application Security",
    "Cloud & Infrastructure Security",
    "Hardware / IoT Security",
    "Space Systems Security",
    "Security Training"
  ].freeze

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :company, presence: true
  validates :job_title, presence: true
  validates :eligibility_confirmed, acceptance: { accept: true }
  validates :eligibility_status, inclusion: { in: ELIGIBILITY_STATUSES }

  scope :eligible, -> { where(eligibility_status: %w[eligible reinstated_admin]) }
  scope :duplicates, -> { where(eligibility_status: "duplicate_review") }
end
```

**Step 5: Run migration and tests**

```bash
bin/rails db:migrate
bin/rails test test/models/entrant_test.rb
```

Expected: all tests pass.

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add Entrant model with validations, scopes, and migration"
```

---

## Task 3: Duplicate Detection Service ✅ (completed 2026-03-14)

**Files:**
- Create: `app/services/duplicate_detector.rb`
- Create: `test/services/duplicate_detector_test.rb`

**Step 1: Write the test**

Create `test/services/duplicate_detector_test.rb`:

```ruby
require "test_helper"

class DuplicateDetectorTest < ActiveSupport::TestCase
  test "flags entrant with duplicate email" do
    Entrant.create!(first_name: "Ada", last_name: "Lovelace", email: "ada@example.com", company: "Babbage", job_title: "Eng", eligibility_confirmed: true)
    new_entrant = Entrant.create!(first_name: "Different", last_name: "Person", email: "ada@example.com", company: "Other", job_title: "Dev", eligibility_confirmed: true)

    DuplicateDetector.check(new_entrant)
    new_entrant.reload

    assert_equal "duplicate_review", new_entrant.eligibility_status
  end

  test "flags entrant with duplicate name and company" do
    Entrant.create!(first_name: "Ada", last_name: "Lovelace", email: "ada1@example.com", company: "Babbage", job_title: "Eng", eligibility_confirmed: true)
    new_entrant = Entrant.create!(first_name: "Ada", last_name: "Lovelace", email: "ada2@example.com", company: "Babbage", job_title: "Dev", eligibility_confirmed: true)

    DuplicateDetector.check(new_entrant)
    new_entrant.reload

    assert_equal "duplicate_review", new_entrant.eligibility_status
  end

  test "does not flag unique entrant" do
    Entrant.create!(first_name: "Ada", last_name: "Lovelace", email: "ada@example.com", company: "Babbage", job_title: "Eng", eligibility_confirmed: true)
    new_entrant = Entrant.create!(first_name: "Grace", last_name: "Hopper", email: "grace@example.com", company: "Navy", job_title: "Admiral", eligibility_confirmed: true)

    DuplicateDetector.check(new_entrant)
    new_entrant.reload

    assert_equal "eligible", new_entrant.eligibility_status
  end

  test "case-insensitive email matching" do
    Entrant.create!(first_name: "Ada", last_name: "Lovelace", email: "Ada@Example.com", company: "Babbage", job_title: "Eng", eligibility_confirmed: true)
    new_entrant = Entrant.create!(first_name: "X", last_name: "Y", email: "ada@example.com", company: "Other", job_title: "Dev", eligibility_confirmed: true)

    DuplicateDetector.check(new_entrant)
    new_entrant.reload

    assert_equal "duplicate_review", new_entrant.eligibility_status
  end
end
```

**Step 2: Run tests to verify they fail**

```bash
bin/rails test test/services/duplicate_detector_test.rb
```

**Step 3: Implement the service**

Create `app/services/duplicate_detector.rb`:

```ruby
class DuplicateDetector
  def self.check(entrant)
    return if entrant.eligibility_status != "eligible"

    duplicate_exists = Entrant
      .where.not(id: entrant.id)
      .where(
        "LOWER(email) = :email OR (LOWER(first_name) = :first AND LOWER(last_name) = :last AND LOWER(company) = :company)",
        email: entrant.email.downcase,
        first: entrant.first_name.downcase,
        last: entrant.last_name.downcase,
        company: entrant.company.downcase
      ).exists?

    if duplicate_exists
      entrant.update!(eligibility_status: "duplicate_review")
    end
  end
end
```

**Step 4: Run tests**

```bash
bin/rails test test/services/duplicate_detector_test.rb
```

Expected: all pass.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add DuplicateDetector service for post-submission flagging"
```

---

## Task 4: Submission Logger (JSONL Append Log) ✅ (completed 2026-03-14)

**Files:**
- Create: `app/services/submission_logger.rb`
- Create: `test/services/submission_logger_test.rb`

**Step 1: Write the test**

Create `test/services/submission_logger_test.rb`:

```ruby
require "test_helper"
require "json"

class SubmissionLoggerTest < ActiveSupport::TestCase
  setup do
    @log_path = Rails.root.join("tmp", "test_submissions.jsonl")
    @log_path.delete if @log_path.exist?
  end

  teardown do
    @log_path.delete if @log_path.exist?
  end

  test "appends a JSON line for an entrant" do
    entrant = Entrant.create!(
      first_name: "Ada", last_name: "Lovelace", email: "ada@example.com",
      company: "Babbage", job_title: "Eng", eligibility_confirmed: true,
      interest_areas: ["Application Security"]
    )

    SubmissionLogger.log(entrant, log_path: @log_path)

    lines = @log_path.readlines
    assert_equal 1, lines.size

    data = JSON.parse(lines.first)
    assert_equal "Ada", data["first_name"]
    assert_equal "ada@example.com", data["email"]
    assert_equal ["Application Security"], data["interest_areas"]
    assert data.key?("logged_at")
  end

  test "appends multiple entries without overwriting" do
    entrant1 = Entrant.create!(first_name: "A", last_name: "A", email: "a@x.com", company: "X", job_title: "X", eligibility_confirmed: true)
    entrant2 = Entrant.create!(first_name: "B", last_name: "B", email: "b@x.com", company: "X", job_title: "X", eligibility_confirmed: true)

    SubmissionLogger.log(entrant1, log_path: @log_path)
    SubmissionLogger.log(entrant2, log_path: @log_path)

    lines = @log_path.readlines
    assert_equal 2, lines.size
  end
end
```

**Step 2: Run tests to verify they fail**

```bash
bin/rails test test/services/submission_logger_test.rb
```

**Step 3: Implement**

Create `app/services/submission_logger.rb`:

```ruby
class SubmissionLogger
  DEFAULT_LOG_PATH = Rails.root.join("log", "submissions.jsonl")

  def self.log(entrant, log_path: DEFAULT_LOG_PATH)
    entry = {
      id: entrant.id,
      first_name: entrant.first_name,
      last_name: entrant.last_name,
      email: entrant.email,
      company: entrant.company,
      job_title: entrant.job_title,
      interest_areas: entrant.interest_areas,
      eligibility_confirmed: entrant.eligibility_confirmed,
      created_at: entrant.created_at.iso8601,
      logged_at: Time.current.iso8601
    }

    File.open(log_path, "a") do |f|
      f.puts(entry.to_json)
      f.flush
    end
  end
end
```

**Step 4: Run tests**

```bash
bin/rails test test/services/submission_logger_test.rb
```

Expected: all pass.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add SubmissionLogger for JSONL append-only audit log"
```

---

## Task 5: Kiosk Controller and Routes ✅ (completed 2026-03-14)

**Files:**
- Create: `app/controllers/kiosk_controller.rb`
- Create: `test/controllers/kiosk_controller_test.rb`
- Modify: `config/routes.rb`

**Step 1: Write the controller test**

Create `test/controllers/kiosk_controller_test.rb`:

```ruby
require "test_helper"

class KioskControllerTest < ActionDispatch::IntegrationTest
  test "GET / renders attract screen" do
    get root_path
    assert_response :success
    assert_select "a", text: /Enter the Raffle/i
  end

  test "GET /enter renders entry form" do
    get enter_path
    assert_response :success
    assert_select "form"
    assert_select "input[name='entrant[first_name]']"
    assert_select "input[name='entrant[email]']"
  end

  test "POST /enter creates entrant and redirects to success" do
    assert_difference "Entrant.count", 1 do
      post enter_path, params: {
        entrant: {
          first_name: "Ada",
          last_name: "Lovelace",
          email: "ada@example.com",
          company: "Babbage Inc",
          job_title: "Engineer",
          eligibility_confirmed: "1",
          interest_areas: ["Penetration Testing"]
        }
      }
    end
    assert_redirected_to success_path
  end

  test "POST /enter with invalid data re-renders form" do
    assert_no_difference "Entrant.count" do
      post enter_path, params: {
        entrant: { first_name: "", last_name: "", email: "" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "GET /success renders success screen" do
    get success_path
    assert_response :success
    assert_select "a", text: /Start New Entry/i
  end

  test "successful submission writes to JSONL log" do
    log_path = Rails.root.join("log", "submissions.jsonl")
    log_path.delete if log_path.exist?

    post enter_path, params: {
      entrant: {
        first_name: "Ada", last_name: "Lovelace", email: "ada@example.com",
        company: "Babbage", job_title: "Eng", eligibility_confirmed: "1"
      }
    }

    assert log_path.exist?
    lines = log_path.readlines
    assert lines.size >= 1
  end
end
```

**Step 2: Run tests to verify they fail**

```bash
bin/rails test test/controllers/kiosk_controller_test.rb
```

**Step 3: Set up routes**

Modify `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  root "kiosk#attract"

  get "enter", to: "kiosk#new"
  post "enter", to: "kiosk#create"
  get "success", to: "kiosk#success"
end
```

**Step 4: Create the controller**

Create `app/controllers/kiosk_controller.rb`:

```ruby
class KioskController < ApplicationController
  def attract
  end

  def new
    @entrant = Entrant.new
  end

  def create
    @entrant = Entrant.new(entrant_params)

    if @entrant.save
      SubmissionLogger.log(@entrant)
      DuplicateDetector.check(@entrant)
      redirect_to success_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def success
  end

  private

  def entrant_params
    params.require(:entrant).permit(
      :first_name, :last_name, :email, :company, :job_title,
      :eligibility_confirmed, interest_areas: []
    )
  end
end
```

**Step 5: Create placeholder views**

Create minimal views (these will be styled in Task 6):

`app/views/kiosk/attract.html.erb`:
```erb
<h1>Win a Commodore 64 Ultimate</h1>
<p>Enter the raffle below.</p>
<ul>
  <li>No purchase required</li>
  <li>Winner does NOT need to be present</li>
  <li>Prize will be shipped if necessary</li>
</ul>
<%= link_to "Enter the Raffle", enter_path %>
```

`app/views/kiosk/new.html.erb`:
```erb
<%= form_with(model: @entrant, url: enter_path) do |f| %>
  <% if @entrant.errors.any? %>
    <div id="error_explanation">
      <ul>
        <% @entrant.errors.full_messages.each do |msg| %>
          <li><%= msg %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div>
    <%= f.check_box :eligibility_confirmed %>
    <%= f.label :eligibility_confirmed, "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules." %>
  </div>

  <div>
    <%= f.label :first_name %>
    <%= f.text_field :first_name %>
  </div>

  <div>
    <%= f.label :last_name %>
    <%= f.text_field :last_name %>
  </div>

  <div>
    <%= f.label :email, "Work Email" %>
    <%= f.email_field :email %>
  </div>

  <div>
    <%= f.label :company, "Company (or School / Independent)" %>
    <%= f.text_field :company %>
  </div>

  <div>
    <%= f.label :job_title, "Job Title (or Student / Researcher / etc.)" %>
    <%= f.text_field :job_title %>
  </div>

  <fieldset>
    <legend>Interest Areas (optional)</legend>
    <% Entrant::INTEREST_AREA_OPTIONS.each do |area| %>
      <div>
        <%= check_box_tag "entrant[interest_areas][]", area, @entrant.interest_areas.include?(area) %>
        <%= label_tag nil, area %>
      </div>
    <% end %>
  </fieldset>

  <%= f.submit "Submit Entry" %>
<% end %>

<button type="button">Rules & Drawing Info</button>
```

`app/views/kiosk/success.html.erb`:
```erb
<h1>You're entered in the raffle.</h1>
<p>The winner will be contacted by email after CypherCon.</p>
<p>The prize will be shipped if you are not present.</p>
<%= link_to "Start New Entry", root_path %>
```

**Step 6: Run tests**

```bash
bin/rails test test/controllers/kiosk_controller_test.rb
```

Expected: all pass.

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: add KioskController with attract, entry form, and success flow"
```

---

## Task 6: Kiosk UI Styling and Touchscreen Layout ✅ (completed 2026-03-14)

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/views/kiosk/attract.html.erb`
- Modify: `app/views/kiosk/new.html.erb`
- Modify: `app/views/kiosk/success.html.erb`
- Create: `app/assets/stylesheets/kiosk.css`

> **Note:** Use the `frontend-design` skill for this task. The kiosk needs a clean, modern, touch-friendly design. Key constraints: 10.1" touchscreen (1280x800), large tap targets (minimum 48px), clear spacing, high contrast. The aesthetic should feel professional and appropriate for a security conference — not generic or playful. Dark theme recommended.

**Step 1: Design and implement the layout and styles**

The layout should:
- Set viewport meta for the touchscreen
- Disable user-select, zoom, and text-size-adjust for kiosk use
- Use a centered, full-viewport layout
- Include touch-friendly input sizing (min 48px height)
- Style the attract screen as a centered hero
- Style the form with clear labels, large fields, visible validation errors
- Style the success screen as a confirmation hero
- Add the rules modal markup and styling

**Step 2: Add the rules modal**

Add to `app/views/kiosk/new.html.erb` — a `<dialog>` or styled `<div>` overlay containing the rules text from `DEVELOPMENT_PLAN.md` Section 3 (Screen 3).

**Step 3: Verify visually**

```bash
bin/rails server
```

Open http://localhost:3000 and walk through all screens.

**Step 4: Run existing tests**

```bash
bin/rails test
```

Expected: all pass (styling shouldn't break functional tests).

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add kiosk UI styling with touch-friendly layout and rules modal"
```

---

## Task 7: Stimulus Controllers (Eligibility Gate, Idle Timeout, Modal)

**Files:**
- Create: `app/javascript/controllers/eligibility_controller.js`
- Create: `app/javascript/controllers/idle_timeout_controller.js`
- Create: `app/javascript/controllers/modal_controller.js`
- Modify: `app/views/kiosk/new.html.erb` (add data-controller attributes)
- Modify: `app/views/kiosk/attract.html.erb` (idle timeout target)
- Create: `test/system/kiosk_flow_test.rb`

**Step 1: Write system test**

Create `test/system/kiosk_flow_test.rb`:

```ruby
require "application_system_test_case"

class KioskFlowTest < ApplicationSystemTestCase
  test "form fields are disabled until eligibility checkbox is checked" do
    visit enter_path

    assert page.has_field?("entrant[first_name]", disabled: true)

    check "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules."

    assert page.has_field?("entrant[first_name]", disabled: false)
  end

  test "full entry flow from attract to success" do
    visit root_path
    click_link "Enter the Raffle"

    check "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules."
    fill_in "First name", with: "Ada"
    fill_in "Last name", with: "Lovelace"
    fill_in "Work Email", with: "ada@example.com"
    fill_in "Company", with: "Babbage Inc"
    fill_in "Job Title", with: "Engineer"
    click_button "Submit Entry"

    assert_text "You're entered in the raffle"
    click_link "Start New Entry"
    assert_text "Win a Commodore 64 Ultimate"
  end

  test "rules modal opens and closes" do
    visit enter_path
    click_button "Rules & Drawing Info"
    assert_text "One entry per person"
    # Close the modal (implementation-dependent: click close button or backdrop)
  end
end
```

**Step 2: Run system tests to verify they fail**

```bash
bin/rails test:system
```

**Step 3: Create eligibility controller**

Create `app/javascript/controllers/eligibility_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Manages the eligibility checkbox gate on the entry form.
// When the checkbox is unchecked, all form fields and the submit button are disabled.
export default class extends Controller {
  static targets = ["checkbox", "field", "submit"]

  connect() {
    this.toggle()
  }

  toggle() {
    const enabled = this.checkboxTarget.checked
    this.fieldTargets.forEach(field => field.disabled = !enabled)
    this.submitTarget.disabled = !enabled
  }
}
```

**Step 4: Create idle timeout controller**

Create `app/javascript/controllers/idle_timeout_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Resets the kiosk to the attract screen after 90 seconds of inactivity.
// Listens for input events (touch, key, mouse) and resets the timer on activity.
export default class extends Controller {
  static values = { seconds: { type: Number, default: 90 }, redirectUrl: String }

  connect() {
    this.resetTimer()
    this.boundReset = this.resetTimer.bind(this)

    ;["touchstart", "mousedown", "keydown", "input"].forEach(event => {
      document.addEventListener(event, this.boundReset)
    })
  }

  disconnect() {
    clearTimeout(this.timer)
    ;["touchstart", "mousedown", "keydown", "input"].forEach(event => {
      document.removeEventListener(event, this.boundReset)
    })
  }

  resetTimer() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      window.location.href = this.redirectUrlValue
    }, this.secondsValue * 1000)
  }
}
```

**Step 5: Create modal controller**

Create `app/javascript/controllers/modal_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Controls the rules & drawing info modal overlay.
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  // Close on backdrop click
  backdropClick(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }
}
```

**Step 6: Wire up data-controller attributes in views**

Update the form view to use `data-controller="eligibility"` on the form wrapper, add `data-eligibility-target` attributes to the checkbox, fields, and submit button. Add `data-controller="idle-timeout"` with `data-idle-timeout-redirect-url-value="/"` to the body or a page wrapper. Wire the modal button and dialog with `data-controller="modal"`.

**Step 7: Register controllers**

Ensure controllers are registered in `app/javascript/controllers/index.js` (Stimulus installer should auto-detect them).

**Step 8: Run system tests**

```bash
bin/rails test:system
```

Expected: all pass.

**Step 9: Commit**

```bash
git add -A
git commit -m "feat: add Stimulus controllers for eligibility gate, idle timeout, and rules modal"
```

---

## Task 8: Admin Authentication

**Files:**
- Create: `app/controllers/admin/base_controller.rb`
- Create: `app/controllers/admin/sessions_controller.rb`
- Create: `app/views/admin/sessions/new.html.erb`
- Create: `test/controllers/admin/sessions_controller_test.rb`
- Modify: `config/routes.rb`

**Step 1: Write the test**

Create `test/controllers/admin/sessions_controller_test.rb`:

```ruby
require "test_helper"

class Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET /admin/login renders login form" do
    get admin_login_path
    assert_response :success
    assert_select "form"
  end

  test "POST /admin/login with correct password sets session and redirects" do
    post admin_login_path, params: { password: admin_password }
    assert_redirected_to admin_root_path
    follow_redirect!
    assert_response :success
  end

  test "POST /admin/login with wrong password re-renders form" do
    post admin_login_path, params: { password: "wrong" }
    assert_response :unprocessable_entity
    assert_select "form"
  end

  test "GET /admin without auth redirects to login" do
    get admin_root_path
    assert_redirected_to admin_login_path
  end

  test "DELETE /admin/logout clears session" do
    post admin_login_path, params: { password: admin_password }
    delete admin_logout_path
    assert_redirected_to admin_login_path

    get admin_root_path
    assert_redirected_to admin_login_path
  end

  private

  def admin_password
    Rails.application.credentials.admin_password || ENV.fetch("ADMIN_PASSWORD", "test_admin_pw")
  end
end
```

**Step 2: Run tests to verify they fail**

```bash
bin/rails test test/controllers/admin/sessions_controller_test.rb
```

**Step 3: Add routes**

Add to `config/routes.rb`:

```ruby
namespace :admin do
  root "entries#index"
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"
end
```

**Step 4: Create base controller**

Create `app/controllers/admin/base_controller.rb`:

```ruby
class Admin::BaseController < ApplicationController
  before_action :require_admin

  private

  def require_admin
    unless session[:admin_authenticated]
      redirect_to admin_login_path
    end
  end
end
```

**Step 5: Create sessions controller**

Create `app/controllers/admin/sessions_controller.rb`:

```ruby
class Admin::SessionsController < ApplicationController
  def new
  end

  def create
    if params[:password] == admin_password
      session[:admin_authenticated] = true
      redirect_to admin_root_path
    else
      flash.now[:alert] = "Invalid password"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:admin_authenticated)
    redirect_to admin_login_path
  end

  private

  def admin_password
    Rails.application.credentials.admin_password || ENV.fetch("ADMIN_PASSWORD", "changeme")
  end
end
```

**Step 6: Create login view**

Create `app/views/admin/sessions/new.html.erb`:

```erb
<h1>Admin Login</h1>

<% if flash[:alert] %>
  <p class="alert"><%= flash[:alert] %></p>
<% end %>

<%= form_with(url: admin_login_path, method: :post) do |f| %>
  <div>
    <%= f.label :password %>
    <%= f.password_field :password, autofocus: true %>
  </div>
  <%= f.submit "Log In" %>
<% end %>
```

**Step 7: Run tests**

```bash
bin/rails test test/controllers/admin/sessions_controller_test.rb
```

Expected: all pass.

**Step 8: Commit**

```bash
git add -A
git commit -m "feat: add admin authentication with session-based password"
```

---

## Task 9: Admin Entries Management

**Files:**
- Create: `app/controllers/admin/entries_controller.rb`
- Create: `app/views/admin/entries/index.html.erb`
- Create: `app/views/admin/entries/show.html.erb`
- Create: `test/controllers/admin/entries_controller_test.rb`
- Modify: `config/routes.rb`

**Step 1: Write the test**

Create `test/controllers/admin/entries_controller_test.rb`:

```ruby
require "test_helper"

class Admin::EntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    post admin_login_path, params: { password: admin_password }
    @entrant = Entrant.create!(
      first_name: "Ada", last_name: "Lovelace", email: "ada@example.com",
      company: "Babbage", job_title: "Eng", eligibility_confirmed: true
    )
  end

  test "index shows entries with counts" do
    get admin_root_path
    assert_response :success
    assert_select "td", text: "Ada"
  end

  test "index search filters by name" do
    Entrant.create!(first_name: "Grace", last_name: "Hopper", email: "grace@example.com", company: "Navy", job_title: "Admiral", eligibility_confirmed: true)

    get admin_root_path, params: { q: "Grace" }
    assert_response :success
    assert_select "td", text: "Grace"
    assert_select "td", text: "Ada", count: 0
  end

  test "show displays entry detail" do
    get admin_entry_path(@entrant)
    assert_response :success
    assert_select "dd", text: "ada@example.com"
  end

  test "exclude marks entry as excluded" do
    patch exclude_admin_entry_path(@entrant), params: { exclusion_reason: "Sponsor employee" }
    @entrant.reload
    assert_equal "excluded_admin", @entrant.eligibility_status
    assert_equal "Sponsor employee", @entrant.exclusion_reason
  end

  test "reinstate marks entry as reinstated" do
    @entrant.update!(eligibility_status: "excluded_admin")
    patch reinstate_admin_entry_path(@entrant)
    @entrant.reload
    assert_equal "reinstated_admin", @entrant.eligibility_status
  end

  test "requires admin auth" do
    delete admin_logout_path
    get admin_root_path
    assert_redirected_to admin_login_path
  end

  private

  def admin_password
    Rails.application.credentials.admin_password || ENV.fetch("ADMIN_PASSWORD", "test_admin_pw")
  end
end
```

**Step 2: Run tests to verify they fail**

```bash
bin/rails test test/controllers/admin/entries_controller_test.rb
```

**Step 3: Add routes**

Update the `admin` namespace in `config/routes.rb`:

```ruby
namespace :admin do
  root "entries#index"
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  resources :entries, only: [:index, :show] do
    member do
      patch :exclude
      patch :reinstate
    end
  end
end
```

**Step 4: Create entries controller**

Create `app/controllers/admin/entries_controller.rb`:

```ruby
class Admin::EntriesController < Admin::BaseController
  def index
    @entrants = Entrant.order(created_at: :desc)
    if params[:q].present?
      query = "%#{params[:q]}%"
      @entrants = @entrants.where(
        "first_name LIKE :q OR last_name LIKE :q OR email LIKE :q OR company LIKE :q",
        q: query
      )
    end

    @total_count = Entrant.count
    @eligible_count = Entrant.eligible.count
    @excluded_count = Entrant.where(eligibility_status: %w[excluded_admin duplicate_review]).count
  end

  def show
    @entrant = Entrant.find(params[:id])
  end

  def exclude
    @entrant = Entrant.find(params[:id])
    @entrant.update!(eligibility_status: "excluded_admin", exclusion_reason: params[:exclusion_reason])
    redirect_to admin_entry_path(@entrant), notice: "Entry excluded."
  end

  def reinstate
    @entrant = Entrant.find(params[:id])
    @entrant.update!(eligibility_status: "reinstated_admin", exclusion_reason: nil)
    redirect_to admin_entry_path(@entrant), notice: "Entry reinstated."
  end
end
```

**Step 5: Create index view**

Create `app/views/admin/entries/index.html.erb`:

```erb
<h1>Entries</h1>

<div class="admin-stats">
  <span>Total: <%= @total_count %></span>
  <span>Eligible: <%= @eligible_count %></span>
  <span>Excluded: <%= @excluded_count %></span>
</div>

<%= form_with(url: admin_root_path, method: :get, local: true) do |f| %>
  <%= f.text_field :q, value: params[:q], placeholder: "Search..." %>
  <%= f.submit "Search" %>
<% end %>

<table>
  <thead>
    <tr>
      <th>Name</th>
      <th>Email</th>
      <th>Company</th>
      <th>Status</th>
      <th>Entered</th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    <% @entrants.each do |entrant| %>
      <tr>
        <td><%= entrant.first_name %></td>
        <td><%= entrant.last_name %></td>
        <td><%= entrant.email %></td>
        <td><%= entrant.company %></td>
        <td><%= entrant.eligibility_status %></td>
        <td><%= entrant.created_at.strftime("%b %d %H:%M") %></td>
        <td><%= link_to "View", admin_entry_path(entrant) %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

**Step 6: Create show view**

Create `app/views/admin/entries/show.html.erb`:

```erb
<h1><%= @entrant.first_name %> <%= @entrant.last_name %></h1>

<dl>
  <dt>Email</dt><dd><%= @entrant.email %></dd>
  <dt>Company</dt><dd><%= @entrant.company %></dd>
  <dt>Job Title</dt><dd><%= @entrant.job_title %></dd>
  <dt>Interest Areas</dt><dd><%= @entrant.interest_areas.join(", ") %></dd>
  <dt>Status</dt><dd><%= @entrant.eligibility_status %></dd>
  <dt>Exclusion Reason</dt><dd><%= @entrant.exclusion_reason %></dd>
  <dt>Entered</dt><dd><%= @entrant.created_at %></dd>
</dl>

<% if @entrant.eligibility_status.in?(%w[eligible duplicate_review reinstated_admin]) %>
  <%= form_with(url: exclude_admin_entry_path(@entrant), method: :patch, local: true) do |f| %>
    <%= f.text_field :exclusion_reason, placeholder: "Reason for exclusion" %>
    <%= f.submit "Exclude" %>
  <% end %>
<% end %>

<% if @entrant.eligibility_status.in?(%w[excluded_admin duplicate_review]) %>
  <%= button_to "Reinstate", reinstate_admin_entry_path(@entrant), method: :patch %>
<% end %>

<%= link_to "Back to entries", admin_root_path %>
```

**Step 7: Run tests**

```bash
bin/rails test test/controllers/admin/entries_controller_test.rb
```

Expected: all pass.

**Step 8: Commit**

```bash
git add -A
git commit -m "feat: add admin entries management with search, exclude, reinstate"
```

---

## Task 10: CSV Export

**Files:**
- Modify: `app/controllers/admin/entries_controller.rb`
- Create: `test/controllers/admin/csv_export_test.rb`
- Modify: `config/routes.rb`

**Step 1: Write the test**

Create `test/controllers/admin/csv_export_test.rb`:

```ruby
require "test_helper"
require "csv"

class Admin::CsvExportTest < ActionDispatch::IntegrationTest
  setup do
    post admin_login_path, params: { password: admin_password }
    Entrant.create!(first_name: "Ada", last_name: "Lovelace", email: "ada@example.com", company: "Babbage", job_title: "Eng", eligibility_confirmed: true, interest_areas: ["Application Security"])
  end

  test "clean export includes only eligible entries" do
    Entrant.create!(first_name: "Ex", last_name: "Cluded", email: "ex@x.com", company: "X", job_title: "X", eligibility_confirmed: true, eligibility_status: "excluded_admin")

    get admin_export_path(format: :csv, type: "clean")
    assert_response :success
    assert_equal "text/csv", response.content_type

    csv = CSV.parse(response.body, headers: true)
    assert_equal 1, csv.size
    assert_equal "Ada", csv[0]["first_name"]
  end

  test "raw export includes all entries" do
    Entrant.create!(first_name: "Ex", last_name: "Cluded", email: "ex@x.com", company: "X", job_title: "X", eligibility_confirmed: true, eligibility_status: "excluded_admin")

    get admin_export_path(format: :csv, type: "raw")
    assert_response :success

    csv = CSV.parse(response.body, headers: true)
    assert_equal 2, csv.size
  end

  test "export filename includes timestamp" do
    get admin_export_path(format: :csv, type: "clean")
    assert_match /raffle-entries-clean-\d{4}/, response.headers["Content-Disposition"]
  end

  private

  def admin_password
    Rails.application.credentials.admin_password || ENV.fetch("ADMIN_PASSWORD", "test_admin_pw")
  end
end
```

**Step 2: Run tests to verify they fail**

```bash
bin/rails test test/controllers/admin/csv_export_test.rb
```

**Step 3: Add export route**

Add inside the `admin` namespace in `config/routes.rb`:

```ruby
get "export", to: "entries#export"
```

**Step 4: Add export action to entries controller**

Add to `Admin::EntriesController`:

```ruby
def export
  entrants = params[:type] == "raw" ? Entrant.all : Entrant.eligible
  filename = "raffle-entries-#{params[:type]}-#{Time.current.strftime('%Y%m%d-%H%M%S')}.csv"

  csv_data = CSV.generate(headers: true) do |csv|
    csv << %w[first_name last_name email company job_title interest_areas created_at eligibility_status]
    entrants.find_each do |e|
      csv << [e.first_name, e.last_name, e.email, e.company, e.job_title,
              e.interest_areas.join("; "), e.created_at.iso8601, e.eligibility_status]
    end
  end

  send_data csv_data, filename: filename, type: "text/csv"
end
```

Add `require "csv"` at the top of the controller file.

**Step 5: Run tests**

```bash
bin/rails test test/controllers/admin/csv_export_test.rb
```

Expected: all pass.

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add CSV export with clean and raw modes"
```

---

## Task 11: Raffle Draw Model and Admin UI

**Files:**
- Create: `db/migrate/TIMESTAMP_create_raffle_draws.rb`
- Create: `app/models/raffle_draw.rb`
- Create: `test/models/raffle_draw_test.rb`
- Create: `app/controllers/admin/raffle_controller.rb`
- Create: `app/views/admin/raffle/show.html.erb`
- Create: `test/controllers/admin/raffle_controller_test.rb`
- Modify: `config/routes.rb`

**Step 1: Write model test**

Create `test/models/raffle_draw_test.rb`:

```ruby
require "test_helper"

class RaffleDrawTest < ActiveSupport::TestCase
  setup do
    3.times do |i|
      Entrant.create!(first_name: "User#{i}", last_name: "Test", email: "user#{i}@example.com",
                      company: "Co", job_title: "Dev", eligibility_confirmed: true)
    end
    Entrant.create!(first_name: "Excluded", last_name: "User", email: "ex@example.com",
                    company: "Co", job_title: "Dev", eligibility_confirmed: true, eligibility_status: "excluded_admin")
  end

  test "perform_draw selects a winner from eligible entries" do
    draw = RaffleDraw.perform_draw!
    assert draw.persisted?
    assert_equal 3, draw.eligible_count
    assert draw.winner.present?
    assert_equal "winner", draw.winner.eligibility_status
  end

  test "perform_draw does not select excluded entries" do
    10.times do
      draw = RaffleDraw.perform_draw!
      assert_not_equal "Excluded", draw.winner.first_name
      # Reset for next iteration
      draw.winner.update!(eligibility_status: "eligible")
      draw.destroy!
    end
  end

  test "alternate draw excludes previous winners" do
    first_draw = RaffleDraw.perform_draw!
    second_draw = RaffleDraw.perform_draw!

    assert_equal "alternate_winner", second_draw.winner.eligibility_status
    assert_not_equal first_draw.winner_id, second_draw.winner_id
  end

  test "draw fails when no eligible entries" do
    Entrant.eligible.update_all(eligibility_status: "excluded_admin")
    assert_raises(RaffleDraw::NoEligibleEntrants) do
      RaffleDraw.perform_draw!
    end
  end
end
```

**Step 2: Run tests to verify they fail**

```bash
bin/rails test test/models/raffle_draw_test.rb
```

**Step 3: Generate migration**

```bash
bin/rails generate migration CreateRaffleDraws
```

Edit:

```ruby
class CreateRaffleDraws < ActiveRecord::Migration[8.0]
  def change
    create_table :raffle_draws do |t|
      t.references :winner, null: false, foreign_key: { to_table: :entrants }
      t.integer :eligible_count, null: false
      t.string :draw_type, null: false, default: "winner"
      t.text :admin_note

      t.timestamps
    end
  end
end
```

**Step 4: Create model**

Create `app/models/raffle_draw.rb`:

```ruby
class RaffleDraw < ApplicationRecord
  class NoEligibleEntrants < StandardError; end

  belongs_to :winner, class_name: "Entrant"

  validates :eligible_count, presence: true
  validates :draw_type, inclusion: { in: %w[winner alternate_winner] }

  def self.perform_draw!(admin_note: nil)
    eligible = Entrant.eligible.where.not(eligibility_status: %w[winner alternate_winner])
    raise NoEligibleEntrants, "No eligible entrants for drawing" if eligible.empty?

    is_alternate = RaffleDraw.exists?
    selected = eligible.offset(SecureRandom.random_number(eligible.count)).first
    status = is_alternate ? "alternate_winner" : "winner"

    transaction do
      selected.update!(eligibility_status: status)
      create!(
        winner: selected,
        eligible_count: eligible.count,
        draw_type: status,
        admin_note: admin_note
      )
    end
  end
end
```

Add to `app/models/entrant.rb`:

```ruby
has_many :raffle_draws, foreign_key: :winner_id
```

**Step 5: Run migration and tests**

```bash
bin/rails db:migrate
bin/rails test test/models/raffle_draw_test.rb
```

Expected: all pass.

**Step 6: Write controller test**

Create `test/controllers/admin/raffle_controller_test.rb`:

```ruby
require "test_helper"

class Admin::RaffleControllerTest < ActionDispatch::IntegrationTest
  setup do
    post admin_login_path, params: { password: admin_password }
    3.times do |i|
      Entrant.create!(first_name: "User#{i}", last_name: "Test", email: "u#{i}@x.com",
                      company: "Co", job_title: "Dev", eligibility_confirmed: true)
    end
  end

  test "show displays draw dashboard" do
    get admin_raffle_path
    assert_response :success
    assert_select "button", text: /Draw Winner/i
  end

  test "draw creates a raffle draw and shows winner" do
    post admin_raffle_draw_path
    assert_redirected_to admin_raffle_path
    follow_redirect!
    assert_response :success
    assert_equal 1, RaffleDraw.count
  end

  test "draw with no eligible entries shows error" do
    Entrant.update_all(eligibility_status: "excluded_admin")
    post admin_raffle_draw_path
    assert_redirected_to admin_raffle_path
    follow_redirect!
    assert_select ".alert", /no eligible/i
  end

  private

  def admin_password
    Rails.application.credentials.admin_password || ENV.fetch("ADMIN_PASSWORD", "test_admin_pw")
  end
end
```

**Step 7: Add routes**

Add inside `admin` namespace:

```ruby
resource :raffle, only: [:show], controller: "raffle" do
  post :draw
end
```

**Step 8: Create controller**

Create `app/controllers/admin/raffle_controller.rb`:

```ruby
class Admin::RaffleController < Admin::BaseController
  def show
    @total_count = Entrant.count
    @eligible_count = Entrant.eligible.where.not(eligibility_status: %w[winner alternate_winner]).count
    @excluded_count = Entrant.where(eligibility_status: %w[excluded_admin duplicate_review]).count
    @draws = RaffleDraw.includes(:winner).order(created_at: :desc)
  end

  def draw
    draw = RaffleDraw.perform_draw!
    redirect_to admin_raffle_path, notice: "Winner drawn: #{draw.winner.first_name} #{draw.winner.last_name}"
  rescue RaffleDraw::NoEligibleEntrants
    redirect_to admin_raffle_path, alert: "No eligible entrants for drawing."
  end
end
```

**Step 9: Create view**

Create `app/views/admin/raffle/show.html.erb`:

```erb
<h1>Raffle Drawing</h1>

<% if flash[:alert] %>
  <p class="alert"><%= flash[:alert] %></p>
<% end %>
<% if flash[:notice] %>
  <p class="notice"><%= flash[:notice] %></p>
<% end %>

<div class="admin-stats">
  <span>Total entries: <%= @total_count %></span>
  <span>Eligible for draw: <%= @eligible_count %></span>
  <span>Excluded: <%= @excluded_count %></span>
</div>

<%= button_to "Draw Winner", admin_raffle_draw_path, method: :post,
    data: { turbo_confirm: "Draw a winner from #{@eligible_count} eligible entries?" } %>

<% if @draws.any? %>
  <h2>Draw History</h2>
  <table>
    <thead>
      <tr><th>Date</th><th>Type</th><th>Winner</th><th>Eligible Pool</th><th>Note</th></tr>
    </thead>
    <tbody>
      <% @draws.each do |d| %>
        <tr>
          <td><%= d.created_at.strftime("%b %d %H:%M") %></td>
          <td><%= d.draw_type %></td>
          <td><%= link_to "#{d.winner.first_name} #{d.winner.last_name}", admin_entry_path(d.winner) %></td>
          <td><%= d.eligible_count %></td>
          <td><%= d.admin_note %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
<% end %>
```

**Step 10: Run tests**

```bash
bin/rails test test/controllers/admin/raffle_controller_test.rb
```

Expected: all pass.

**Step 11: Commit**

```bash
git add -A
git commit -m "feat: add raffle drawing system with audit trail"
```

---

## Task 12: USB Backup System

**Files:**
- Create: `bin/backup_to_usb`
- Create: `test/services/usb_backup_test.rb`
- Create: `app/services/usb_backup.rb`

**Step 1: Write the test**

Create `test/services/usb_backup_test.rb`:

```ruby
require "test_helper"

class UsbBackupTest < ActiveSupport::TestCase
  setup do
    @backup_dir = Rails.root.join("tmp", "test_backup")
    FileUtils.mkdir_p(@backup_dir)
  end

  teardown do
    FileUtils.rm_rf(@backup_dir)
  end

  test "performs backup when target dir exists" do
    result = UsbBackup.perform(target_dir: @backup_dir)
    assert result[:success]
    assert File.exist?(File.join(@backup_dir, "raffle.sqlite3"))
  end

  test "copies JSONL log if it exists" do
    log_path = Rails.root.join("log", "submissions.jsonl")
    File.write(log_path, '{"test": true}\n')

    result = UsbBackup.perform(target_dir: @backup_dir)
    assert result[:success]
    assert File.exist?(File.join(@backup_dir, "submissions.jsonl"))
  ensure
    log_path.delete if log_path.exist?
  end

  test "returns failure when target dir does not exist" do
    result = UsbBackup.perform(target_dir: "/nonexistent/path")
    assert_not result[:success]
  end

  test "records backup timestamp" do
    UsbBackup.perform(target_dir: @backup_dir)
    status = UsbBackup.last_status
    assert status[:last_backup_at].present?
    assert status[:success]
  end
end
```

**Step 2: Run tests to verify they fail**

```bash
bin/rails test test/services/usb_backup_test.rb
```

**Step 3: Implement the service**

Create `app/services/usb_backup.rb`:

```ruby
class UsbBackup
  STATUS_FILE = Rails.root.join("tmp", "backup_status.json")
  USB_LABEL = "RAFFLE_BACKUP"

  def self.perform(target_dir: find_usb_mount)
    return failure("No backup target found") unless target_dir && Dir.exist?(target_dir.to_s)

    db_path = ActiveRecord::Base.connection_db_config.database
    backup_db_path = File.join(target_dir, "raffle.sqlite3")

    # Use SQLite backup API via command line for consistency
    system("sqlite3", db_path, ".backup '#{backup_db_path}'")

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

  def self.last_status
    return {} unless STATUS_FILE.exist?
    JSON.parse(STATUS_FILE.read, symbolize_names: true)
  end

  def self.find_usb_mount
    # Look for mounted filesystem with RAFFLE_BACKUP label
    mount_point = `findmnt -rn -S LABEL=#{USB_LABEL} -o TARGET 2>/dev/null`.strip
    mount_point.empty? ? nil : mount_point
  end

  private

  def self.failure(message)
    { success: false, error: message }
  end

  def self.record_status(success:, error: nil)
    status = { success: success, last_backup_at: Time.current.iso8601, error: error }
    File.write(STATUS_FILE, status.to_json)
  end
end
```

**Step 4: Create the backup script**

Create `bin/backup_to_usb`:

```bash
#!/usr/bin/env bash
# Called by cron every 5 minutes to back up to USB if present
set -euo pipefail

cd "$(dirname "$0")/.."
RAILS_ENV="${RAILS_ENV:-production}"

exec bin/rails runner "UsbBackup.perform"
```

Make it executable:

```bash
chmod +x bin/backup_to_usb
```

**Step 5: Run tests**

```bash
bin/rails test test/services/usb_backup_test.rb
```

Expected: all pass.

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add USB backup service with status tracking"
```

---

## Task 13: Admin Dashboard (Backup Status + Navigation)

**Files:**
- Modify: `app/views/admin/entries/index.html.erb`
- Create: `app/views/admin/shared/_nav.html.erb`
- Modify: `app/controllers/admin/entries_controller.rb`

**Step 1: Add backup status to entries controller index**

Add to the `index` action:

```ruby
@backup_status = UsbBackup.last_status
```

**Step 2: Create admin nav partial**

Create `app/views/admin/shared/_nav.html.erb`:

```erb
<nav class="admin-nav">
  <%= link_to "Entries", admin_root_path %>
  <%= link_to "Raffle", admin_raffle_path %>
  <%= link_to "Export (Clean)", admin_export_path(format: :csv, type: "clean") %>
  <%= link_to "Export (Raw)", admin_export_path(format: :csv, type: "raw") %>
  <%= button_to "Logout", admin_logout_path, method: :delete %>
</nav>
```

**Step 3: Add backup status display to index view**

Add to `app/views/admin/entries/index.html.erb`:

```erb
<div class="backup-status">
  <% if @backup_status[:success] %>
    Last backup: <%= @backup_status[:last_backup_at] %> — OK
  <% elsif @backup_status[:error] %>
    Backup error: <%= @backup_status[:error] %>
  <% else %>
    No backup recorded
  <% end %>
</div>
```

**Step 4: Include nav in all admin views**

Add `<%= render "admin/shared/nav" %>` at the top of each admin view.

**Step 5: Run all tests**

```bash
bin/rails test
```

Expected: all pass.

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add admin navigation and backup status display"
```

---

## Task 14: Admin UI Styling

**Files:**
- Create: `app/assets/stylesheets/admin.css`
- Modify: admin views as needed

> **Note:** Use the `frontend-design` skill for this task. The admin interface should be functional and clean. It will be viewed on the same 10.1" touchscreen or on a laptop via SSH tunnel. Prioritize readability and clear data presentation. Light theme is fine for admin (distinct from the kiosk dark theme).

**Step 1: Style the admin interface**

- Clean table styling with alternating rows
- Status badges with color coding (eligible=green, excluded=red, duplicate_review=yellow, winner=blue)
- Touch-friendly buttons and form fields
- Stats cards for entry counts
- Responsive layout that works on the 10.1" screen

**Step 2: Run all tests**

```bash
bin/rails test
```

Expected: all pass.

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add admin UI styling"
```

---

## Task 15: Kiosk Setup Script

**Files:**
- Create: `bin/setup_kiosk`
- Create: `config/systemd/raffle-kiosk.service`
- Create: `config/kiosk/wayfire.ini`
- Create: `config/kiosk/chromium-kiosk.sh`
- Create: `config/kiosk/autostart`

**Step 1: Create the systemd service file**

Create `config/systemd/raffle-kiosk.service`:

```ini
[Unit]
Description=Raffle Entry Collector Rails App
After=network.target

[Service]
Type=simple
User=andre
WorkingDirectory=/home/andre/RaffleEntryCollector
Environment=RAILS_ENV=production
Environment=SECRET_KEY_BASE=GENERATE_ME
Environment=ADMIN_PASSWORD=CHANGE_ME
ExecStart=/home/andre/.rbenv/shims/bundle exec rails server -b 127.0.0.1 -p 3000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**Step 2: Create Chromium kiosk launch script**

Create `config/kiosk/chromium-kiosk.sh`:

```bash
#!/usr/bin/env bash
# Wait for Rails to be ready
until curl -s http://127.0.0.1:3000 > /dev/null 2>&1; do
  sleep 1
done

exec chromium-browser \
  --kiosk \
  --noerrdialogs \
  --disable-translate \
  --no-first-run \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-features=TranslateUI \
  --autoplay-policy=no-user-gesture-required \
  --disable-component-update \
  --check-for-update-interval=31536000 \
  http://127.0.0.1:3000
```

**Step 3: Create Wayfire kiosk config overlay**

Create `config/kiosk/wayfire.ini` with shortcut blocking (this will be merged with or replace the kiosk user's Wayfire config):

```ini
[command]
# Disable common escape shortcuts
binding_close = none
binding_terminal = none

[core]
# Minimal plugins for kiosk
plugins = autostart
```

**Step 4: Create kiosk autostart config**

Create `config/kiosk/autostart`:

```ini
[autostart]
chromium = /home/andre/RaffleEntryCollector/config/kiosk/chromium-kiosk.sh
```

**Step 5: Create the setup script**

Create `bin/setup_kiosk`:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUBY_VERSION="$(cat "$APP_DIR/.ruby-version")"

echo "=== Raffle Kiosk Setup ==="

# 1. System dependencies
echo "--- Installing system packages ---"
sudo apt-get update -qq
sudo apt-get install -y -qq \
  build-essential libsqlite3-dev libssl-dev libreadline-dev zlib1g-dev \
  libyaml-dev sqlite3 curl git chromium-browser

# 2. Create kiosk user if not exists
if ! id -u kiosk &>/dev/null; then
  echo "--- Creating kiosk user ---"
  sudo useradd -m -s /bin/bash kiosk
  # Configure auto-login for kiosk user
  sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
  sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null <<LOGINEOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin kiosk --noclear %I \$TERM
LOGINEOF
fi

# 3. rbenv (if not installed)
if [ ! -d "$HOME/.rbenv" ]; then
  echo "--- Installing rbenv ---"
  git clone https://github.com/rbenv/rbenv.git "$HOME/.rbenv"
  git clone https://github.com/rbenv/ruby-build.git "$HOME/.rbenv/plugins/ruby-build"
  echo 'eval "$($HOME/.rbenv/bin/rbenv init - bash)"' >> "$HOME/.bashrc"
  export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"
  eval "$(rbenv init - bash)"
fi

# 4. Ruby (if not installed)
export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"
eval "$(rbenv init - bash)" 2>/dev/null || true
if ! rbenv versions | grep -q "$RUBY_VERSION"; then
  echo "--- Installing Ruby $RUBY_VERSION (this takes ~15min on Pi) ---"
  rbenv install "$RUBY_VERSION"
fi
rbenv global "$RUBY_VERSION"

# 5. Bundle
echo "--- Installing gems ---"
cd "$APP_DIR"
gem install bundler --no-document
bundle install --deployment --without development test

# 6. Database
echo "--- Setting up database ---"
RAILS_ENV=production bin/rails db:create db:migrate 2>/dev/null || bin/rails db:migrate

# 7. Precompile assets
echo "--- Precompiling assets ---"
RAILS_ENV=production bin/rails assets:precompile

# 8. Install systemd service
echo "--- Installing systemd service ---"
sudo cp "$APP_DIR/config/systemd/raffle-kiosk.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable raffle-kiosk

# 9. Configure kiosk user Wayfire
echo "--- Configuring kiosk desktop ---"
sudo mkdir -p /home/kiosk/.config
sudo cp "$APP_DIR/config/kiosk/wayfire.ini" /home/kiosk/.config/wayfire.ini
sudo mkdir -p /home/kiosk/.config/wayfire
sudo cp "$APP_DIR/config/kiosk/autostart" /home/kiosk/.config/wayfire/autostart
sudo chown -R kiosk:kiosk /home/kiosk/.config

# 10. Make kiosk scripts executable
chmod +x "$APP_DIR/config/kiosk/chromium-kiosk.sh"
chmod +x "$APP_DIR/bin/backup_to_usb"

# 11. USB backup cron (every 5 minutes)
echo "--- Setting up backup cron ---"
(crontab -l 2>/dev/null | grep -v backup_to_usb; echo "*/5 * * * * $APP_DIR/bin/backup_to_usb") | crontab -

echo "=== Setup complete ==="
echo "Next steps:"
echo "  1. Edit /etc/systemd/system/raffle-kiosk.service to set SECRET_KEY_BASE and ADMIN_PASSWORD"
echo "  2. sudo systemctl start raffle-kiosk"
echo "  3. Reboot to test kiosk auto-login"
```

Make it executable:

```bash
chmod +x bin/setup_kiosk
```

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add kiosk setup script, systemd service, and Wayfire config"
```

---

## Task 16: Update DEVELOPMENT_PLAN.md

**Files:**
- Modify: `DEVELOPMENT_PLAN.md`

**Step 1: Update the development plan**

Update Section 2 (Technology Stack) to reflect confirmed decisions:
- Ruby 3.3 via rbenv
- Rails 8 with Hotwire (Turbo + Stimulus)
- No JS build pipeline

Update Section 6 (Data Model) to reflect:
- `interest_areas` is a JSON column (not "array or join table")
- Add `raffle_draws` table

Update Section 7 (Admin Console) to reflect:
- Password-based auth on `/admin` route
- Session-based, no user model

Update Section 9 (Data Integrity) to reflect:
- JSONL append log format
- USB backup by drive label `RAFFLE_BACKUP` (not UUID)
- 5-minute backup interval

Update Section 13 (Raspberry Pi Deployment) to reflect:
- `kiosk` user for Chromium, `andre` user for Rails
- Wayfire shortcut blocking
- systemd service
- Setup script in repo

Add Section 17 — References:
```
## 17. Design & Implementation Documents

- `docs/plans/2026-03-14-architecture-design.md` — Architecture decisions
- `docs/plans/2026-03-14-implementation-plan.md` — Step-by-step implementation plan
- `CLAUDE.md` — Development guide for AI-assisted coding
```

**Step 2: Commit**

```bash
git add DEVELOPMENT_PLAN.md
git commit -m "docs: update DEVELOPMENT_PLAN.md with confirmed architecture decisions"
```

---

## Task 17: Full Test Suite Run and Cleanup

**Step 1: Run entire test suite**

```bash
bin/rails test
bin/rails test:system
```

All tests must pass.

**Step 2: Fix any failures**

Address any test failures found.

**Step 3: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve test suite issues from integration"
```

---

## Summary

| Task | Description | Depends On |
|------|-------------|------------|
| 1 | Rails project scaffold | — |
| 2 | Entrant model + migration | 1 |
| 3 | Duplicate detection service | 2 |
| 4 | Submission logger (JSONL) | 2 |
| 5 | Kiosk controller + routes | 2, 3, 4 |
| 6 | Kiosk UI styling | 5 |
| 7 | Stimulus controllers | 6 |
| 8 | Admin authentication | 1 |
| 9 | Admin entries management | 2, 8 |
| 10 | CSV export | 9 |
| 11 | Raffle draw system | 2, 8 |
| 12 | USB backup service | 1 |
| 13 | Admin dashboard + nav | 9, 11, 12 |
| 14 | Admin UI styling | 13 |
| 15 | Kiosk setup script | all app tasks |
| 16 | Update DEVELOPMENT_PLAN.md | all |
| 17 | Full test suite run | all |
