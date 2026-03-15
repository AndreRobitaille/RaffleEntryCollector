# Admin UI Styling — Design Spec

**Issue:** #14
**Date:** 2026-03-15

## Goal

Polish the admin interface with focused CSS changes that visually distinguish it from the kiosk mode using the green accent color (#A6DA74), and improve table readability and touch-friendliness.

## Design Decision

Keep the existing dark theme. Do NOT switch to a light theme. Use the green accent color more prominently so staff immediately know they're in admin mode, not the public-facing kiosk.

## Changes

### 1. Solid Green Header

Replace the current `linear-gradient(90deg, var(--accent), var(--blue))` header background with a solid `var(--accent)` green. This is the single strongest visual signal that differentiates admin from kiosk.

**File:** `app/assets/stylesheets/admin.css` — `.admin-header`

### 2. Green Top Accent on Stat Cards

Add a `border-top: 2px solid var(--accent)` to `.admin-stat` cards. Subtle reinforcement of the admin identity throughout the page.

**File:** `app/assets/stylesheets/admin.css` — `.admin-stat`

### 3. Alternating Table Rows

Add `background: rgba(59, 56, 111, 0.2)` to every even table row via `.admin-table__row:nth-child(even)`. Improves readability when scanning long entry lists.

**File:** `app/assets/stylesheets/admin.css` — new rule

### 4. Larger Touch Targets

Increase padding on interactive elements for the 10.1" touchscreen:
- `.admin-table__view-btn`: padding from `3px 10px` to `5px 12px`, font-size from `12px` to `13px`
- `.admin-pagination__link`: padding from `6px 12px` to `8px 16px`
- `.admin-btn`: padding from `8px 16px` to `10px 20px`

**File:** `app/assets/stylesheets/admin.css` — existing rules

## Out of Scope

- Theme changes (staying dark)
- Layout restructuring
- New components or views
- JavaScript changes

## Acceptance Criteria

- Header is solid green (#A6DA74)
- Stat cards have green top border
- Table rows alternate backgrounds
- Touch targets are visibly larger
- All existing tests pass
