# Admin Page Styling Improvements

Three targeted improvements to admin pages: raffle page redesign, export page cleanup, and exclusion reason buttons.

## 1. Raffle Page Redesign

### Pre-Draw State

- Stats row (total, eligible, excluded) — unchanged
- **Instructions panel**: blue-bordered info box explaining the draw process:
  - Draws 1 winner + 2 alternates at once
  - Use "Announce" buttons to show each winner to the crowd
  - If winner doesn't respond within 2 business days, contact alternates in order
- **"Draw Winner + 2 Alternates" button**: single primary button, disabled if fewer than 3 eligible entries
- **Fail state**: if `eligible_count < 3`, the draw button is disabled and a warning message explains why ("Need at least 3 eligible entries to draw")

### Post-Draw State

- **Winner/alternate cards**: three stacked cards, each showing:
  - Label: "Winner", "Alternate #1", "Alternate #2"
  - Name (bold), email, company
  - "Announce" button — opens the full-screen celebration overlay
  - Winner card has a solid blue left border; alternate cards have a muted blue border
- **"Export Winners CSV" button**: appears only after draw is complete. Exports winner + alternates with contact info and draw order.
- **Draw history table**: uses existing `admin-table` classes (currently unstyled `<table>` with bare `<th>/<td>`)

### Full-Screen Celebration Overlay

- **Purely client-side** — no server round-trip. JavaScript shows/hides a hidden `<div>` overlay on the raffle page.
- Triggered by clicking "Announce" on any winner/alternate card
- Covers entire viewport with gradient background (`#1a1835` → `#26235a` → `#3b386f`)
- Accent gradient line across the top (`#5b8bcd` → `#a6da74` → `#5b8bcd`)
- Content centered:
  - "CONGRATULATIONS" label — green, uppercase, large letter-spacing
  - Name — white, very large font (~60px), bold
  - Company — sky blue, medium font (~24px)
- Small "Close" button in bottom-right corner; also closeable via Escape key
- Can be shown repeatedly — click Announce again anytime to re-show

### Backend Changes (Raffle Draw)

- `RaffleDraw.perform_draw!` currently draws one entry at a time. Add a new `perform_full_draw!` method that draws winner + 2 alternates in a single transaction.
- The draw button calls `perform_full_draw!` which:
  1. Checks eligible count >= 3; raises `RaffleDraw::InsufficientEntrants` if not
  2. Selects winner from eligible pool (re-queries `Entrant.eligible` each time), marks as `winner`
  3. Selects alternate #1 from *updated* eligible pool (winner now excluded), marks as `alternate_winner`
  4. Selects alternate #2 from *updated* eligible pool (winner + alt #1 now excluded), marks as `alternate_winner`
  5. Creates 3 `RaffleDraw` records with `draw_type` of `winner`, `alternate_winner`, `alternate_winner`
  6. Rolls back entire transaction on any failure
- `RaffleDraw::InsufficientEntrants` is a new exception class defined in `raffle_draw.rb` (alongside existing `NoEligibleEntrants`). The controller rescues both the same way.
- **Alternate ordering**: alternates are distinguished by `RaffleDraw.id` (auto-incrementing). The first `alternate_winner` record created is Alternate #1, the second is Alternate #2. The CSV export and UI derive "#1" / "#2" labels by ordering `alternate_winner` records by `id`.
- Keep existing `perform_draw!` for backwards compatibility with tests

### "Draw complete" definition

A draw is considered complete when at least one `RaffleDraw` record with `draw_type: "winner"` exists. The post-draw UI (winner cards, export button) is shown when `@draws.any?`. The draw is a **one-time operation** — once complete, the draw button is hidden and replaced by the winner cards. There is no "redraw" functionality.

### Winners CSV Export

- New export type `"winners"` in `Admin::ExportsController#download` (single location — no separate action on the raffle controller)
- Uses a separate `generate_winners_csv` method (the winners CSV has different columns than the entrant CSV, so `generate_csv` is not reused)
- Columns: draw_type (Winner/Alternate #1/Alternate #2), first_name, last_name, email, company, job_title, drawn_at
- Also writes to USB backup if available (same mechanism as existing exports)
- Filename: `raffle-winners-{timestamp}.csv`

## 2. Export Page Cleanup

### Stats Row — Full Breakdown with Context

Replace the current 2-stat row (Total, Eligible) with 4 stats. The `index` action in `Admin::ExportsController` needs to set `@excluded_count` and `@winners_count` in addition to the existing `@total_count` and `@eligible_count`.

| Stat | Color | Context hint |
|------|-------|-------------|
| Total | white | (none) |
| Eligible | green when >= 3, orange when < 3 | "min 3 for raffle" when green; "need 3+ for raffle" when orange |
| Excluded | red | (none) |
| Winners | blue | "not yet drawn" when 0; count when > 0 |

- Border-top color on the eligible stat card changes to orange when below threshold
- Summary line below stats: "42 eligible — ready for raffle" (green) or "Only 1 eligible — need at least 3 for raffle" (orange warning)

### Export Cards — Three Options, Aligned

Replace the 2-column grid with a 3-column grid:

1. **Eligible Entries** — existing, green download button
2. **All Entries** — existing, blue download button
3. **Winners** — new, blue download button. Only shown after raffle has been drawn. Shows "No winners drawn yet" in disabled state otherwise.

All cards use `display: flex; flex-direction: column` with `flex: 1` on the description paragraph so buttons align at the bottom regardless of description length.

## 3. Exclusion Reason Buttons

### Replace Text Field with Preset Buttons

Remove the freeform `text_field` for `exclusion_reason` and replace with 5 buttons:

| Button label | Stored reason string |
|-------------|---------------------|
| Sponsor / Vendor | `Sponsor / Vendor` |
| Event Staff | `Event Staff` |
| Duplicate | `Duplicate` |
| FFS Employee | `FFS Employee` |
| Other | `Other` |

### Behavior

- Each button is a `button_to` form that POSTs to `exclude_admin_entry_path` with the reason as a hidden field
- **No confirmation dialog** — clicking excludes immediately
- Reinstate is still one click away on the resulting page, so accidental exclusions are trivially reversible
- Buttons use `admin-btn--danger` styling (solid red, dark text)

### Applies to Both Eligible and Duplicate-Review States

The same button group replaces the text field in both the `eligible`/`reinstated_admin` and `duplicate_review` action sections of `entries/show.html.erb`.

## Files to Modify

| File | Changes |
|------|---------|
| `app/views/admin/raffle/show.html.erb` | Full rewrite: instructions, draw button, winner cards, announce buttons, export |
| `app/views/admin/exports/index.html.erb` | Stats with context, 3-column export grid, winners export card |
| `app/views/admin/entries/show.html.erb` | Replace text field with reason buttons in both exclude sections |
| `app/assets/stylesheets/admin.css` | New classes: winner cards, celebration overlay, contextual stat hints, reason buttons |
| `app/models/raffle_draw.rb` | Add `perform_full_draw!` method |
| `app/controllers/admin/raffle_controller.rb` | Update `draw` action to call `perform_full_draw!`, rescue `InsufficientEntrants` |
| `app/controllers/admin/exports_controller.rb` | Add `"winners"` export type to `download`; add `@excluded_count` and `@winners_count` to `index` |
| `app/controllers/admin/entries_controller.rb` | No changes needed — already reads `exclusion_reason` from params |
| `config/routes.rb` | No new routes needed (announce is client-side JS, winners export uses existing download path with `type=winners`) |
| `test/` | Update raffle draw tests, add full-draw tests, update exclusion tests |
