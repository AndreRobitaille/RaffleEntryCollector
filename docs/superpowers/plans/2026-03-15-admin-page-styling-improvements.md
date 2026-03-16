# Admin Page Styling Improvements Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve three admin pages — raffle (draw all 3 at once with celebration overlay), export (contextual stats, 3-column layout), and entry detail (preset exclusion reason buttons).

**Architecture:** Backend changes add `perform_full_draw!` to RaffleDraw model and a winners CSV export type. Frontend changes are view templates, CSS, and a small JS snippet for the celebration overlay. No new routes needed.

**Tech Stack:** Ruby on Rails, ERB templates, vanilla CSS, vanilla JavaScript (no Stimulus/Turbo for overlay)

**Spec:** `docs/superpowers/specs/2026-03-15-admin-page-styling-improvements-design.md`

---

## File Structure

| File | Responsibility |
|------|---------------|
| `app/models/raffle_draw.rb` | Add `InsufficientEntrants` exception, `MINIMUM_ELIGIBLE` constant, `perform_full_draw!` method |
| `app/controllers/admin/raffle_controller.rb` | Update `draw` to call `perform_full_draw!`, rescue new exception |
| `app/controllers/admin/exports_controller.rb` | Add `@excluded_count`/`@winners_count` to `index`, add `"winners"` export type with `generate_winners_csv` |
| `app/views/admin/raffle/show.html.erb` | Full rewrite: pre-draw (instructions + draw button) / post-draw (winner cards + announce) states |
| `app/views/admin/exports/index.html.erb` | 4 contextual stats, 3-column export card grid |
| `app/views/admin/entries/show.html.erb` | Replace exclusion text field with 5 reason buttons |
| `app/assets/stylesheets/admin.css` | New classes for winner cards, celebration overlay, stat hints, reason button grid |
| `test/models/raffle_draw_test.rb` | Tests for `perform_full_draw!`, `InsufficientEntrants` |
| `test/controllers/admin/raffle_controller_test.rb` | Integration tests for full draw, winner cards, announce overlay |
| `test/controllers/admin/exports_controller_test.rb` | Tests for winners CSV export, updated stats |
| `test/controllers/admin/entries_controller_test.rb` | Tests for exclusion reason buttons |

---

## Chunk 1: Backend — Model and Controller Changes

### Task 1: Add `InsufficientEntrants` exception and `MINIMUM_ELIGIBLE` constant

**Files:**
- Modify: `app/models/raffle_draw.rb:1-2`
- Test: `test/models/raffle_draw_test.rb`

- [ ] **Step 1: Write the failing test for InsufficientEntrants**

**Important:** The existing `RaffleDrawTest` class has a `setup` block that deletes all fixtures and creates its own 3 eligible entrants (User0, User1, User2) plus 1 excluded. New tests in this class must use those local entrants, NOT fixture references like `entrants(:ada)`.

Add to `test/models/raffle_draw_test.rb`:

```ruby
test "perform_full_draw! raises InsufficientEntrants with fewer than 3 eligible" do
  # Setup creates 3 eligible (User0, User1, User2). Exclude one to leave only 2.
  Entrant.eligible.first.update!(eligibility_status: "excluded_admin")

  assert_raises(RaffleDraw::InsufficientEntrants) do
    RaffleDraw.perform_full_draw!
  end
end

test "MINIMUM_ELIGIBLE is 3" do
  assert_equal 3, RaffleDraw::MINIMUM_ELIGIBLE
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/raffle_draw_test.rb -v`
Expected: FAIL — `NameError: uninitialized constant RaffleDraw::InsufficientEntrants`

- [ ] **Step 3: Add exception class and constant to RaffleDraw**

In `app/models/raffle_draw.rb`, after line 2 (`class NoEligibleEntrants < StandardError; end`), add:

```ruby
class InsufficientEntrants < StandardError; end

MINIMUM_ELIGIBLE = 3
```

- [ ] **Step 4: Run test to verify constant test passes, draw test still fails**

Run: `bin/rails test test/models/raffle_draw_test.rb -v`
Expected: `MINIMUM_ELIGIBLE is 3` passes, `perform_full_draw!` still fails (method not defined)

- [ ] **Step 5: Commit**

```bash
git add app/models/raffle_draw.rb test/models/raffle_draw_test.rb
git commit -m "feat: add InsufficientEntrants exception and MINIMUM_ELIGIBLE constant to RaffleDraw"
```

---

### Task 2: Implement `perform_full_draw!`

**Files:**
- Modify: `app/models/raffle_draw.rb`
- Test: `test/models/raffle_draw_test.rb`

- [ ] **Step 1: Write failing tests for perform_full_draw! happy path**

**Reminder:** The existing `setup` creates 3 eligible entrants (User0, User1, User2) + 1 excluded. Use those — not fixtures.

Add to `test/models/raffle_draw_test.rb`:

```ruby
test "perform_full_draw! creates winner and two alternates" do
  # Setup creates exactly 3 eligible entrants
  draws = RaffleDraw.perform_full_draw!

  assert_equal 3, draws.length
  assert_equal "winner", draws[0].draw_type
  assert_equal "alternate_winner", draws[1].draw_type
  assert_equal "alternate_winner", draws[2].draw_type

  # All three are distinct entrants
  winner_ids = draws.map(&:winner_id)
  assert_equal winner_ids.uniq.length, 3

  # Entrant statuses updated
  assert_equal "winner", draws[0].winner.reload.eligibility_status
  assert_equal "alternate_winner", draws[1].winner.reload.eligibility_status
  assert_equal "alternate_winner", draws[2].winner.reload.eligibility_status
end

test "perform_full_draw! records eligible_count correctly for each draw" do
  draws = RaffleDraw.perform_full_draw!

  # Pool shrinks by 1 each time: 3, 2, 1
  assert_equal draws[0].eligible_count, draws[1].eligible_count + 1
  assert_equal draws[1].eligible_count, draws[2].eligible_count + 1
end

test "perform_full_draw! raises InsufficientEntrants with exactly 2 eligible" do
  # Exclude one of the 3 eligible entrants from setup
  Entrant.eligible.first.update!(eligibility_status: "excluded_admin")

  assert_raises(RaffleDraw::InsufficientEntrants) do
    RaffleDraw.perform_full_draw!
  end

  # No draws created
  assert_equal 0, RaffleDraw.count
end

test "perform_full_draw! rolls back all changes on failure" do
  # Exclude one so only 2 eligible remain
  Entrant.eligible.first.update!(eligibility_status: "excluded_admin")
  eligible_before = Entrant.eligible.pluck(:eligibility_status)

  assert_raises(RaffleDraw::InsufficientEntrants) do
    RaffleDraw.perform_full_draw!
  end

  # Statuses unchanged
  assert_equal eligible_before, Entrant.eligible.pluck(:eligibility_status)
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/raffle_draw_test.rb -v`
Expected: FAIL — `NoMethodError: undefined method 'perform_full_draw!'`

- [ ] **Step 3: Implement perform_full_draw!**

Add to `app/models/raffle_draw.rb`, after the existing `perform_draw!` method:

```ruby
# Draws winner + 2 alternates in a single transaction.
# Alternates are ordered by record id (first created = Alternate #1).
def self.perform_full_draw!
  transaction do
    eligible = Entrant.eligible.where.not(eligibility_status: %w[winner alternate_winner])
    raise InsufficientEntrants, "Need at least #{MINIMUM_ELIGIBLE} eligible entrants" if eligible.count < MINIMUM_ELIGIBLE

    draws = []

    # Draw winner
    draws << draw_one!(status: "winner")

    # Draw alternates — re-query each time since previous winner is now excluded
    2.times { draws << draw_one!(status: "alternate_winner") }

    draws
  end
end

private_class_method def self.draw_one!(status:)
  eligible = Entrant.eligible.where.not(eligibility_status: %w[winner alternate_winner])
  pool_size = eligible.count
  selected = eligible.offset(SecureRandom.random_number(pool_size)).first

  selected.update!(eligibility_status: status)
  create!(
    winner: selected,
    eligible_count: pool_size,
    draw_type: status
  )
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/models/raffle_draw_test.rb -v`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add app/models/raffle_draw.rb test/models/raffle_draw_test.rb
git commit -m "feat: implement perform_full_draw! for winner + 2 alternates"
```

---

### Task 3: Update raffle controller to use `perform_full_draw!`

**Files:**
- Modify: `app/controllers/admin/raffle_controller.rb`
- Test: `test/controllers/admin/raffle_controller_test.rb`

- [ ] **Step 1: Rewrite raffle controller tests**

The existing tests assume single-draw behavior (`assert_equal 1, RaffleDraw.count`, `perform_draw!`, etc.). These must be rewritten for the new `perform_full_draw!` behavior (3 draws at once, different flash message, minimum 3 eligible requirement).

Replace the **entire contents** of `test/controllers/admin/raffle_controller_test.rb`:

```ruby
require "test_helper"

class Admin::RaffleControllerTest < ActionDispatch::IntegrationTest
  setup do
    login_as_admin
    RaffleDraw.delete_all
  end

  test "GET /admin/raffle without auth redirects to login" do
    reset!
    get admin_raffle_path
    assert_redirected_to admin_login_path
  end

  test "POST /admin/raffle/draw without auth redirects to login" do
    reset!
    post draw_admin_raffle_path
    assert_redirected_to admin_login_path
  end

  test "show displays draw dashboard with stats" do
    get admin_raffle_path
    assert_response :success
    assert_select ".admin-stat__count", minimum: 3
  end

  test "show displays draw button when no draw has occurred" do
    get admin_raffle_path
    assert_select "button", text: /Draw Winner/i
  end

  test "draw creates winner and two alternates" do
    assert_difference "RaffleDraw.count", 3 do
      post draw_admin_raffle_path
    end
    assert_redirected_to admin_raffle_path
    follow_redirect!
    assert_select ".admin-flash--notice"
  end

  test "draw shows error when fewer than 3 eligible" do
    # Leave only 2 eligible
    Entrant.eligible.where.not(id: Entrant.eligible.limit(2).pluck(:id)).update_all(eligibility_status: "excluded_admin")

    assert_no_difference "RaffleDraw.count" do
      post draw_admin_raffle_path
    end
    assert_redirected_to admin_raffle_path
    follow_redirect!
    assert_select ".admin-flash--alert"
  end

  test "draw with no eligible entries shows error" do
    Entrant.update_all(eligibility_status: "excluded_admin")
    post draw_admin_raffle_path
    assert_redirected_to admin_raffle_path
    follow_redirect!
    assert_select ".admin-flash--alert"
  end

  test "show displays winner cards after draw" do
    post draw_admin_raffle_path
    get admin_raffle_path

    assert_select ".admin-winner-card", 3
    assert_select ".admin-winner-card--winner", 1
    assert_select ".admin-winner-card--alternate", 2
  end

  test "show hides draw button after draw is complete" do
    post draw_admin_raffle_path
    get admin_raffle_path

    assert_select ".admin-draw-action", 0
  end

  test "show displays draw history after a draw" do
    post draw_admin_raffle_path
    get admin_raffle_path
    assert_select "table tbody tr", count: 3
  end

  test "show displays instructions before draw" do
    get admin_raffle_path
    assert_select ".admin-info-panel"
  end
end
```

- [ ] **Step 2: Run tests to verify some fail (controller not yet updated)**

Run: `bin/rails test test/controllers/admin/raffle_controller_test.rb -v`
Expected: Tests that check for `perform_full_draw!` behavior and new CSS selectors will fail

- [ ] **Step 3: Update the raffle controller**

Replace `app/controllers/admin/raffle_controller.rb` with:

```ruby
class Admin::RaffleController < Admin::BaseController
  def show
    @total_count = Entrant.count
    @eligible_count = Entrant.eligible.where.not(eligibility_status: %w[winner alternate_winner]).count
    @excluded_count = Entrant.where(eligibility_status: %w[excluded_admin duplicate_review]).count
    @draws = RaffleDraw.includes(:winner).order(id: :asc)
    @draw_complete = @draws.exists?(draw_type: "winner")
  end

  def draw
    RaffleDraw.perform_full_draw!
    redirect_to admin_raffle_path, notice: "Winner and 2 alternates drawn!"
  rescue RaffleDraw::InsufficientEntrants
    redirect_to admin_raffle_path, alert: "Need at least #{RaffleDraw::MINIMUM_ELIGIBLE} eligible entrants to draw."
  rescue RaffleDraw::NoEligibleEntrants
    redirect_to admin_raffle_path, alert: "No eligible entrants for drawing."
  end
end
```

- [ ] **Step 4: Run tests to verify controller tests pass (view tests may still fail)**

Run: `bin/rails test test/controllers/admin/raffle_controller_test.rb -v`
Expected: Tests checking flash/redirect pass; tests checking CSS selectors for winner cards will fail until view is updated (that's fine — view comes in Chunk 2)

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/raffle_controller.rb test/controllers/admin/raffle_controller_test.rb
git commit -m "feat: update raffle controller to use perform_full_draw!"
```

---

### Task 4: Add winners CSV export to exports controller

**Files:**
- Modify: `app/controllers/admin/exports_controller.rb`
- Test: `test/controllers/admin/exports_controller_test.rb`

- [ ] **Step 1: Write failing tests for winners export and updated index stats**

Add to `test/controllers/admin/exports_controller_test.rb`:

```ruby
test "index shows excluded count and winners count" do
  login_as_admin
  get admin_export_path
  assert_response :success
  assert_select ".admin-stat", minimum: 4
end

test "download winners CSV with draws present" do
  login_as_admin
  # Perform a full draw first
  RaffleDraw.perform_full_draw!

  get admin_export_download_path(type: "winners")
  assert_response :success
  assert_equal "text/csv", response.media_type

  csv = CSV.parse(response.body, headers: true)
  assert_equal 3, csv.size

  # Check headers
  assert_includes csv.headers, "draw_type"
  assert_includes csv.headers, "first_name"
  assert_includes csv.headers, "email"
  assert_includes csv.headers, "company"
  assert_includes csv.headers, "drawn_at"

  # First row should be the winner
  assert_equal "Winner", csv[0]["draw_type"]
  # Second and third should be alternates
  assert_equal "Alternate #1", csv[1]["draw_type"]
  assert_equal "Alternate #2", csv[2]["draw_type"]
end

test "download winners CSV with no draws returns empty CSV with headers" do
  login_as_admin
  get admin_export_download_path(type: "winners")
  assert_response :success

  csv = CSV.parse(response.body, headers: true)
  assert_equal 0, csv.size
  assert_includes csv.headers, "draw_type"
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/exports_controller_test.rb -v`
Expected: FAIL — index doesn't have 4 stats, winners export not handled

- [ ] **Step 3: Update the exports controller**

In `app/controllers/admin/exports_controller.rb`:

Update the `index` action:

```ruby
def index
  @total_count = Entrant.count
  @eligible_count = Entrant.eligible.count
  @excluded_count = Entrant.where(eligibility_status: %w[excluded_admin duplicate_review]).count
  @winners_count = RaffleDraw.count
end
```

Update `export_type` to accept `"winners"`:

```ruby
def export_type
  %w[eligible all winners].include?(params[:type]) ? params[:type] : "eligible"
end
```

Update the `download` action to branch on winners:

```ruby
def download
  if export_type == "winners"
    csv_data = generate_winners_csv
    filename = "raffle-winners-#{Time.current.strftime('%Y%m%d-%H%M%S')}.csv"
  else
    entries = export_scope
    csv_data = generate_csv(entries)
    filename = "raffle-entries-#{export_type}-#{Time.current.strftime('%Y%m%d-%H%M%S')}.csv"
  end

  send_data csv_data, filename: filename, type: "text/csv", disposition: "attachment"
end
```

Add `generate_winners_csv` private method:

```ruby
WINNERS_CSV_HEADERS = %w[draw_type first_name last_name email company job_title drawn_at].freeze

def generate_winners_csv
  draws = RaffleDraw.includes(:winner).order(id: :asc)
  alternate_index = 0

  CSV.generate do |csv|
    csv << WINNERS_CSV_HEADERS
    draws.each do |draw|
      label = if draw.draw_type == "winner"
        "Winner"
      else
        alternate_index += 1
        "Alternate ##{alternate_index}"
      end

      entrant = draw.winner
      csv << [
        label,
        entrant.first_name,
        entrant.last_name,
        entrant.email,
        entrant.company,
        entrant.job_title,
        draw.created_at
      ]
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/admin/exports_controller_test.rb -v`
Expected: All tests pass

- [ ] **Step 5: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass (some raffle controller view-assertion tests may fail — those are fixed in Chunk 2)

- [ ] **Step 6: Commit**

```bash
git add app/controllers/admin/exports_controller.rb test/controllers/admin/exports_controller_test.rb
git commit -m "feat: add winners CSV export and contextual stats to exports controller"
```

---

## Chunk 2: Frontend — Views, CSS, and JavaScript

### Task 5: Add CSS classes for new components

**Files:**
- Modify: `app/assets/stylesheets/admin.css`

- [ ] **Step 1: Add winner card styles**

Append to `app/assets/stylesheets/admin.css`:

```css
/* Winner cards on raffle page */
.admin-winner-card {
  background: var(--brand-deep);
  border-radius: var(--radius-lg);
  padding: 16px 20px;
  border-left: 4px solid rgba(91, 139, 205, 0.4);
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}

.admin-winner-card--winner {
  border-left-color: var(--blue);
}

.admin-winner-card__label {
  display: block;
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 1px;
  margin-bottom: 4px;
  color: rgba(91, 139, 205, 0.7);
}

.admin-winner-card--winner .admin-winner-card__label {
  color: var(--blue);
}

.admin-winner-card__name {
  color: var(--white);
  font-size: 16px;
  font-weight: 700;
}

.admin-winner-card__detail {
  color: var(--text-muted);
  font-size: 13px;
}
```

- [ ] **Step 2: Add celebration overlay styles**

Append to `app/assets/stylesheets/admin.css`:

```css
/* Celebration overlay */
.admin-celebrate {
  display: none;
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 1000;
  background: linear-gradient(135deg, #1a1835 0%, #26235a 50%, #3b386f 100%);
  align-items: center;
  justify-content: center;
  flex-direction: column;
}

.admin-celebrate--visible {
  display: flex;
}

.admin-celebrate__accent {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 4px;
  background: linear-gradient(90deg, var(--blue), var(--accent), var(--blue));
}

.admin-celebrate__label {
  color: var(--accent);
  font-size: 18px;
  text-transform: uppercase;
  letter-spacing: 4px;
  margin-bottom: 20px;
}

.admin-celebrate__name {
  color: var(--white);
  font-size: 72px;
  font-weight: 800;
  line-height: 1.1;
  text-align: center;
  margin-bottom: 16px;
}

.admin-celebrate__company {
  color: var(--sky);
  font-size: 28px;
  text-align: center;
}

.admin-celebrate__close {
  position: absolute;
  bottom: 16px;
  right: 16px;
  background: rgba(255, 255, 255, 0.1);
  color: var(--text-muted);
  border: 1px solid rgba(174, 234, 253, 0.2);
  padding: 8px 16px;
  border-radius: var(--radius);
  font-size: 12px;
  cursor: pointer;
  font-family: inherit;
  transition: background var(--transition);
}

.admin-celebrate__close:hover {
  background: rgba(255, 255, 255, 0.2);
}
```

- [ ] **Step 3: Add contextual stat hint and info panel styles**

Append to `app/assets/stylesheets/admin.css`:

```css
/* Stat context hints */
.admin-stat__hint {
  display: block;
  font-size: 10px;
  margin-top: 2px;
}

.admin-stat__hint--ok {
  color: rgba(166, 218, 116, 0.6);
}

.admin-stat__hint--warn {
  color: rgba(255, 183, 77, 0.7);
}

.admin-stat__hint--info {
  color: rgba(91, 139, 205, 0.6);
}

.admin-stat--warn {
  border-top-color: var(--warning);
}

.admin-stat__count--warn {
  color: var(--warning);
}

/* Stats summary line */
.admin-stats-summary {
  font-size: 12px;
  text-align: center;
  padding: 4px 0;
  margin-bottom: 16px;
}

.admin-stats-summary--ok {
  color: var(--accent);
}

.admin-stats-summary--warn {
  color: var(--warning);
}

/* Info panel (raffle instructions) */
.admin-info-panel {
  background: rgba(91, 139, 205, 0.1);
  border: 1px solid rgba(91, 139, 205, 0.25);
  border-radius: var(--radius-lg);
  padding: 16px 20px;
  margin-bottom: 20px;
}

.admin-info-panel__title {
  color: var(--blue);
  font-weight: 600;
  font-size: 13px;
  margin-bottom: 6px;
}

.admin-info-panel__body {
  color: var(--text-muted);
  font-size: 13px;
  line-height: 1.6;
}

/* Exclusion reason button grid */
.admin-exclude-reasons {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.admin-exclude-reasons__hint {
  color: var(--text-muted);
  font-size: 11px;
  margin-top: 8px;
  width: 100%;
}

/* Export card alignment fix */
.admin-export__option {
  display: flex;
  flex-direction: column;
}

.admin-export__option-description {
  flex: 1;
}

.admin-export__options--three {
  grid-template-columns: 1fr 1fr 1fr;
  max-width: 1000px;
}

/* Disabled button */
.admin-btn--disabled {
  opacity: 0.4;
  cursor: not-allowed;
  pointer-events: none;
}
```

- [ ] **Step 4: Commit**

```bash
git add app/assets/stylesheets/admin.css
git commit -m "feat: add CSS for winner cards, celebration overlay, stat hints, exclusion buttons"
```

---

### Task 6: Rewrite raffle page view

**Files:**
- Modify: `app/views/admin/raffle/show.html.erb`

- [ ] **Step 1: Rewrite the raffle page template**

Replace the entire contents of `app/views/admin/raffle/show.html.erb`:

```erb
<h1>Raffle Drawing</h1>

<div class="admin-stats">
  <div class="admin-stat">
    <span class="admin-stat__label">Total Entries</span>
    <span class="admin-stat__count"><%= @total_count %></span>
  </div>
  <div class="admin-stat">
    <span class="admin-stat__label">Eligible for Draw</span>
    <span class="admin-stat__count admin-stat__count--eligible"><%= @eligible_count %></span>
  </div>
  <div class="admin-stat">
    <span class="admin-stat__label">Excluded</span>
    <span class="admin-stat__count admin-stat__count--excluded"><%= @excluded_count %></span>
  </div>
</div>

<% if @draw_complete %>
  <%# Post-draw state: winner cards + export %>
  <% winner_draw = @draws.find { |d| d.draw_type == "winner" } %>
  <% alternate_draws = @draws.select { |d| d.draw_type == "alternate_winner" }.sort_by(&:id) %>

  <div class="admin-winner-card admin-winner-card--winner">
    <div>
      <span class="admin-winner-card__label">Winner</span>
      <div class="admin-winner-card__name"><%= winner_draw.winner.first_name %> <%= winner_draw.winner.last_name %></div>
      <div class="admin-winner-card__detail"><%= winner_draw.winner.email %> · <%= winner_draw.winner.company %></div>
    </div>
    <button class="admin-btn admin-btn--primary" type="button"
            onclick="showCelebration('<%= j winner_draw.winner.first_name %> <%= j winner_draw.winner.last_name %>', '<%= j winner_draw.winner.company %>')">
      Announce
    </button>
  </div>

  <% alternate_draws.each_with_index do |draw, i| %>
    <div class="admin-winner-card admin-winner-card--alternate">
      <div>
        <span class="admin-winner-card__label">Alternate #<%= i + 1 %></span>
        <div class="admin-winner-card__name"><%= draw.winner.first_name %> <%= draw.winner.last_name %></div>
        <div class="admin-winner-card__detail"><%= draw.winner.email %> · <%= draw.winner.company %></div>
      </div>
      <button class="admin-btn admin-btn--primary" type="button"
              onclick="showCelebration('<%= j draw.winner.first_name %> <%= j draw.winner.last_name %>', '<%= j draw.winner.company %>')">
        Announce
      </button>
    </div>
  <% end %>

  <div style="margin: 20px 0;">
    <%= link_to "Export Winners CSV", admin_export_download_path(type: "winners"), class: "admin-btn admin-btn--success" %>
  </div>

<% else %>
  <%# Pre-draw state: instructions + draw button %>
  <div class="admin-info-panel">
    <div class="admin-info-panel__title">How the draw works</div>
    <div class="admin-info-panel__body">
      Clicking the button below selects one winner and two alternates at random from the eligible pool.
      You can then reveal each one to the crowd using the "Announce" button.
      If the winner doesn't claim the prize within two business days, contact alternates in order.
    </div>
  </div>

  <div class="admin-draw-action">
    <% if @eligible_count >= RaffleDraw::MINIMUM_ELIGIBLE %>
      <%= button_to "Draw Winner + 2 Alternates", draw_admin_raffle_path, method: :post,
          class: "admin-btn admin-btn--primary",
          data: { turbo_confirm: "Draw a winner and 2 alternates from #{@eligible_count} eligible entries?" } %>
    <% else %>
      <button class="admin-btn admin-btn--primary admin-btn--disabled" disabled>Draw Winner + 2 Alternates</button>
      <p class="admin-stats-summary admin-stats-summary--warn">
        Need at least <%= RaffleDraw::MINIMUM_ELIGIBLE %> eligible entries to draw (currently <%= @eligible_count %>)
      </p>
    <% end %>
  </div>
<% end %>

<% if @draws.any? %>
  <h2>Draw History</h2>
  <table class="admin-table">
    <thead>
      <tr>
        <th class="admin-table__th">Date</th>
        <th class="admin-table__th">Type</th>
        <th class="admin-table__th">Winner</th>
        <th class="admin-table__th">Eligible Pool</th>
        <th class="admin-table__th">Note</th>
      </tr>
    </thead>
    <tbody>
      <% @draws.each_with_index do |d, i| %>
        <tr class="admin-table__row">
          <td class="admin-table__td admin-table__td--date"><%= d.created_at.strftime("%b %d %H:%M") %></td>
          <td class="admin-table__td">
            <span class="admin-status-pill admin-status-pill--<%= d.draw_type %>"><%= d.draw_type.titleize %></span>
          </td>
          <td class="admin-table__td"><%= link_to "#{d.winner.first_name} #{d.winner.last_name}", admin_entry_path(d.winner) %></td>
          <td class="admin-table__td"><%= d.eligible_count %></td>
          <td class="admin-table__td"><%= d.admin_note %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
<% end %>

<%# Celebration overlay — hidden, shown by JS %>
<div class="admin-celebrate" id="celebration-overlay">
  <div class="admin-celebrate__accent"></div>
  <div class="admin-celebrate__label">Congratulations</div>
  <div class="admin-celebrate__name" id="celebration-name"></div>
  <div class="admin-celebrate__company" id="celebration-company"></div>
  <button class="admin-celebrate__close" type="button" onclick="hideCelebration()">Close</button>
</div>

<script>
  function showCelebration(name, company) {
    document.getElementById('celebration-name').textContent = name;
    document.getElementById('celebration-company').textContent = company;
    document.getElementById('celebration-overlay').classList.add('admin-celebrate--visible');
  }

  function hideCelebration() {
    document.getElementById('celebration-overlay').classList.remove('admin-celebrate--visible');
  }

  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') hideCelebration();
  });
</script>
```

- [ ] **Step 2: Run raffle controller tests**

Run: `bin/rails test test/controllers/admin/raffle_controller_test.rb -v`
Expected: All tests pass (including the CSS selector assertions from Task 3)

- [ ] **Step 3: Commit**

```bash
git add app/views/admin/raffle/show.html.erb
git commit -m "feat: rewrite raffle page with winner cards, instructions, and celebration overlay"
```

---

### Task 7: Update export page view

**Files:**
- Modify: `app/views/admin/exports/index.html.erb`

- [ ] **Step 1: Write test for updated export page**

Add to `test/controllers/admin/exports_controller_test.rb`:

```ruby
test "index shows contextual stat hints" do
  login_as_admin
  get admin_export_path
  assert_select ".admin-stat__hint"
end

test "index shows warning when fewer than 3 eligible" do
  login_as_admin
  # Exclude most entries to drop below 3
  Entrant.where(eligibility_status: "eligible").update_all(eligibility_status: "excluded_admin")
  get admin_export_path
  assert_select ".admin-stats-summary--warn"
end

test "index shows three export cards" do
  login_as_admin
  get admin_export_path
  assert_select ".admin-export__option", 3
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/exports_controller_test.rb -v`
Expected: FAIL — current view only has 2 stats and 2 export cards

- [ ] **Step 3: Rewrite the export page template**

Replace the entire contents of `app/views/admin/exports/index.html.erb`:

```erb
<h2 class="admin-export__title">Export Entries</h2>

<div class="admin-stats">
  <div class="admin-stat">
    <span class="admin-stat__label">Total</span>
    <span class="admin-stat__count"><%= @total_count %></span>
  </div>
  <div class="admin-stat <%= @eligible_count < RaffleDraw::MINIMUM_ELIGIBLE ? 'admin-stat--warn' : '' %>">
    <span class="admin-stat__label">Eligible</span>
    <span class="admin-stat__count <%= @eligible_count < RaffleDraw::MINIMUM_ELIGIBLE ? 'admin-stat__count--warn' : 'admin-stat__count--eligible' %>"><%= @eligible_count %></span>
    <% if @eligible_count < RaffleDraw::MINIMUM_ELIGIBLE %>
      <span class="admin-stat__hint admin-stat__hint--warn">need <%= RaffleDraw::MINIMUM_ELIGIBLE %>+ for raffle</span>
    <% else %>
      <span class="admin-stat__hint admin-stat__hint--ok">min <%= RaffleDraw::MINIMUM_ELIGIBLE %> for raffle</span>
    <% end %>
  </div>
  <div class="admin-stat">
    <span class="admin-stat__label">Excluded</span>
    <span class="admin-stat__count admin-stat__count--excluded"><%= @excluded_count %></span>
  </div>
  <div class="admin-stat">
    <span class="admin-stat__label">Winners</span>
    <span class="admin-stat__count" style="color: var(--blue);"><%= @winners_count %></span>
    <% if @winners_count == 0 %>
      <span class="admin-stat__hint admin-stat__hint--info">not yet drawn</span>
    <% end %>
  </div>
</div>

<% if @eligible_count >= RaffleDraw::MINIMUM_ELIGIBLE %>
  <p class="admin-stats-summary admin-stats-summary--ok"><%= @eligible_count %> eligible — ready for raffle</p>
<% else %>
  <p class="admin-stats-summary admin-stats-summary--warn">Only <%= @eligible_count %> eligible — need at least <%= RaffleDraw::MINIMUM_ELIGIBLE %> for raffle</p>
<% end %>

<div class="admin-export__options admin-export__options--three">
  <div class="admin-export__option">
    <h3 class="admin-export__option-title">Eligible Entries</h3>
    <p class="admin-export__option-description">
      Entries eligible for the raffle only. Excludes entries marked as
      ineligible, excluded, or flagged for duplicate review.
    </p>
    <p class="admin-export__option-count"><%= @eligible_count %> entries</p>
    <%= link_to "Download CSV", admin_export_download_path(type: "eligible"), class: "admin-btn admin-btn--success" %>
  </div>

  <div class="admin-export__option">
    <h3 class="admin-export__option-title">All Entries</h3>
    <p class="admin-export__option-description">
      Every entry including excluded, duplicates, and self-attested ineligible.
    </p>
    <p class="admin-export__option-count"><%= @total_count %> entries</p>
    <%= link_to "Download CSV", admin_export_download_path(type: "all"), class: "admin-btn admin-btn--primary" %>
  </div>

  <div class="admin-export__option">
    <h3 class="admin-export__option-title">Winners</h3>
    <p class="admin-export__option-description">
      Winner and alternate winners with contact info and draw order.
    </p>
    <% if @winners_count > 0 %>
      <p class="admin-export__option-count"><%= @winners_count %> winners</p>
      <%= link_to "Download CSV", admin_export_download_path(type: "winners"), class: "admin-btn admin-btn--primary" %>
    <% else %>
      <p class="admin-export__option-count">No winners drawn yet</p>
      <span class="admin-btn admin-btn--primary admin-btn--disabled">Download CSV</span>
    <% end %>
  </div>
</div>
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/admin/exports_controller_test.rb -v`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add app/views/admin/exports/index.html.erb test/controllers/admin/exports_controller_test.rb
git commit -m "feat: redesign export page with contextual stats and winners CSV option"
```

---

### Task 8: Replace exclusion text field with reason buttons

**Files:**
- Modify: `app/views/admin/entries/show.html.erb:59-82`
- Test: `test/controllers/admin/entries_controller_test.rb`

- [ ] **Step 1: Write tests for exclusion reason buttons**

Add to `test/controllers/admin/entries_controller_test.rb`:

```ruby
test "show displays exclusion reason buttons for eligible entry" do
  login_as_admin
  get admin_entry_path(entrants(:ada))
  assert_select ".admin-exclude-reasons"
  assert_select ".admin-exclude-reasons form", 5
end

test "show displays exclusion reason buttons for duplicate_review entry" do
  login_as_admin
  get admin_entry_path(entrants(:duplicate_alan))
  assert_select ".admin-exclude-reasons"
  assert_select ".admin-exclude-reasons form", 5
end

test "exclude with preset reason stores correct reason" do
  login_as_admin
  patch exclude_admin_entry_path(entrants(:ada)), params: { exclusion_reason: "FFS Employee" }
  assert_equal "FFS Employee", entrants(:ada).reload.exclusion_reason
end

test "show does not display text field for exclusion reason" do
  login_as_admin
  get admin_entry_path(entrants(:ada))
  assert_select "input[type=text][name*=exclusion_reason]", 0
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb -v`
Expected: FAIL — current view has text field, not buttons

- [ ] **Step 3: Replace the entire case block in the entry show template**

In `app/views/admin/entries/show.html.erb`, replace the entire case block (lines 58-107) with the following. This avoids stitching errors from partial replacements.

**Note:** The `%w[]` with escaped spaces (`Sponsor\ /\ Vendor`) produces the array `["Sponsor / Vendor", "Event Staff", "Duplicate", "FFS Employee", "Other"]`.

Replace from `<%# Action area` through the closing `<% end %>` of the case:

```erb
  <%# Action area — contextual based on eligibility status %>
  <% case @entrant.eligibility_status %>
  <% when "eligible", "reinstated_admin" %>
    <div class="admin-action admin-action--exclude">
      <span class="admin-action__title">Exclude This Entry</span>
      <div class="admin-exclude-reasons">
        <% %w[Sponsor\ /\ Vendor Event\ Staff Duplicate FFS\ Employee Other].each do |reason| %>
          <%= button_to reason, exclude_admin_entry_path(@entrant),
              method: :patch,
              params: { exclusion_reason: reason },
              class: "admin-btn admin-btn--danger" %>
        <% end %>
      </div>
    </div>

  <% when "duplicate_review" %>
    <div class="admin-action admin-action--exclude">
      <span class="admin-action__title">Exclude This Entry</span>
      <div class="admin-exclude-reasons">
        <% %w[Sponsor\ /\ Vendor Event\ Staff Duplicate FFS\ Employee Other].each do |reason| %>
          <%= button_to reason, exclude_admin_entry_path(@entrant),
              method: :patch,
              params: { exclusion_reason: reason },
              class: "admin-btn admin-btn--danger" %>
        <% end %>
      </div>
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/admin/entries_controller_test.rb -v`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add app/views/admin/entries/show.html.erb test/controllers/admin/entries_controller_test.rb
git commit -m "feat: replace exclusion text field with preset reason buttons"
```

---

### Task 9: Final quality checks

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass

- [ ] **Step 2: Run rubocop**

Run: `bundle exec rubocop`
Expected: No offenses (or only pre-existing ones in `.html.erb` files)

- [ ] **Step 3: Run brakeman**

Run: `bundle exec brakeman --no-pager -q`
Expected: No warnings

- [ ] **Step 4: Visual verification**

Start the dev server (`bin/rails server -b 0.0.0.0`) and manually check each page in the browser:
- Raffle page: pre-draw state (instructions, draw button), post-draw state (winner cards, announce, celebration overlay, close via button and Escape key)
- Export page: 4 stats with context hints, 3 export cards aligned, low-count warning state
- Entry detail: exclusion reason buttons for eligible and duplicate_review entries, reinstate flow

- [ ] **Step 5: Fix any issues found in steps 1-4**

Address any failures before final commit.

- [ ] **Step 6: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: address quality check issues"
```
