# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project

**PiSafe** — a single-file Raspberry Pi SD-card imaging app: backs up a device with `dd`, shrinks the last partition with `pishrink`, compresses with `zip`/`pigz`/`xz`/`zstd`.  It can also restore images. Pure bash (`#!/bin/bash`), ~2,900 lines, ~78 functions, no build system.

## File map

| Path | Purpose |
|---|---|
| `pisafe` | The application itself (single file) |
| `pisafe_test` | Interactive, **destructive** test harness (formats/restores a real device, defaults to `/dev/sda`). Human-driven only — agents must never run it. |
| `REVIEW_ROUNDS.md` | Progress log for the review campaign (user may keep their own copy in the worktree — inspect before overwriting) |
| `REVIEW_STATUS.md` | High-level campaign position doc, **user-maintained** — treat as the source of truth for campaign state; update only when asked |
| `REVIEW_FUNCTION_INVENTORY.md` | Function checklist + dependency order (generated 2026-10-18 from `dev` @ `16158f3`; 78 functions, 12 groups) |
| `lint.sh` | shellcheck gate (0 findings required) |
| `AGENTS_old.md` | Superseded workflow (kept for history) |
| `junk/` | Untracked drafts — ignore |

## Review campaign

We are stepping through the code from the published `v1.2.11` baseline toward a new release. Rules:

* Work one approved round at a time; the round prompt lives in `REVIEW_ROUND_N.md`.
* Read `REVIEW_ROUNDS.md` and `REVIEW_STATUS.md` at the start of every session before touching code.
* Update `REVIEW_ROUNDS.md` at the end of every round (changes, test results, open items).
* Function-review rounds work through `REVIEW_FUNCTION_INVENTORY.md` **in document order** (leaves → menus). Flip each function's status column (`open` → `partial`/`reviewed` + evidence) as its round lands; regenerate the doc if function structure changes.
* **Function-review focus (set 2026-10-18):** reliability first, then standards and readability. **Don't make unneeded changes** — no refactoring or cosmetic rewrites unless they serve one of those three.
* Release ladder (lesson of the 2026-10-18 beta.5 retraction — a published beta artifact is effectively frozen): **(a)** code done + agent battery green → **(b)** *user's* destructive-harness pass on that exact code → **(c)** tag + push. Step (c) always with explicit user confirmation.

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
* **Never run:** `pisafe_test`, or any `pisafe` command that installs, formats, restores, erases, or writes to a device. Actual functional testing is done by the user.

## Environment caveats — SMB share, live surface (2026-10-18, diagnosed)

* The repo lives on a CIFS mount (`//omv.local/…`, CIFS 3.1.1 with cloud-provider `reparse`/`upcall` options). It is a **live surface**: the user may be running `bash pisafe` from it, or editing files on it, concurrently with any agent session.
* **Recognized glitch signature:** `stat`/`ls` work and show the right size, but `open`/reads fail with `No such file or directory` and git can't hash the file. This is **not corruption** — it is the file pinned by another client holding it open (diagnosed 2026-10-18: a running `bash pisafe`, fd held to EOF) or a transient provider lease.
* **When it happens:** do *not* `reset --hard` / `restore` / `checkout --` to "clean" the status; work from the object DB instead (`git show dev:pisafe`, `git cat-file -s <ref>:pisafe`). Once the file is readable again, verify byte integrity with `git hash-object pisafe` vs `git rev-parse dev:pisafe`.
* **Detection one-liner:** `fuser -v pisafe` — names the process holding the file.
* **For the user (app-running tip):** run the app from a local copy so the share file isn't pinned while it's live — `cp pisafe /tmp/pisafe-run && bash /tmp/pisafe-run` (config/log writes still land where configured; only the script copy moves).
* Parallel sessions have reworked `REVIEW_ROUNDS.md` and introduced `REVIEW_STATUS.md` — inspect current contents before overwriting; prefer asking the user which doc is canonical for a given note.

## Git workflow

* Work happens on branch `dev` (fresh at `v1.2.11` script state). `dev_old` holds the pre-review work; do not touch it.
* `main` tracks `origin/main`; it is the release branch. Nothing in the review campaign modifies `main`.
* Small, focused commits — one per approved round — **only with explicit user approval**.
* Suggested commit message format: `review R<N>: <summary>` (e.g. `review R1: quote expansions, normalize whitespace, fix TB multiplier`).
* **No remote operation — push, tag create/delete, force-push — without explicit user confirmation of that specific action** (standing rule from 2026-10-18). The version bump (`SCRIPTVER`), copyright header, and tag are separate explicit user actions at release time.

## Known-issues backlog

| Item | Location | Round |
|---|---|---|
| TB multiplier typo `2014` | `pisafe`:844 | R1 (approved) |
| Unquoted single-token expansions | throughout | R1 (SAFE subset) |
| `get_ver_to_int`: no `local`s, global `parts` array, `let`, tab indentation | `pisafe`:710–717 | R2+ (indent is R1) |
| Stale harness: references removed `pisafe_beta` file | `pisafe_test` | later, user decides |
| Copyright header says `2018 - 2022` | `pisafe`:3 | **done in `3e9ecfd`** (now `2018 - 2026`; in beta.3/beta.4 + remote dev) |
