# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project

**PiSafe** — a single-file Raspberry Pi SD-card imaging app: backs up a device with `dd`, shrinks the last partition with `pishrink`, compresses with `zip`/`pigz`/`xz`/`zstd`, and restores images. Pure bash (`#!/bin/bash`), ~2,900 lines, ~78 functions, no build system.

## File map

| Path | Purpose |
|---|---|
| `pisafe` | The application itself (single file) |
| `test_pisafe` | Interactive, **destructive** test harness (formats/restores a real device, defaults to `/dev/sda`). Human-driven only — agents must never run it. |
| `REVIEW_ROUNDS.md` | Progress log for the review campaign (create it in Round 1) |
| `AGENTS_old.md` | Superseded workflow (kept for history) |
| `junk/` | Untracked drafts — ignore |

## Review campaign

We are stepping through the code from the published `v1.2.11` baseline toward a new release. Rules:

* Work one approved round at a time; the round prompt lives in `REVIEW_ROUND_N.md`.
* Read `REVIEW_ROUNDS.md` at the start of every session before touching code.
* Update `REVIEW_ROUNDS.md` at the end of every round (changes, test results, open items).

## Change classification

### SAFE — behavior-preserving; allowed in a cleanup round without per-item approval

* Arithmetic typos (e.g. line 844: TB multiplier `2014` → `1024` in `get_bytes`)
* Quoting **single-token** expansions (paths, command arguments, test operands) where quoting is provably equivalent
* Whitespace: trailing spaces, tabs → 4-space indentation, double-space clutter
* Syntax standardization: `[` → `[[` in simple tests, `;then` → `; then`, single-line `if…then…fi` → multi-line, consistent `[[ ]]`/keyword spacing, aligned `;;` in case blocks

### RISKY — log it, never apply silently; user decides per item

* Anything changing word-splitting/glob semantics of list variables (`for X in $LIST` loops)
* Adding or moving `local` (changes scoping, can hide or fix real bugs)
* Renames, reordering, deleting code
* Adding `set -euo pipefail`
* Changing user-visible strings, prompts, exit codes, or function signatures
* Quoting an expansion that could be `echo` flags, an `=~` regex RHS, or a glob-pattern RHS

## Verification playbook (agent-safe only)

* `bash -n pisafe` — parse check (before and after every round)
* `bash pisafe -v` — prints the version and exits (safe, non-interactive)
* Subshell spot-tests of pure functions: extract with `sed -n 'START,ENDp'` into a standalone file that stubs UI helpers, run test inputs, compare output
* `git diff --stat` and a read-through of the full `git diff` before reporting
* **Never run:** `test_pisafe`, or any `pisafe` command that installs, formats, restores, erases, or writes to a device. Actual functional testing is done by the user.

## Git workflow

* Work happens on branch `dev` (fresh at `v1.2.11` script state). `dev_old` holds the pre-review work; do not touch it.
* `main` tracks `origin/main`; it is the release branch. Nothing in the review campaign modifies `main`.
* Small, focused commits — one per approved round — **only with explicit user approval**.
* Suggested commit message format: `review R<N>: <summary>` (e.g. `review R1: quote expansions, normalize whitespace, fix TB multiplier`).
* **Never push, tag, or bump the version during review rounds.** The version bump (`SCRIPTVER`), copyright header, and tag are a separate explicit user action at release time.

## Known-issues backlog

| Item | Location | Round |
|---|---|---|
| TB multiplier typo `2014` | `pisafe`:844 | R1 (approved) |
| Unquoted single-token expansions | throughout | R1 (SAFE subset) |
| `get_ver_to_int`: no `local`s, global `parts` array, `let`, tab indentation | `pisafe`:710–717 | R2+ (indent is R1) |
| Stale harness: references removed `pisafe_beta` file | `test_pisafe` | later, user decides |
| Copyright header says `2018 - 2022` | `pisafe`:3 | release round |
