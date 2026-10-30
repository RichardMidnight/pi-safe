# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project

**PiSafe** — a single-file Raspberry Pi SD-card imaging app: backs up a device with `dd`, shrinks the last partition with `pishrink`, compresses with `zip`/`pigz`/`xz`/`zstd`.  It can also restore images. Pure bash (`#!/bin/bash`), ~3,100 lines, no build system.

## File map

| Path | Purpose |
|---|---|
| `pisafe` | The application itself (single file) |
| `testing/` | Canonical harness tools (`pisafe_test.sh` + `pisafe_benchmark_test.sh`) — tracked, version-independent |
| `testing/pisafe_test.sh` | Interactive, **destructive** test harness (formats/restores a real device, defaults to `/dev/sda`). Human-driven only — agents must never run it. |
| `ver 1.2.12 development/` | The 1.2.12 development cycle (2026-10-26 reorg; **gitignored — kept on disk only**): all REVIEW_* docs + round prompts, RELEASE_NOTES_1.2.12.md, lint.sh, testing/ (bench + logs + plan) |
| `ver 1.3.0 development/` | Reserved for the next cycle (gitignored) — currently holds the 1.3.x punchlist |
| `ver 1.2.12 development/REVIEW_ROUNDS.md` | Progress log for the review campaign (user may keep their own copy in the worktree — inspect before overwriting) |
| `ver 1.2.12 development/REVIEW_STATUS.md` | High-level campaign position doc, **user-maintained** — treat as the source of truth for campaign state; update only when asked |
| `ver 1.2.12 development/REVIEW_FUNCTION_INVENTORY.md` | Function checklist + dependency order (generated 2026-10-18 from `dev` @ `16158f3`; 78 functions, 12 groups) |
| `ver 1.2.12 development/lint.sh` | shellcheck gate (0 findings required; runs shellcheck on `../pisafe`) |
| `archive/` | Known-good old release versions (tracked; byte-identical to `main`'s archive — the README install-block targets) |
| `AGENTS_old.md` | Superseded workflow (kept for history) |
| `junk/` | Untracked drafts — ignore |

## Review campaign

We are stepping through the code from the published `v1.2.11` baseline toward a new release. Rules:

* Work one approved round at a time; the round prompt lives in `ver 1.2.12 development/REVIEW_ROUND_N.md`.
* Read `ver 1.2.12 development/REVIEW_ROUNDS.md` and `REVIEW_STATUS.md` at the start of every session before touching code.
* Update `ver 1.2.12 development/REVIEW_ROUNDS.md` at the end of every round (changes, test results, open items).
* Function-review rounds work through `ver 1.2.12 development/REVIEW_FUNCTION_INVENTORY.md` **in document order** (leaves → menus). Flip each function's status column (`open` → `partial`/`reviewed` + evidence) as its round lands; regenerate the doc if function structure changes.
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

* `bash -n pisafe` — parse check (before and after every round); shellcheck gate: `bash "ver 1.2.12 development/lint.sh"`
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
* Parallel sessions have reworked `REVIEW_ROUNDS.md` and introduced `REVIEW_STATUS.md` (both under `ver 1.2.12 development/`) — inspect current contents before overwriting; prefer asking the user which doc is canonical for a given note.

## Git workflow

* Work happens on branch `dev` (the campaign branch). `dev_old` holds the pre-review work; do not touch it.
* **Session-close handoff (2026-10-26):** local `dev` = `b4b705c` (R20 `ab42ce6` + reorg `b4b705c`) = **2 commits ahead of `origin/dev` (`a842113`), NOT pushed**. Push/tag only with the user's GO for that specific action. Campaign position + open user calls: `ver 1.2.12 development/REVIEW_STATUS.md`; latest round: R21 in `ver 1.2.12 development/REVIEW_ROUNDS.md`.
* `main` tracks `origin/main`; it is the release branch. Nothing in the review campaign modifies `main`.
* Small, focused commits — one per approved round — **only with explicit user approval**.
* Suggested commit message format: `review R<N>: <summary>` (e.g. `review R1: quote expansions, normalize whitespace, fix TB multiplier`).
* **No remote operation — push, tag create/delete, force-push — without explicit user confirmation of that specific action** (standing rule from 2026-10-18). The version bump (`SCRIPTVER`), copyright header, and tag are separate explicit user actions at release time.

## Known-issues backlog

(Current open items live in `ver 1.2.12 development/REVIEW_STATUS.md` → `outstanding`; future-version ideas in `ver 1.3.0 development/pisafe_test_punchlist.txt`. Historical table below.)

| Item | Location | Round |
|---|---|---|
| TB multiplier typo `2014` | `pisafe`:844 | R1 (approved) |
| Unquoted single-token expansions | throughout | R1 (SAFE subset) |
| `get_ver_to_int`: no `local`s, global `parts` array, `let`, tab indentation | `pisafe`:710–717 | R2+ (indent is R1) |
| Stale harness: references removed `pisafe_beta` file | `pisafe_test` | **done** (harness R11–R16 rewrite, 2026-10-18) |
| gz images ≥ 4 GiB: 32-bit footer (ISIZE mod 2^32) makes the size unverifiable → spurious `restore [gz]` refusal | `pisafe` gz backup guard + `file_image_size` + restore gate | **done in `fe47be2`** (no longer makes gz ≥ ~3.9 GiB; footer size trusted; one uniform restore size path — 2026-10-23) |
| Copyright header says `2018 - 2022` | `pisafe`:3 | **done in `3e9ecfd`** (now `2018 - 2026`; in beta.3/beta.4 + remote dev) |
