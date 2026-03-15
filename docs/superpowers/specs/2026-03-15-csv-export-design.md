# CSV Export Design

**Issue:** #10
**Date:** 2026-03-15

## Goal

Add CSV export functionality to the admin console with two export modes: eligible entries only (business use) and all entries (archival).

## Routing

Two new routes in the admin namespace:

```ruby
get "export", to: "exports#index", as: :export
get "export/download", to: "exports#download", as: :export_download
```

Route helpers: `admin_export_path` and `admin_export_download_path`.

## Controller

**`Admin::ExportsController`** inherits from `Admin::BaseController` (gets session-based authentication).

### `index` action

Renders the export page. Provides counts to the view:

- Total entries (`Entrant.count`)
- Eligible entries (`Entrant.eligible.count`)

### `download` action

Generates CSV based on `params[:type]`:

- `type=eligible` — uses `Entrant.eligible` scope (eligible + reinstated_admin)
- `type=all` — uses `Entrant.all`
- Invalid or missing type defaults to eligible

Response:

- Content-Type: `text/csv`
- Content-Disposition: attachment with filename `raffle-entries-eligible-20260315-153000.csv` or `raffle-entries-all-20260315-153000.csv`
- CSV generated in-memory using Ruby's stdlib `CSV` library

## CSV Columns

Fixed fields:

| Column | Source |
|--------|--------|
| `first_name` | `entrant.first_name` |
| `last_name` | `entrant.last_name` |
| `email` | `entrant.email` |
| `company` | `entrant.company` |
| `job_title` | `entrant.job_title` |
| `created_at` | `entrant.created_at` |
| `eligibility_status` | `entrant.eligibility_status` |

Interest area columns — one per entry in `Entrant::INTEREST_AREA_OPTIONS`, dynamically derived (not hardcoded). Each column contains `1` or `0`, computed as `entrant.interest_areas.include?(area) ? 1 : 0`.

Current interest areas and their column names:

| Column | Interest Area |
|--------|---------------|
| `penetration_testing` | Penetration Testing |
| `red_team` | Red Team / Adversary Simulation |
| `app_security` | Application Security |
| `cloud_infra_security` | Cloud & Infrastructure Security |
| `hardware_iot_security` | Hardware / IoT Security |
| `space_systems_security` | Space Systems Security |
| `security_training` | Security Training |

Column order: fixed fields first, then interest area columns.

The column name mapping (display name to snake_case header) should be defined in the controller or as a constant, derived from `Entrant::INTEREST_AREA_OPTIONS`.

## Export Page UI

Located at `/admin/export`. Wires up the currently-disabled "Export" nav link in the admin layout.

Page content:

- Entry counts: total and eligible
- Two download buttons with descriptions:
  - **"Eligible Entries"** — "Download entries eligible for the raffle only. Excludes entries marked as ineligible, excluded, or flagged for duplicate review."
  - **"All Entries"** — "Download all entries including excluded, duplicates, and ineligible"
- Styled consistently with existing admin pages (same card/button patterns)

## Tests

Controller tests for `Admin::ExportsController`:

- `download` with `type=eligible` returns only eligible/reinstated entries
- `download` with `type=all` returns all entries
- `download` with invalid or missing type defaults to eligible
- Response content type is `text/csv`
- Response has correct Content-Disposition with filename and timestamp
- CSV header row contains the expected column names in the correct order
- Interest area columns contain `1`/`0` values
- `index` renders successfully when authenticated
- Unauthenticated requests redirect to login (inherited from BaseController)

## Files to Create/Modify

- **Create:** `app/controllers/admin/exports_controller.rb`
- **Create:** `app/views/admin/exports/index.html.erb`
- **Modify:** `config/routes.rb` — add export routes
- **Modify:** `app/views/layouts/admin.html.erb` — enable the Export nav link
- **Modify:** `app/assets/stylesheets/admin.css` — export page styles (if needed)
- **Create:** `test/controllers/admin/exports_controller_test.rb`
