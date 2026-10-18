# Review Round 13 — file layer (inventory group 7, `file_*`): 9 functions reviewed, 0 defects, 2 observations

**Baseline:** `development` @ `5229adb` (R12). `pisafe` = 3008 lines, blob `b0ddbd1`, version `1.2.12-beta.5`. `shellcheck` clean, `bash -n` clean.

**Goal (approved 2026-10-18, "continue"):** complete the function review of inventory **group 7 — file/size introspection**: `file_base`, `file_device`, `file_ext`, `file_folder_size`, `file_fs_freespace`, `file_image_size`, `file_list_image_files`, `file_path`, `file_size` (9 functions, all `open`). Campaign focus applies: **reliability first, then standards and readability — no unneeded changes**.

**Outcome:** all 9 scope functions read in full and exercised by a behavior battery that ran **the real external tools** (du, df, lsblk, stat, zipinfo, xz, pigz, zstd, column) against synthetic archives with a known **100000-byte payload** — every size pipeline produced **exactly 100000**. **No defects. No code changes.** Two minor observations logged (O1 version-parse drift risk, O2 trailing space).

## Scope + findings (each function read in full at `5229adb`)

| function | finding | evidence |
|---|---|---|
| `file_base` | `dirname`/`basename` + `${BASE%%.*}` (first-dot strip) — semantics match the comment; no-ext and spaced-name cases hold | T01 (`/d/sub/my image.tar` → `/d/sub/my image`; `a` → `./a`; `/d/x.y.tar` → `/d/x`) |
| `file_device` | `df -a` mount-point field 6 + `lsblk -o PKNAME,MOUNTPOINT,NAME` → **parent** block device of the mounted partition (right for "which disk holds this path"); header row excluded by `grep -v Mounted`; mount points are exact-token matched (`" /tmp "`) so substring collisions can't occur; **no matching row → empty output, no crash** | T04 (`/` on this host → `/dev/mmcblk0`, eMMC), T05 (`/tmp` is tmpfs here → empty) |
| `file_ext` | dot-grep + last-dot strip; empty for extensionless (feeds `file_image_size`'s `*)` guard) | T02 (`tar` / `` / a.tar.gz → `gz`) |
| `file_folder_size` | `du -sh \| cut -d/ -f1` correctly yields the size field because `du` prints `SIZE\tPATH` (first `/` boundary is after the tab — verified byte-exact with `od`); `-d` guard; `ES=$?` after the pipeline is only meaningful under the file-wide `set -o pipefail` (R10) — the battery reproduces that option | T06 (`304K ` for a 300000-byte tree; missing dir → `0`, rc0) |
| `file_fs_freespace` | `df --output=avail` + `tr -cd '0-9'` digit-filter (replaces the older `grep -v Avail` — more robust); dir-or-dirname dispatch; failure → early `return ES` (again pipefail-dependent); `-h` via `get_bytes` | T07 (pure digits; `-h` translated), T08 (bad path → rc≠0, no output) |
| `file_image_size` | **every format arm measured against real tools** with a 100000-byte payload: img/iso (`stat`), zip (`zipinfo -t` summary line), xz (the 2025 HovnovoD pin handles the `97.7 KiB (100,000 B)` form), gz (`pigz -l`), zst (`zstd -v -l` — current zstd 1.5.7 prints `human (decimal B)`, so `cut '( ' -f2` lands on the decimal) → **all 100000**; unsupported ext → `0` + rc1; empty-size guard intact | T10–T15 (exact), T16, T17 (`-h` == `get_bytes … -h`) |
| `file_list_image_files` | `cd`/`pwd-restore` pair; glob over image extensions with `-e` guard; **`IFS` is a global set→unset pair** — verified restored after the call (battery observes it in the parent shell, not a subshell); spaced filenames → `_`-normalized via sed; sizes from the two helpers | T19 (seeded dir: 6 formats + `my img.img`; human sizes present; CWD and IFS restored) |
| `file_path` | single `dirname "$*"` — fine for the single-path call convention | T03 |
| `file_size` | `stat -c%s --` (trailing `--` guards dash-prefixed names), `ES=$?` capture, `-h` via `get_bytes`, missing → `0` | T18 |

## Observations (no change made)

* **O1** `file_image_size`'s zip/xz/gz/zst arms are **version-sensitive text parses** of tool summaries. All are correct on this host (measured), and the xz arm already carries the 2025 format-drift fix (with the upstream reporter credited in-line). The **zst arm** matches the zstd ≥1.5.x `human (decimal B)` layout; if zstd ever changes that field again it degrades to the guarded `0` (verified guard path), the same graceful failure mode. Intrinsic to text-parsing third-party tools; no better portable option (no stable `--parseable` across the five tools worth requiring).
* **O2** `file_folder_size` leaves one trailing space (the `\t`→space sed normalization) — visible as a double space at line end in the backup-checklist `TrashSize = …` lines (L1044–1045). Purely cosmetic.

## Verified non-issues (checked, no action)

* `ES=$?` after pipelines in `file_folder_size`/`file_fs_freespace` looks fragile **only without** `set -o pipefail` — the script sets it (R10). Battery fact: without the option, T08's failed `df` would slip through as rc0 — the R10 change is what makes these two functions sound; noted rather than patched (adding per-function guards would be an unneeded change).
* `file_image_size`/`file_size` share the global `SIZE_BYTES`; `file_device` writes `MOUNT_POINT`/`BLK_DEV` globals — set-before-read, single-threaded bash, no live hazard (file-wide convention).
* `file_list_image_files`' IFS mutation is contained (set L991, unset L1000, no early return in between — the only `return` is L988, before the IFS line).
* `sudo du` in `file_folder_size` is the only elevation in the group; battery ran it as an unprompted passthrough with no password prompt path.

## Verification (measured 2026-10-18)

* `bash -n pisafe` — OK (unchanged file)
* `bash pisafe -v` — `1.2.12-beta.5`
* `./lint.sh` — **0 findings**
* Behavior battery **18/18 pass** (`/tmp/opencode/r13_battery.sh`, re-runnable): 9 scope functions + `get_bytes`; synthetic 100000-byte payload in all six formats; **real** du/df/lsblk/stat/zipinfo/xz/pigz/zstd/column (all read-only); `sudo` as no-op passthrough; `set -o pipefail` reproduced (the real script's option — required for the T08 failure path); IFS-restore observed in the parent shell.
  * *Transparency (harness bugs found and fixed before the green run, none masked a code path):* (1) the `sudo` passthrough stub initially did `shift` and thereby dropped the real command (`du`) — fixed to plain `"$@"`; (2) a shell-regex label collision in one loop (`$t_…` parsed as one variable) — cosmetic label only; (3) the T06 expectation omitted the intentional tab→`sed` trailing space — byte-verified with `od` first; (4) T05 initially assumed `/tmp` was block-backed — on this host it is **tmpfs**, and the graceful-empty result is the *correct* behavior, so the test now asserts that.
* **Code changes this round:** **none** — `git status` for `pisafe` unchanged after the round (blob `b0ddbd1`), consistent with "no unneeded changes".

## Status changes

9 functions `open → reviewed`: `file_base`, `file_device`, `file_ext`, `file_folder_size`, `file_fs_freespace`, `file_image_size`, `file_list_image_files`, `file_path`, `file_size`.
Inventory totals: **44 reviewed / 2 partial / 32 open** (was 35/2/41).

## Open items

* O1/O2 are noted, none block anything.
* Next in inventory order: **group 8 — whiptail dialogs** (`whiptail_calc_wt_size`, `whiptail_countdown`, `whiptail_fselect`), then `do`, `media`, `menu` (32 `open` + 2 `partial` remain).
* Release ladder unchanged: code done + battery green → user's destructive-harness pass on that exact code → beta.6 tag + push (each step separately confirmed).
