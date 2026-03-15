# Printable ASCII Validation for Text Fields

**Issue:** #22 — Restrict text fields to standard US characters
**Date:** 2026-03-15

## Problem

The Entrant model accepts any Unicode in `first_name`, `last_name`, `company`, and `job_title`. This allows emoji, control characters, null bytes, Unicode tricks (homograph attacks, RTL overrides), and other non-standard input. At a security conference kiosk, this is both a defense-in-depth concern and an input sanity issue.

## Decision

Add a `format:` validation to the four text fields restricting them to printable ASCII (space `0x20` through tilde `0x7E`).

**Regex:** `/\A[ -~]*\z/`

This covers all keyboard-typeable characters: letters, digits, spaces, and all standard symbols (`!@#$%^&*()` etc.).

**Error message:** `"may only contain standard characters (letters, numbers, and common symbols)"`

## Why Not a Gem?

Rails already handles the major threats (SQL injection via parameterized queries, XSS via auto-escaping, CSRF tokens). This validation is a defense-in-depth layer that also blocks nonsense input. It's a one-line regex per field — a gem would be unnecessary abstraction.

## Scope

### Files Changed

- `app/models/entrant.rb` — add `format:` option to 4 existing `validates` lines
- `test/models/entrant_test.rb` — add tests for valid symbols, emoji rejection, non-ASCII rejection

### What It Catches

- Emoji (e.g., `Ada `)
- CJK, Cyrillic, accented characters
- Control characters and null bytes
- Unicode direction overrides, homograph characters

### What It Allows

- All standard keyboard input: `A-Z`, `a-z`, `0-9`, spaces
- All common symbols: `'-.&,()/:;!@#$%^*+=[]{}|\<>?~"`
- Everything a kiosk user could type on a physical keyboard

## Implementation

Add a constant and format validation to `Entrant`:

```ruby
PRINTABLE_ASCII = /\A[ -~]*\z/
PRINTABLE_ASCII_MESSAGE = "may only contain standard characters (letters, numbers, and common symbols)"

validates :first_name, presence: true, format: { with: PRINTABLE_ASCII, message: PRINTABLE_ASCII_MESSAGE }
validates :last_name, presence: true, format: { with: PRINTABLE_ASCII, message: PRINTABLE_ASCII_MESSAGE }
validates :company, presence: true, format: { with: PRINTABLE_ASCII, message: PRINTABLE_ASCII_MESSAGE }
validates :job_title, presence: true, format: { with: PRINTABLE_ASCII, message: PRINTABLE_ASCII_MESSAGE }
```

## Tests

- Valid: standard name with letters, spaces, hyphens, periods
- Valid: company with symbols (`&`, `(`, `)`, etc.)
- Invalid: emoji in first_name
- Invalid: accented character in last_name
- Invalid: CJK character in company
- Invalid: null byte in job_title
