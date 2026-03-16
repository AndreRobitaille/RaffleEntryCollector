# Sponsor / Vendor Exclusion Modal

## Summary

When an admin clicks "Sponsor / Vendor" to exclude an entry, a modal dialog appears offering two choices: exclude just this individual, or exclude all entries from the same company. The same pattern applies in reverse when reinstating a sponsor-excluded entry. This replaces the current immediate single-entry exclusion for the "Sponsor / Vendor" reason only — all other exclusion reasons continue to work as before.

Additionally, the admin entries index now persists search and sort state in the session, so navigating away and back preserves the admin's view.

## Exclusion Modal

### Trigger

Only the "Sponsor / Vendor" exclusion reason button opens the modal. The other four reasons (Event Staff, Duplicate, FFS Employee, Other) continue to exclude immediately as they do today.

The "Sponsor / Vendor" button changes from a `button_to` form submission to a regular `<button>` with a Stimulus action that opens a `<dialog>` element rendered inline in the show template. The dialog contains the modal content and its own forms for the exclude actions.

### Modal Content

- **Header:** "Exclude as Sponsor / Vendor"
- **Context line:** "[Name] is from [Company]."
- **Primary action (top, filled button):** "Exclude [Name]" — excludes only this individual. This is the expected/default action and must be the most visually prominent.
- **Divider:** "or exclude the whole company"
- **Company preview panel:** Shows count of matching entries and a list of the first 3 (with "+ N more" if applicable). Company matching uses `LOWER(company) = LOWER(?)` in SQL since the company field is squished but not downcased. Only entries with status `eligible`, `duplicate_review`, or `reinstated_admin` are shown/counted (this implicitly excludes winners and already-excluded entries). The count and list include the current entry being viewed — they represent the full set that "Exclude All" would affect.
- **Bulk confirmation:** A text input where the admin must type "all" to unlock the "Exclude All" button. The button is disabled/grayed out until the input matches.
- **Cancel button:** Closes the modal with no action.

### Bulk Exclusion Behavior

Sets `eligibility_status` to `excluded_admin` and `exclusion_reason` to "Sponsor / Vendor" on all matching entries including the current entry (same company via `LOWER()` comparison, with status `eligible`, `duplicate_review`, or `reinstated_admin`). The operation is wrapped in a database transaction for atomicity. Entries with `self_attested_ineligible`, `winner`, or `alternate_winner` status are not touched — `self_attested_ineligible` is the entrant's own declaration and should be preserved; winners cannot be modified.

## Reinstatement Modal

### Trigger

When clicking "Reinstate" on an entry whose `exclusion_reason` is "Sponsor / Vendor" **and** there are other `excluded_admin` entries from the same company (case-insensitive match via `LOWER()`, excluding the current entry from this count), the modal appears. If no other company entries are excluded, reinstatement works as today (immediate, single-entry).

The current reinstate button changes from a `button_to` to a regular `<button>` with a Stimulus action when the modal condition is met. When the condition is not met (no other excluded company entries, or exclusion reason is not "Sponsor / Vendor"), the button remains a `button_to` with immediate behavior.

### Modal Content

- **Header:** "Reinstate Entry"
- **Context line:** "[Name] was excluded as Sponsor / Vendor."
- **Primary action (top, filled button):** "Reinstate [Name]" — reinstates only this individual.
- **Divider:** "or reinstate the whole company"
- **Company preview panel:** Shows count of excluded entries from the same company including the current entry, and the first 3 names. Includes all `excluded_admin` entries from the company regardless of exclusion reason — the admin may have excluded some individually for different reasons (e.g., "Event Staff," "Other"), and they should see the full picture. **Note:** "Reinstate All" will reinstate all of these, even those excluded for non-sponsor reasons. This is intentional — if the admin wants to keep specific individuals excluded, they can re-exclude them afterward.
- **Bulk confirmation:** Text input requiring "all" to unlock "Reinstate All" button.
- **Cancel button:** Closes the modal.

### Bulk Reinstatement Behavior

Sets `eligibility_status` to `reinstated_admin` and clears `exclusion_reason` on all `excluded_admin` entries from the same company including the current entry (case-insensitive match via `LOWER()`). Wrapped in a database transaction for atomicity.

## Post-Action Redirect

**Behavior change:** Both single and bulk actions now redirect to the entries index instead of the entry show page. This applies only to "Sponsor / Vendor" exclusions and their reinstatements. All other exclusion/reinstatement actions continue to redirect to the show page as they do today.

### Single Action (exclude or reinstate one person)

Redirects to the entries index with the admin's previous search and sort state preserved (restored from session). Flash notice: "Entry excluded." or "Entry reinstated."

### Bulk Action

Redirects to the entries index with a search for the first word of the company name pre-filled. "First word" is determined by splitting the company name on whitespace and taking element `[0]`. For single-word companies (e.g., "Accenture"), the full name is used. This overrides the stored session state so the admin can spot stragglers with slight name variations.

- **Exclude flash:** "N entries from [Company] excluded. Searching for other entries that may be related."
- **Reinstate flash:** "N entries from [Company] reinstated. Searching for other entries that may still be excluded."

## Index State Persistence

### Behavior

The entries index stores the current `search`, `sort`, and `direction` params in the Rails session on each visit. When the admin returns to the index without explicit query params, the stored values are restored. This is a global behavior improvement, not specific to the exclusion feature.

Page number is intentionally not persisted — after an exclusion or reinstatement changes the result count, the previous page number may no longer be valid.

### Logout

The `Admin::SessionsController#destroy` action is updated to call `reset_session` instead of only deleting `:admin_authenticated`. This clears all session state including stored search/sort params.

## Technical Approach

- **Stimulus + `<dialog>`:** Follows the same native `<dialog>` pattern as the existing `modal_controller.js`, but implemented as a new, separate Stimulus controller (`exclusion-modal`) with its own fetch, DOM population, and input validation logic.
- **New endpoint:** `GET /admin/entries/:id/company_matches` — accepts a `context` query parameter (`exclude` or `reinstate`). For `exclude`, returns entries with status `eligible`, `duplicate_review`, or `reinstated_admin`. For `reinstate`, returns entries with status `excluded_admin`. Response format: `{ count:, entries: [{ id:, first_name:, last_name:, email: }], company: }`. Limited to first 3 entries in the `entries` array; `count` reflects the total. Route added to the admin namespace in `routes.rb`.
- **New Stimulus controller:** `exclusion-modal` — handles opening the dialog, fetching company match data via the endpoint, populating the preview, and the "type all to confirm" input validation (enabling/disabling the bulk action button).
- **Session storage:** `session[:admin_entries_search]`, `session[:admin_entries_sort]`, `session[:admin_entries_direction]` — set on index visits, cleared on logout via `reset_session`.

## Scope Boundaries

- Only "Sponsor / Vendor" reason triggers the modal. Other reasons unchanged.
- Company matching is case-insensitive via `LOWER()` SQL comparison. The `company` field is squished on save but not downcased. No fuzzy matching.
- No new models or database migrations needed — uses existing `eligibility_status`, `exclusion_reason`, and `company` fields.
