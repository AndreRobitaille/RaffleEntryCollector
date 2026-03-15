# Admin Entries Management — Design Spec

**GitHub Issue:** #9
**Date:** 2026-03-15
**Status:** Approved

## Summary

Build the admin entries list with search, sortable columns, detail view, and exclude/reinstate actions. Uses Turbo Frames for responsive partial-page updates and a debounced search input. Visual design follows the dark space theme with a green-to-blue gradient header bar to distinguish admin mode from the kiosk.

## Constraints

- Runs on Raspberry Pi 4 with 4GB RAM (shared with desktop + Chromium kiosk)
- Expected max ~150 entries — no pagination needed
- Admin accessed via wireless keyboard+trackpad, not touchscreen
- All server-rendered, no external dependencies

## Routes

Added inside the existing `namespace :admin` block in `config/routes.rb`:

```ruby
resources :entries, only: [:index, :show] do
  member do
    patch :exclude
    patch :reinstate
  end
end
```

This produces:
- `GET /admin/entries` — index (already wired as `admin_root`)
- `GET /admin/entries/:id` — show
- `PATCH /admin/entries/:id/exclude` — exclude
- `PATCH /admin/entries/:id/reinstate` — reinstate

**Note:** The existing `root "entries#index"` line in the admin namespace must remain — do not duplicate it. The `resources` block adds the named `admin_entries_path` helpers alongside the existing `admin_root_path`.

## Controller: Admin::EntriesController

Inherits from `Admin::BaseController` (auth handled by `before_action :require_admin`).

### Actions

**`index`**
- Loads all entrants, ordered by sort params (default: `company ASC`)
- If `params[:q]` present, filters with LIKE on `first_name`, `last_name`, `email`, `company` and changes default sort to `last_name ASC`
- Sort controlled by `params[:sort]` (column name) and `params[:dir]` (`asc` or `desc`)
- Allowed sort columns: `first_name`, `last_name`, `company`, `eligibility_status`, `email`, `created_at`
- Computes stats: total count, eligible count (scope `:eligible` — includes `reinstated_admin`, intentionally), excluded count (scope `:excluded`), duplicate count (scope `:duplicates`)
- Responds within Turbo Frame `entries_table` when requested via frame

**`show`**
- `Entrant.find(params[:id])`
- Renders full detail view with contextual action area (exclude form or reinstate button)

**`exclude`**
- Uses `entry.update(eligibility_status: "excluded_admin", exclusion_reason: params[:exclusion_reason])` — keep validations active so `eligibility_status` inclusion check remains enforced
- Redirects back to show page with flash notice

**`reinstate`**
- Uses `entry.update(eligibility_status: "reinstated_admin", exclusion_reason: nil)` — keep validations active
- Redirects back to show page with flash notice

## Views

### Admin Layout (`app/views/layouts/admin.html.erb`) — NEW FILE

Separate layout from the kiosk. Shares the dark space theme (`--bg: #1a1835`, `--brand: #3B386F`) but adds:
- **Green-to-blue gradient header bar** (`linear-gradient(90deg, #A6DA74, #5B8BCD)`) with nav links: Entries, Export, Raffle, Logout
- "ADMIN CONSOLE" label with diamond icon on the left
- No touch-friendly sizing — tighter spacing for keyboard/trackpad use

### Index View (`admin/entries/index.html.erb`)

**Stats bar** (outside Turbo Frame — always visible):
- Four cards: Total (white), Eligible (green), Excluded (red), Duplicates (amber)
- Background: `#26235A`, centered text with large count numbers

**Search form** (outside Turbo Frame):
- Single text input with placeholder "Search by name, email, or company..."
- Targets the `entries_table` Turbo Frame
- Auto-submits via `search-form` Stimulus controller with 300ms debounce

**Entries table** (inside `<turbo-frame id="entries_table">`):

Column order:
1. View button (far left, with generous right padding/margin before name columns)
2. First Name
3. Last Name
4. Company
5. Status (color-coded pills)
6. Email
7. Date

- Column headers are links with `?sort=column&dir=asc|desc` targeting the Turbo Frame
- Active sort column header highlighted in green with ▲/▼ indicator
- Inactive columns show dimmed ▲
- Status pills color-coded: green (`eligible`, `reinstated_admin`), red (`excluded_admin`), amber (`duplicate_review`), gray (`self_attested_ineligible`), default/gray for any other

**Sort behavior:**
- Default (no search): ascending by company
- When search query is present: resets to ascending by last name
- Click column header: ascending; click again: descending; alternates

### Show View (`admin/entries/show.html.erb`)

**Back link** — "← Back to Entries" linking to index

**Header** — entrant full name + status pill

**Detail card** (`#26235A` background, rounded):
- Two-column grid: First Name, Last Name, Email, Company, Job Title, Entered (formatted datetime)
- Interest areas section: horizontal tag chips (`#3B386F` background, `#AEEAFD` text)
- Exclusion reason (below interest areas, only shown when present, `#e57373` text)

**Action area** (contextual, below detail card):
- **If `eligible` or `reinstated_admin`**: red-tinted exclude form (reason text field + "Exclude" button). Form PATCHes to `exclude_admin_entry_path`.
- **If `duplicate_review`**: both actions shown — red-tinted exclude form (to confirm as real duplicate and exclude) AND green-tinted reinstate button (to clear the flag as a false positive and restore to eligible). Admin decides which action to take.
- **If `excluded_admin`**: green-tinted reinstate section with description text + "Reinstate" button. Form PATCHes to `reinstate_admin_entry_path`.
- **If `self_attested_ineligible`**: gray info box with text "This person did not confirm eligibility." No action buttons — their self-attestation is respected.
- **If `winner` or `alternate_winner`**: no action area shown (don't allow status changes on winners).

## Stimulus Controllers

### `search-form` controller

- Attaches to the search form
- On `input` event: debounces 300ms, then calls `form.requestSubmit()`
- Turbo handles the frame replacement automatically
- Minimal — ~15 lines of JS

### Sort (no controller needed)

Column header links are plain `<a>` tags inside the Turbo Frame. Turbo follows the link and replaces the frame content. No Stimulus needed.

## Styling

### New file: `app/assets/stylesheets/admin.css` — NEW FILE

Loaded only in the admin layout. Uses the same CSS custom properties as `kiosk.css` for brand consistency.

Key styles:
- Gradient header bar
- Stats bar cards
- Data table (with hover row highlight)
- Status pills (color variants)
- Detail card grid
- Exclude/reinstate action areas
- Search input

No touch-friendly overrides — admin uses standard web spacing.

## Model Changes

Add one scope to `Entrant` if not already present:

```ruby
scope :excluded, -> { where(eligibility_status: "excluded_admin") }
```

No other model changes needed — all fields and validations already exist.

## Testing

### Controller tests (`test/controllers/admin/entries_controller_test.rb`)

- **Auth gate:** unauthenticated requests to all four actions redirect to login
- **Index:** returns success, displays entries
- **Index with search:** filters results by query matching name/email/company
- **Index with sort:** respects sort column and direction params
- **Show:** returns success, displays entry details
- **Exclude:** updates status to `excluded_admin`, saves reason, redirects to show
- **Exclude without reason:** still works (reason is optional but encouraged)
- **Reinstate:** updates status to `reinstated_admin`, clears reason, redirects to show

### Fixtures

Use existing entrant fixtures or create test-specific entries inline with `Entrant.create!`.
