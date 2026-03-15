# Whitespace Normalization for Text Fields (Issue #23)

## Problem

The `Entrant` model has no normalization callback. An entry with `" bob@test.com "` stores leading/trailing spaces, causing duplicate detection misses and inconsistent CSV exports. On a touchscreen keyboard, accidental double-spaces within fields are also plausible.

## Design

### Single `before_validation` callback in `Entrant`

Add `before_validation :normalize_text_fields` that:

1. **Squishes** `first_name`, `last_name`, `company`, `job_title` — strips leading/trailing whitespace and collapses internal whitespace runs to a single space.
2. **Squishes then downcases** `email` — email addresses are case-insensitive per RFC 5321, and the duplicate detector already compares with `LOWER()`. Storing lowercase ensures consistency.
3. **Skips nil values** — guards with `&.squish` to avoid `NoMethodError` on blank fields (presence validation handles the error).
4. **Leaves `interest_areas` alone** — JSON array, not free-text.

### No changes to `DuplicateDetector`

Already uses `LOWER()` comparisons. With normalized data stored, those comparisons become more reliable, not less.

### Implementation

```ruby
# In Entrant model
before_validation :normalize_text_fields

private

def normalize_text_fields
  self.first_name = first_name&.squish
  self.last_name = last_name&.squish
  self.company = company&.squish
  self.job_title = job_title&.squish
  self.email = email&.squish&.downcase
end
```

## Tests

- Whitespace is stripped from all text fields before save
- Internal double-spaces are collapsed
- Email is downcased
- Duplicate detection catches entries that differ only by whitespace/case
- Nil fields don't raise errors
