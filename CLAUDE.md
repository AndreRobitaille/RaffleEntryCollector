# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kiosk-based raffle entry and lead collection app for the Final Frontier Security booth at CypherCon. Runs offline on a Raspberry Pi 4 with a 10.1" touchscreen. See `DEVELOPMENT_PLAN.md` for the full specification.

## Tech Stack

- **Ruby on Rails** with **SQLite** (WAL mode)
- Frontend rendered locally in **Chromium kiosk mode**
- Target: Raspberry Pi 4, Raspberry Pi OS 64-bit (Debian Trixie)
- Fully offline — no external APIs, no network dependencies

## Common Commands

```bash
# Setup
bundle install
bin/rails db:create db:migrate

# Development server
bin/rails server -b 127.0.0.1

# Tests
bin/rails test                    # all tests
bin/rails test test/models/       # directory
bin/rails test test/models/entrant_test.rb        # single file
bin/rails test test/models/entrant_test.rb:42     # single test by line

# Database
bin/rails db:migrate
bin/rails db:rollback
bin/rails console

# Linting (if rubocop is configured)
bundle exec rubocop
bundle exec rubocop -a            # auto-fix
```

## Architecture

### Core Flow

```
Attract Screen → Entry Form → (Rules Modal) → Success Screen
                                                    ↓
                                              Start New Entry → Attract Screen
```

- 90-second idle timeout resets to attract screen
- Rails bound to localhost only — no exposed network services

### Key Domain Concepts

- **Entrants** — the single core model. Contains name, email, company, job title, interest areas, eligibility status
- **Eligibility statuses**: `eligible`, `self_attested_ineligible`, `duplicate_review`, `excluded_admin`, `reinstated_admin`, `winner`, `alternate_winner`
- **Duplicates** are flagged (same email, or name+company match) but **not blocked** — no embarrassing kiosk confrontations

### Admin Console

Accessed via password (not publicly linked). Provides entry management, CSV export, duplicate flagging, exclusion/reinstatement, and raffle drawing using `SecureRandom`.

### Data Integrity

Three layers: SQLite database, append-only submission log, periodic USB backup (by filesystem UUID).

## Workflow

- **GitHub Issues** track all implementation tasks ([issues](https://github.com/AndreRobitaille/RaffleEntryCollector/issues)). When starting, completing, or making progress on a task, update the corresponding GitHub issue (e.g., `gh issue close 3`, or add a comment with `gh issue comment`). Reference issues in commit messages (e.g., `Closes #3`).
- Implementation plan lives in `docs/plans/2026-03-14-implementation-plan.md` — issue numbers map to task numbers.

## Session Workflow (MUST follow)

### Starting a task
- **Always brainstorm first** before writing code for any new feature or non-trivial change. Use the brainstorming skill to explore requirements and design before implementation.

### Before every commit
1. **Run quality checks** — all three must pass before committing:
   - `bin/rails test` (full test suite)
   - `bundle exec rubocop` (linting — exclude `.html.erb` files)
   - `bundle exec brakeman --no-pager -q` (security scan)
2. **If working on a GitHub issue**, post a markdown comment to the issue (`gh issue comment <number>`) summarizing what was done in this commit.
3. **Reference the GitHub issue** in the commit message (e.g., `Closes #N` or `Issue #N`).
4. **Update local tracking** — if a task or todo item was completed, mark it as done in `docs/plans/2026-03-14-implementation-plan.md` and any other relevant local docs.

### Before ending a session
- Confirm all quality checks pass (tests, rubocop, brakeman) even if no commit is being made — catch regressions early.

## Design Constraints

- All UI must be touch-friendly with large tap targets (10.1" touchscreen, 1360x768)
- No CRM features, no lead scoring, no marketing slides
- Security-hardened for a security-conference audience: no autofill, no password storage, kiosk mode, localhost-only binding
