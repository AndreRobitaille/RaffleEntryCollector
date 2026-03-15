# Admin Entries Management — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the admin entries list with search, sortable columns, detail view, and exclude/reinstate actions (GitHub Issue #9).

**Architecture:** Turbo Frames for responsive partial-page updates. Server-rendered views with a debounced search Stimulus controller. Separate admin layout with gradient header bar. All actions go through `Admin::EntriesController` inheriting auth from `Admin::BaseController`.

**Tech Stack:** Rails 8, SQLite3, Turbo Frames, Stimulus, Minitest

**Spec:** `docs/superpowers/specs/2026-03-15-admin-entries-management-design.md`

---

## File Map

**Create:**
- `app/views/layouts/admin.html.erb` — admin layout with gradient header bar
- `app/assets/stylesheets/admin.css` — admin-specific styles
- `app/views/admin/entries/show.html.erb` — entry detail view
- `app/views/admin/entries/_entries_table.html.erb` — Turbo Frame partial for the sortable entries table
- `app/javascript/controllers/search_form_controller.js` — debounced search auto-submit
- `test/controllers/admin/entries_controller_test.rb` — controller tests

**Modify:**
- `config/routes.rb` — add entry resource routes inside admin namespace
- `app/models/entrant.rb` — add `:excluded` scope
- `app/controllers/admin/entries_controller.rb` — replace stub with full controller
- `app/views/admin/entries/index.html.erb` — replace placeholder with real index view
- `test/fixtures/entrants.yml` — add fixtures for various eligibility statuses

---

## Chunk 1: Model, Routes, Fixtures

### Task 1: Add `:excluded` scope and test fixtures

**Files:**
- Modify: `app/models/entrant.rb:33` (add scope after `:duplicates`)
- Modify: `test/fixtures/entrants.yml` (add fixtures for all status types)

- [ ] **Step 1: Add the `:excluded` scope to Entrant**

In `app/models/entrant.rb`, add after line 33 (the `:duplicates` scope):

```ruby
scope :excluded, -> { where(eligibility_status: "excluded_admin") }
```

- [ ] **Step 2: Add test fixtures for various eligibility statuses**

Replace `test/fixtures/entrants.yml` with fixtures covering the statuses we need for testing:

```yaml
ada:
  first_name: Ada
  last_name: Lovelace
  email: ada@example.com
  company: Babbage Inc
  job_title: Engineer
  eligibility_confirmed: true
  eligibility_status: eligible
  interest_areas:
    - "Penetration Testing"
    - "Application Security"

grace:
  first_name: Grace
  last_name: Hopper
  email: grace@example.com
  company: US Navy
  job_title: Admiral
  eligibility_confirmed: true
  eligibility_status: eligible
  interest_areas:
    - "Security Training"

duplicate_alan:
  first_name: Alan
  last_name: Turing
  email: alan@example.com
  company: Bletchley Park
  job_title: Cryptanalyst
  eligibility_confirmed: true
  eligibility_status: duplicate_review
  interest_areas:
    - "Hardware / IoT Security"

excluded_eve:
  first_name: Eve
  last_name: Hacker
  email: eve@sponsor.com
  company: CypherCon Sponsor LLC
  job_title: Marketing
  eligibility_confirmed: true
  eligibility_status: excluded_admin
  exclusion_reason: CypherCon sponsor employee
  interest_areas: []

ineligible_bob:
  first_name: Bob
  last_name: Nocheck
  email: bob@example.com
  company: Independent
  job_title: Student
  eligibility_confirmed: true
  eligibility_status: self_attested_ineligible
  interest_areas: []
```

- [ ] **Step 3: Run existing tests to make sure fixtures don't break anything**

Run: `bin/rails test`
Expected: All existing tests pass.

- [ ] **Step 4: Commit**

```bash
git add app/models/entrant.rb test/fixtures/entrants.yml
git commit -m "feat: add excluded scope and expand test fixtures for admin entries

Closes #9 (partial)"
```

### Task 2: Add entry resource routes

**Files:**
- Modify: `config/routes.rb:8-13` (admin namespace block)

- [ ] **Step 1: Add the resources routes**

In `config/routes.rb`, update the admin namespace block to:

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
end
```

- [ ] **Step 2: Verify routes exist**

Run: `bin/rails routes | grep admin`
Expected: See routes for `admin_entries`, `admin_entry`, `exclude_admin_entry`, `reinstate_admin_entry` alongside the existing `admin_root`, `admin_login`, `admin_logout`.

- [ ] **Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "feat: add admin entry management routes (index, show, exclude, reinstate)"
```

---

## Chunk 2: Controller with TDD

### Task 3: Write auth gate tests

**Files:**
- Create: `test/controllers/admin/entries_controller_test.rb`

- [ ] **Step 1: Write the auth gate tests**

Create `test/controllers/admin/entries_controller_test.rb`:

```ruby
require "test_helper"

class Admin::EntriesControllerTest < ActionDispatch::IntegrationTest
  test "GET /admin/entries without auth redirects to login" do
    get admin_entries_path
    assert_redirected_to admin_login_path
  end

  test "GET /admin/entries/:id without auth redirects to login" do
    get admin_entry_path(entrants(:ada))
    assert_redirected_to admin_login_path
  end

  test "PATCH /admin/entries/:id/exclude without auth redirects to login" do
    patch exclude_admin_entry_path(entrants(:ada))
    assert_redirected_to admin_login_path
  end

  test "PATCH /admin/entries/:id/reinstate without auth redirects to login" do
    patch reinstate_admin_entry_path(entrants(:excluded_eve))
    assert_redirected_to admin_login_path
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

- [ ] **Step 2: Run tests to verify they fail (show and member routes not yet handled)**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb`
Expected: Auth gate tests for index should pass (controller exists with inherited auth). The show/exclude/reinstate tests should fail with routing or action errors since those actions don't exist yet.

- [ ] **Step 3: Commit**

```bash
git add test/controllers/admin/entries_controller_test.rb
git commit -m "test: add auth gate tests for admin entries controller"
```

### Task 4: Write index tests and implement index action

**Files:**
- Modify: `test/controllers/admin/entries_controller_test.rb`
- Modify: `app/controllers/admin/entries_controller.rb`

- [ ] **Step 1: Write index tests**

Add to `test/controllers/admin/entries_controller_test.rb`, inside the class:

```ruby
test "GET /admin/entries shows entries and stats" do
  login_as_admin
  get admin_entries_path
  assert_response :success
  assert_select "table" do
    assert_select "tr td", text: "Ada"
    assert_select "tr td", text: "Grace"
  end
end

test "GET /admin/entries with search filters by name" do
  login_as_admin
  get admin_entries_path, params: { q: "Ada" }
  assert_response :success
  assert_select "table tr td", text: "Ada"
  assert_select "table tr td", text: "Grace", count: 0
end

test "GET /admin/entries with search filters by email" do
  login_as_admin
  get admin_entries_path, params: { q: "grace@example" }
  assert_response :success
  assert_select "table tr td", text: "Grace"
  assert_select "table tr td", text: "Ada", count: 0
end

test "GET /admin/entries with search filters by company" do
  login_as_admin
  get admin_entries_path, params: { q: "Babbage" }
  assert_response :success
  assert_select "table tr td", text: "Ada"
  assert_select "table tr td", text: "Grace", count: 0
end

test "GET /admin/entries default sort is company ascending" do
  login_as_admin
  get admin_entries_path
  assert_response :success
  # Babbage Inc comes before Bletchley Park, CypherCon Sponsor LLC, etc.
  rows = css_select("table tbody tr td:nth-child(4)")
  companies = rows.map(&:text).map(&:strip)
  assert_equal companies, companies.sort
end

test "GET /admin/entries respects sort params" do
  login_as_admin
  get admin_entries_path, params: { sort: "last_name", dir: "desc" }
  assert_response :success
  rows = css_select("table tbody tr td:nth-child(3)")
  last_names = rows.map(&:text).map(&:strip)
  assert_equal last_names, last_names.sort.reverse
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb`
Expected: Index tests fail because the index action doesn't set `@entrants` or render a real table.

- [ ] **Step 3: Implement the index action**

Replace `app/controllers/admin/entries_controller.rb`:

```ruby
class Admin::EntriesController < Admin::BaseController
  SORTABLE_COLUMNS = %w[first_name last_name company eligibility_status email created_at].freeze

  def index
    @entrants = Entrant.all

    if params[:q].present?
      query = "%#{params[:q]}%"
      @entrants = @entrants.where(
        "first_name LIKE ? OR last_name LIKE ? OR email LIKE ? OR company LIKE ?",
        query, query, query, query
      )
    end

    default_sort = params[:q].present? ? "last_name" : "company"
    sort_column = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : default_sort
    sort_direction = params[:dir] == "desc" ? "desc" : "asc"
    @entrants = @entrants.order("#{sort_column} #{sort_direction}")

    @sort_column = sort_column
    @sort_direction = sort_direction
    @query = params[:q]

    @total_count = Entrant.count
    @eligible_count = Entrant.eligible.count
    @excluded_count = Entrant.excluded.count
    @duplicate_count = Entrant.duplicates.count
  end
end
```

- [ ] **Step 4: Create a minimal index view to make tests pass**

Replace `app/views/admin/entries/index.html.erb`:

```erb
<div class="admin-stats">
  <div class="admin-stat">
    <span class="admin-stat__label">Total</span>
    <span class="admin-stat__count"><%= @total_count %></span>
  </div>
  <div class="admin-stat">
    <span class="admin-stat__label">Eligible</span>
    <span class="admin-stat__count admin-stat__count--eligible"><%= @eligible_count %></span>
  </div>
  <div class="admin-stat">
    <span class="admin-stat__label">Excluded</span>
    <span class="admin-stat__count admin-stat__count--excluded"><%= @excluded_count %></span>
  </div>
  <div class="admin-stat">
    <span class="admin-stat__label">Duplicates</span>
    <span class="admin-stat__count admin-stat__count--duplicate"><%= @duplicate_count %></span>
  </div>
</div>

<%= form_with url: admin_entries_path, method: :get, data: { controller: "search-form", turbo_frame: "entries_table" } do |f| %>
  <%= f.search_field :q, value: @query, placeholder: "Search by name, email, or company...", class: "admin-search__input", data: { search_form_target: "input", action: "input->search-form#search" } %>
<% end %>

<%= turbo_frame_tag "entries_table" do %>
  <%= render "entries_table" %>
<% end %>
```

- [ ] **Step 5: Create the entries table partial**

Create `app/views/admin/entries/_entries_table.html.erb`:

```erb
<% sort_link = ->(column, label) do
  next_dir = (@sort_column == column.to_s && @sort_direction == "asc") ? "desc" : "asc"
  indicator = if @sort_column == column.to_s
    @sort_direction == "asc" ? " ▲" : " ▼"
  else
    ""
  end
  active_class = @sort_column == column.to_s ? "admin-table__th--active" : ""
  link_to "#{label}#{indicator}".html_safe,
    admin_entries_path(sort: column, dir: next_dir, q: @query),
    class: "admin-table__sort #{active_class}",
    data: { turbo_frame: "entries_table" }
end %>

<table class="admin-table">
  <thead>
    <tr>
      <th class="admin-table__th admin-table__th--view"></th>
      <th class="admin-table__th"><%= sort_link.call(:first_name, "First") %></th>
      <th class="admin-table__th"><%= sort_link.call(:last_name, "Last") %></th>
      <th class="admin-table__th"><%= sort_link.call(:company, "Company") %></th>
      <th class="admin-table__th"><%= sort_link.call(:eligibility_status, "Status") %></th>
      <th class="admin-table__th"><%= sort_link.call(:email, "Email") %></th>
      <th class="admin-table__th"><%= sort_link.call(:created_at, "Date") %></th>
    </tr>
  </thead>
  <tbody>
    <% @entrants.each do |entrant| %>
      <tr class="admin-table__row">
        <td class="admin-table__td admin-table__td--view">
          <%= link_to "View", admin_entry_path(entrant), class: "admin-table__view-btn" %>
        </td>
        <td class="admin-table__td"><%= entrant.first_name %></td>
        <td class="admin-table__td"><%= entrant.last_name %></td>
        <td class="admin-table__td"><%= entrant.company %></td>
        <td class="admin-table__td">
          <span class="admin-status-pill admin-status-pill--<%= entrant.eligibility_status %>">
            <%= entrant.eligibility_status %>
          </span>
        </td>
        <td class="admin-table__td admin-table__td--email"><%= entrant.email %></td>
        <td class="admin-table__td admin-table__td--date"><%= entrant.created_at.strftime("%b %d, %H:%M") %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

- [ ] **Step 6: Run index tests**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb`
Expected: All index tests pass. Auth gate tests for show/exclude/reinstate may still fail.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/admin/entries_controller.rb app/views/admin/entries/index.html.erb app/views/admin/entries/_entries_table.html.erb test/controllers/admin/entries_controller_test.rb
git commit -m "feat: implement admin entries index with search and sortable columns"
```

### Task 5: Write show tests and implement show action

**Files:**
- Modify: `test/controllers/admin/entries_controller_test.rb`
- Modify: `app/controllers/admin/entries_controller.rb`
- Create: `app/views/admin/entries/show.html.erb`

- [ ] **Step 1: Write show tests**

Add to `test/controllers/admin/entries_controller_test.rb`:

```ruby
test "GET /admin/entries/:id shows entry detail" do
  login_as_admin
  get admin_entry_path(entrants(:ada))
  assert_response :success
  assert_select "h2", text: /Ada Lovelace/
  assert_select ".admin-detail__value", text: "ada@example.com"
  assert_select ".admin-detail__value", text: "Babbage Inc"
  assert_select ".admin-detail__value", text: "Engineer"
end

test "GET /admin/entries/:id shows interest areas" do
  login_as_admin
  get admin_entry_path(entrants(:ada))
  assert_response :success
  assert_select ".admin-interest-tag", text: "Penetration Testing"
  assert_select ".admin-interest-tag", text: "Application Security"
end

test "GET /admin/entries/:id shows exclude form for eligible entry" do
  login_as_admin
  get admin_entry_path(entrants(:ada))
  assert_response :success
  assert_select ".admin-action--exclude form"
end

test "GET /admin/entries/:id shows reinstate button for excluded entry" do
  login_as_admin
  get admin_entry_path(entrants(:excluded_eve))
  assert_response :success
  assert_select ".admin-action--reinstate form"
  assert_select ".admin-detail__value", text: "CypherCon sponsor employee"
end

test "GET /admin/entries/:id shows both actions for duplicate_review entry" do
  login_as_admin
  get admin_entry_path(entrants(:duplicate_alan))
  assert_response :success
  assert_select ".admin-action--exclude form"
  assert_select ".admin-action--reinstate form"
end

test "GET /admin/entries/:id shows info box for self_attested_ineligible" do
  login_as_admin
  get admin_entry_path(entrants(:ineligible_bob))
  assert_response :success
  assert_select ".admin-action--info", text: /did not confirm eligibility/
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb -n /show/`
Expected: Fail — show action doesn't exist yet.

- [ ] **Step 3: Add show action to controller**

Add to `app/controllers/admin/entries_controller.rb`, inside the class after the `index` method:

```ruby
def show
  @entrant = Entrant.find(params[:id])
end
```

- [ ] **Step 4: Create the show view**

Create `app/views/admin/entries/show.html.erb`:

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
  <% when "eligible", "reinstated_admin" %>
    <div class="admin-action admin-action--exclude">
      <span class="admin-action__title">Exclude This Entry</span>
      <%= form_with url: exclude_admin_entry_path(@entrant), method: :patch, class: "admin-action__form" do |f| %>
        <div class="admin-action__field">
          <%= f.label :exclusion_reason, "Reason", class: "admin-action__label" %>
          <%= f.text_field :exclusion_reason, placeholder: "e.g. CypherCon sponsor employee", class: "admin-action__input" %>
        </div>
        <%= f.submit "Exclude", class: "admin-btn admin-btn--danger" %>
      <% end %>
    </div>

  <% when "duplicate_review" %>
    <div class="admin-action admin-action--exclude">
      <span class="admin-action__title">Exclude This Entry</span>
      <%= form_with url: exclude_admin_entry_path(@entrant), method: :patch, class: "admin-action__form" do |f| %>
        <div class="admin-action__field">
          <%= f.label :exclusion_reason, "Reason", class: "admin-action__label" %>
          <%= f.text_field :exclusion_reason, placeholder: "e.g. Confirmed duplicate", class: "admin-action__input" %>
        </div>
        <%= f.submit "Exclude", class: "admin-btn admin-btn--danger" %>
      <% end %>
    </div>

    <div class="admin-action admin-action--reinstate">
      <div class="admin-action__info">
        <span class="admin-action__title">Reinstate This Entry</span>
        <span class="admin-action__description">Clears the duplicate flag and restores to eligible</span>
      </div>
      <%= button_to "Reinstate", reinstate_admin_entry_path(@entrant), method: :patch, class: "admin-btn admin-btn--success" %>
    </div>

  <% when "excluded_admin" %>
    <div class="admin-action admin-action--reinstate">
      <div class="admin-action__info">
        <span class="admin-action__title">Reinstate This Entry</span>
        <span class="admin-action__description">Returns status to eligible and clears exclusion reason</span>
      </div>
      <%= button_to "Reinstate", reinstate_admin_entry_path(@entrant), method: :patch, class: "admin-btn admin-btn--success" %>
    </div>

  <% when "self_attested_ineligible" %>
    <div class="admin-action admin-action--info">
      <p>This person did not confirm eligibility.</p>
    </div>

  <%# winner, alternate_winner — no actions %>
  <% end %>
</div>
```

- [ ] **Step 5: Run show tests**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb -n /show/`
Expected: All show tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/admin/entries_controller.rb app/views/admin/entries/show.html.erb test/controllers/admin/entries_controller_test.rb
git commit -m "feat: implement admin entry show page with contextual actions"
```

### Task 6: Write exclude/reinstate tests and implement actions

**Files:**
- Modify: `test/controllers/admin/entries_controller_test.rb`
- Modify: `app/controllers/admin/entries_controller.rb`

- [ ] **Step 1: Write exclude and reinstate tests**

Add to `test/controllers/admin/entries_controller_test.rb`:

```ruby
test "PATCH exclude updates status and saves reason" do
  login_as_admin
  entrant = entrants(:ada)
  patch exclude_admin_entry_path(entrant), params: { exclusion_reason: "Sponsor employee" }
  assert_redirected_to admin_entry_path(entrant)
  entrant.reload
  assert_equal "excluded_admin", entrant.eligibility_status
  assert_equal "Sponsor employee", entrant.exclusion_reason
end

test "PATCH exclude works without a reason" do
  login_as_admin
  entrant = entrants(:grace)
  patch exclude_admin_entry_path(entrant)
  assert_redirected_to admin_entry_path(entrant)
  entrant.reload
  assert_equal "excluded_admin", entrant.eligibility_status
  assert_nil entrant.exclusion_reason
end

test "PATCH reinstate updates status and clears reason" do
  login_as_admin
  entrant = entrants(:excluded_eve)
  patch reinstate_admin_entry_path(entrant)
  assert_redirected_to admin_entry_path(entrant)
  entrant.reload
  assert_equal "reinstated_admin", entrant.eligibility_status
  assert_nil entrant.exclusion_reason
end

test "PATCH reinstate works on duplicate_review entry" do
  login_as_admin
  entrant = entrants(:duplicate_alan)
  patch reinstate_admin_entry_path(entrant)
  assert_redirected_to admin_entry_path(entrant)
  entrant.reload
  assert_equal "reinstated_admin", entrant.eligibility_status
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb -n /exclude\|reinstate/`
Expected: Fail — actions don't exist yet.

- [ ] **Step 3: Add exclude and reinstate actions**

Add to `app/controllers/admin/entries_controller.rb`, after the `show` method:

```ruby
def exclude
  @entrant = Entrant.find(params[:id])
  @entrant.update(eligibility_status: "excluded_admin", exclusion_reason: params[:exclusion_reason])
  redirect_to admin_entry_path(@entrant), notice: "Entry excluded."
end

def reinstate
  @entrant = Entrant.find(params[:id])
  @entrant.update(eligibility_status: "reinstated_admin", exclusion_reason: nil)
  redirect_to admin_entry_path(@entrant), notice: "Entry reinstated."
end
```

- [ ] **Step 4: Run all tests**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb`
Expected: All tests pass — auth gates, index, show, exclude, reinstate.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/entries_controller.rb test/controllers/admin/entries_controller_test.rb
git commit -m "feat: implement admin exclude and reinstate actions with tests"
```

---

## Chunk 3: Stimulus Controller, Layout, and Styling

### Task 7: Search form Stimulus controller

**Files:**
- Create: `app/javascript/controllers/search_form_controller.js`

- [ ] **Step 1: Create the search form controller**

Create `app/javascript/controllers/search_form_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, 300)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
```

- [ ] **Step 2: Verify it loads**

Run: `bin/rails runner "puts 'ok'"`
Expected: No errors. The controller will be picked up by the eager loader in `controllers/index.js` automatically — no registration changes needed.

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/search_form_controller.js
git commit -m "feat: add search form Stimulus controller with 300ms debounce"
```

### Task 8: Admin layout

**Files:**
- Create: `app/views/layouts/admin.html.erb`
- Modify: `app/controllers/admin/base_controller.rb` (add layout declaration)

- [ ] **Step 1: Create the admin layout**

Create `app/views/layouts/admin.html.erb`:

```erb
<!DOCTYPE html>
<html>
  <head>
    <title><%= content_for(:title) || "Admin — Raffle Entry Collector" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag :app, "admin" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="admin-body">
    <header class="admin-header">
      <div class="admin-header__left">
        <span class="admin-header__logo">&#9670; ADMIN CONSOLE</span>
        <%= link_to "Entries", admin_entries_path, class: "admin-header__link #{'admin-header__link--active' if controller_name == 'entries'}" %>
        <%# Export and Raffle links will be wired up in Issues #10 and #11 %>
        <span class="admin-header__link" style="opacity: 0.4; cursor: default;">Export</span>
        <span class="admin-header__link" style="opacity: 0.4; cursor: default;">Raffle</span>
      </div>
      <div class="admin-header__right">
        <%= button_to "Logout", admin_logout_path, method: :delete, class: "admin-header__link" %>
      </div>
    </header>

    <% if flash[:notice] %>
      <div class="admin-flash admin-flash--notice"><%= flash[:notice] %></div>
    <% end %>
    <% if flash[:alert] %>
      <div class="admin-flash admin-flash--alert"><%= flash[:alert] %></div>
    <% end %>

    <main class="admin-main">
      <%= yield %>
    </main>
  </body>
</html>
```

- [ ] **Step 2: Set the layout on the base controller**

Add to `app/controllers/admin/base_controller.rb`, inside the class (first line after the class declaration):

```ruby
layout "admin"
```

- [ ] **Step 3: Run all tests to make sure nothing is broken**

Run: `bin/rails test`
Expected: All tests pass. The admin layout applies to all admin controllers.

- [ ] **Step 4: Commit**

```bash
git add app/views/layouts/admin.html.erb app/controllers/admin/base_controller.rb
git commit -m "feat: add admin layout with gradient header bar and nav"
```

### Task 9: Admin CSS

**Files:**
- Create: `app/assets/stylesheets/admin.css`

- [ ] **Step 1: Create the admin stylesheet**

Create `app/assets/stylesheets/admin.css`:

```css
/* ==========================================================================
   Admin UI — Raffle Entry Collector
   Uses same brand palette as kiosk.css via CSS variables
   ========================================================================== */

:root {
  --white: #ffffff;
  --ice: #e6fafe;
  --sky: #aeeafd;
  --accent: #a6da74;
  --accent-hover: #bce598;
  --blue: #5b8bcd;
  --brand: #3b386f;
  --brand-deep: #26235a;
  --black: #000000;

  --bg: #1a1835;
  --surface: rgba(59, 56, 111, 0.45);
  --surface-solid: #2e2b5e;
  --border: rgba(91, 139, 205, 0.3);
  --text: var(--ice);
  --text-muted: rgba(174, 234, 253, 0.6);
  --error: #ff6b6b;
  --warning: #ffb74d;
  --success: #a6da74;

  --radius: 6px;
  --radius-lg: 8px;
  --transition: 150ms ease;
}

/* --- Reset & Base --- */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

html { height: 100%; }

.admin-body {
  min-height: 100%;
  font-family: -apple-system, "Segoe UI", "Liberation Sans", Helvetica, Arial, sans-serif;
  font-size: 14px;
  line-height: 1.5;
  color: var(--text);
  background: var(--bg);
  -webkit-font-smoothing: antialiased;
}

/* --- Header --- */
.admin-header {
  background: linear-gradient(90deg, var(--accent), var(--blue));
  padding: 0 24px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.admin-header__left {
  display: flex;
  align-items: center;
  gap: 20px;
}

.admin-header__right {
  display: flex;
  align-items: center;
}

.admin-header__logo {
  color: var(--bg);
  font-weight: 700;
  font-size: 15px;
  letter-spacing: 0.5px;
}

.admin-header__link {
  color: var(--bg);
  text-decoration: none;
  font-size: 13px;
  opacity: 0.7;
  transition: opacity var(--transition);
  background: none;
  border: none;
  cursor: pointer;
  font-family: inherit;
}

.admin-header__link:hover,
.admin-header__link--active {
  opacity: 1;
}

.admin-header__link--active {
  font-weight: 600;
  text-decoration: underline;
  text-underline-offset: 3px;
}

/* --- Flash --- */
.admin-flash {
  padding: 10px 24px;
  font-size: 13px;
}

.admin-flash--notice {
  background: rgba(166, 218, 116, 0.15);
  color: var(--accent);
}

.admin-flash--alert {
  background: rgba(255, 107, 107, 0.15);
  color: var(--error);
}

/* --- Main Content --- */
.admin-main {
  padding: 24px;
  max-width: 1200px;
}

/* --- Stats Bar --- */
.admin-stats {
  display: flex;
  gap: 12px;
  margin-bottom: 20px;
}

.admin-stat {
  background: var(--brand-deep);
  padding: 12px 20px;
  border-radius: var(--radius);
  flex: 1;
  text-align: center;
}

.admin-stat__label {
  display: block;
  color: rgba(174, 234, 253, 0.5);
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 1px;
  margin-bottom: 2px;
}

.admin-stat__count {
  display: block;
  color: var(--white);
  font-size: 24px;
  font-weight: 700;
}

.admin-stat__count--eligible { color: var(--accent); }
.admin-stat__count--excluded { color: var(--error); }
.admin-stat__count--duplicate { color: var(--warning); }

/* --- Search --- */
.admin-search__input {
  width: 100%;
  background: var(--brand-deep);
  border: 1px solid var(--brand);
  color: var(--white);
  padding: 10px 14px;
  border-radius: var(--radius);
  font-size: 13px;
  font-family: inherit;
  outline: none;
  margin-bottom: 16px;
  transition: border-color var(--transition);
}

.admin-search__input:focus {
  border-color: var(--sky);
}

.admin-search__input::placeholder {
  color: var(--text-muted);
}

/* --- Table --- */
.admin-table {
  width: 100%;
  border-collapse: collapse;
}

.admin-table__th {
  text-align: left;
  padding: 8px 12px;
  color: rgba(174, 234, 253, 0.5);
  font-weight: 600;
  font-size: 12px;
  border-bottom: 1px solid var(--brand);
  white-space: nowrap;
}

.admin-table__th--view {
  width: 70px;
  padding-right: 24px;
}

.admin-table__th--active .admin-table__sort {
  color: var(--accent);
}

.admin-table__sort {
  color: rgba(174, 234, 253, 0.5);
  text-decoration: none;
  transition: color var(--transition);
}

.admin-table__sort:hover {
  color: var(--white);
}

.admin-table__sort.admin-table__th--active {
  color: var(--accent);
}

.admin-table__row {
  border-bottom: 1px solid rgba(38, 35, 90, 0.8);
  transition: background var(--transition);
}

.admin-table__row:hover {
  background: rgba(59, 56, 111, 0.3);
}

.admin-table__td {
  padding: 8px 12px;
  font-size: 13px;
}

.admin-table__td--view {
  padding-right: 24px;
}

.admin-table__td--email {
  color: var(--sky);
}

.admin-table__td--date {
  color: var(--text-muted);
}

.admin-table__view-btn {
  color: var(--blue);
  text-decoration: none;
  font-size: 12px;
  border: 1px solid rgba(91, 139, 205, 0.3);
  padding: 3px 10px;
  border-radius: 3px;
  transition: border-color var(--transition), color var(--transition);
}

.admin-table__view-btn:hover {
  border-color: var(--blue);
  color: var(--white);
}

/* --- Status Pills --- */
.admin-status-pill {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 10px;
  font-size: 11px;
  font-weight: 500;
  white-space: nowrap;
}

.admin-status-pill--eligible,
.admin-status-pill--reinstated_admin {
  background: rgba(166, 218, 116, 0.2);
  color: var(--accent);
}

.admin-status-pill--excluded_admin {
  background: rgba(255, 107, 107, 0.2);
  color: var(--error);
}

.admin-status-pill--duplicate_review {
  background: rgba(255, 183, 77, 0.2);
  color: var(--warning);
}

.admin-status-pill--self_attested_ineligible {
  background: rgba(174, 234, 253, 0.1);
  color: var(--text-muted);
}

.admin-status-pill--winner,
.admin-status-pill--alternate_winner {
  background: rgba(91, 139, 205, 0.2);
  color: var(--blue);
}

/* --- Show Page --- */
.admin-show {
  max-width: 800px;
}

.admin-back-link {
  display: inline-block;
  color: var(--blue);
  text-decoration: none;
  font-size: 13px;
  margin-bottom: 16px;
  transition: color var(--transition);
}

.admin-back-link:hover {
  color: var(--sky);
}

.admin-show__header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 20px;
}

.admin-show__header h2 {
  font-size: 22px;
  font-weight: 700;
  color: var(--white);
  margin: 0;
}

/* --- Detail Card --- */
.admin-detail-card {
  background: var(--brand-deep);
  border-radius: var(--radius-lg);
  padding: 20px;
  margin-bottom: 16px;
}

.admin-detail-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 14px 24px;
}

.admin-detail__label {
  display: block;
  color: rgba(174, 234, 253, 0.5);
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 1px;
  margin-bottom: 2px;
}

.admin-detail__value {
  color: var(--white);
  font-size: 14px;
}

.admin-detail__value--excluded {
  color: var(--error);
}

.admin-detail__section {
  margin-top: 14px;
  padding-top: 14px;
  border-top: 1px solid var(--brand);
}

.admin-interest-tags {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
  margin-top: 4px;
}

.admin-interest-tag {
  background: var(--brand);
  color: var(--sky);
  padding: 3px 10px;
  border-radius: 4px;
  font-size: 12px;
}

/* --- Action Areas --- */
.admin-action {
  border-radius: var(--radius-lg);
  padding: 16px 20px;
  margin-bottom: 12px;
}

.admin-action--exclude {
  background: rgba(255, 107, 107, 0.08);
  border: 1px solid rgba(255, 107, 107, 0.25);
}

.admin-action--reinstate {
  background: rgba(166, 218, 116, 0.08);
  border: 1px solid rgba(166, 218, 116, 0.25);
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.admin-action--info {
  background: rgba(174, 234, 253, 0.06);
  border: 1px solid rgba(174, 234, 253, 0.15);
  color: var(--text-muted);
}

.admin-action__title {
  display: block;
  font-weight: 600;
  font-size: 13px;
  margin-bottom: 8px;
}

.admin-action--exclude .admin-action__title { color: var(--error); }
.admin-action--reinstate .admin-action__title { color: var(--accent); }

.admin-action__description {
  display: block;
  color: var(--text-muted);
  font-size: 12px;
  margin-top: 2px;
}

.admin-action__form {
  display: flex;
  gap: 8px;
  align-items: flex-end;
}

.admin-action__field {
  flex: 1;
}

.admin-action__label {
  display: block;
  color: var(--text-muted);
  font-size: 11px;
  margin-bottom: 4px;
}

.admin-action__input {
  width: 100%;
  background: var(--brand-deep);
  border: 1px solid var(--brand);
  color: var(--white);
  padding: 8px 12px;
  border-radius: var(--radius);
  font-size: 13px;
  font-family: inherit;
  outline: none;
}

.admin-action__input:focus {
  border-color: var(--sky);
}

/* --- Buttons --- */
.admin-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 8px 16px;
  font-size: 13px;
  font-weight: 600;
  font-family: inherit;
  border: none;
  border-radius: var(--radius);
  cursor: pointer;
  transition: background var(--transition);
  white-space: nowrap;
}

.admin-btn--danger {
  background: var(--error);
  color: var(--bg);
}

.admin-btn--danger:hover {
  background: #ff8a8a;
}

.admin-btn--success {
  background: var(--accent);
  color: var(--bg);
}

.admin-btn--success:hover {
  background: var(--accent-hover);
}
```

- [ ] **Step 2: Verify the app loads without CSS errors**

Run: `bin/rails runner "puts 'ok'"`
Expected: No errors. Propshaft will pick up the new stylesheet automatically.

- [ ] **Step 3: Run all tests**

Run: `bin/rails test`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add app/assets/stylesheets/admin.css
git commit -m "feat: add admin stylesheet with dark theme and gradient header"
```

### Task 10: Run full test suite and verify

**Files:** None (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `bin/rails test`
Expected: All tests pass with zero failures, zero errors.

- [ ] **Step 2: Start the server and manually verify**

Run: `bin/rails server -b 127.0.0.1`
Note: The user SSHs in from another machine, so for manual testing they may choose to bind to `0.0.0.0` temporarily. But the default and production binding must always be `127.0.0.1` per CLAUDE.md.

Verify in browser:
1. Navigate to `/admin` — should redirect to login
2. Log in with the admin password
3. See the entries index with stats bar, search, and table
4. Search filters entries as you type (with debounce)
5. Click column headers to sort
6. Click View to see entry detail
7. Exclude an entry (with reason)
8. Reinstate an excluded entry

- [ ] **Step 3: Final commit if any cleanup was needed**

If everything works, no additional commit needed. If fixes were required, commit them with a descriptive message.

- [ ] **Step 4: Close the GitHub issue**

```bash
gh issue close 9 --comment "Admin entries management implemented: index with search + sortable columns, show with contextual exclude/reinstate actions, admin layout with gradient header bar."
```
