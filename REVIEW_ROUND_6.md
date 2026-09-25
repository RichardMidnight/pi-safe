# Review Round 6 — SC2181: stop testing `$?` directly (18 sites)

**Baseline:** `dev` at R5 (`f6cb58d`), 2918 lines, **62 findings / 11 codes**, `1.2.12.beta1`.
**Goal:** close **SC2181 ×18** — every `if (( $? ))` in the file. The fix is the file's **own native idiom** (bare `ES=$?` capture is already used **47 times** in this codebase, incl. the R4-split sites): capture the status immediately, test the variable.

## Proposed change (uniform, one pattern for all 18 sites)

```bash
    cmd …
-    if (( $? )); then
+    ES=$?
+    if (( ES )); then
```

**Sites (18):**

| Line | Function | Command whose status is tested |
|---|---|---|
| 300 | `pisafe_install_tool` | `sudo "$INSTALL" "$TOOL"` |
| 614 | `env_which` | `which which` (helper self-check) |
| 621 | `env_which` | `which "$FILE"` |
| 987 | `file_size` | `SIZE_BYTES="$(stat -c%s -- "$FILE")"` |
| 1152 | `media_backup` | `run_command "sudo pishrink.sh …"` |
| 1586 | `media_restore` | `media_restore_checklist` |
| 1593 | `media_restore` | `ui_countdown 10 "RESTORE"` |
| 1748 | `media_restore_checklist` | `OUTDEV=$(menu_select_device …)` |
| 1850 | `media_mount` | `udisksctl mount -b …` (loop) |
| 2060 | `media_format` | `ui_countdown 10 "ERASE MEDIA"` |
| 2157 | `media_format` | `run_command "udisksctl mount …"` |
| 2200 | `media_partition_info` | `PARTED_OUTPUT=$(sudo parted …)` |
| 2207 | `media_partition_info` | `LOOPBACK="$(sudo losetup …)"` (retry 1) |
| 2211 | `media_partition_info` | `LOOPBACK="$(sudo losetup …)"` (retry 2, nested) |
| 2217 | `media_partition_info` | `sudo mount …` |
| 2777 | `menu_settings_options` | `ON=$(… whiptail … 3>&1 1>&2 2>&3)` |
| 2832 | `menu_tools` | `DEVICE=$(menu_select_device "MEDIA DETAILS")` |
| 2842 | `menu_tools` | `DEVICE=$(menu_select_device "ERASE MEDIA")` |

**Why SAFE (provably equivalent):**
* `$?` immediately after a command holds exactly that command's (pipeline/assignment's) status; `ES=$?` captures it with no command, subshell, or option change in between, and `(( ES ))` tests the identical truth value (both treat the value purely as a non-zero check).
* No `local` added (bare `ES` — the file's existing global-workspace idiom; **no function anywhere declares `local ES`/`local RC`**, so scoping is untouched). Nothing executes between capture and test (immediately `if`), so no clobber window is introduced for the test.
* The two nested sites (2207/2211) each re-capture before their own test — the second capture overwrites `ES` only after the first test has already run.
* No rename, reorder, deletion, string, prompt, exit-code, or signature change. Branch decisions are byte-identical.

**Known consequence (accepted):** `ES` (a shared global this file already tramples) will hold the tested command's rc after each site — no later code in any affected function reads `ES` without re-capturing it first.

## Expected shellcheck result

SC2181×18 → 0 → **62 → 44 findings**, **11 → 10 codes**. SC2086 keep-list: 17/17 sites, lines shifted by the +1 insertions above each (verified: 129, 968→971, 1859→1868, 1979→1988, 2068→2078, 2465→2480, 2467→2482, 2471→2486, 2473→2488, 2475→2490, 2486→2501, 2488×3→2503×3, 2889→2907, 2898→2916, 2918→2936). File 2918 → **2936 lines** (exactly +18).

## Verification (run before report)

1. `bash -n pisafe`; `bash pisafe -v` → `1.2.12.beta1`.
2. A/B pristine-vs-live (pristine = R5 commit `f6cb58d` snapshot):
   * `env_which` (sites 614/621): real function extracted; `bash` (hit → rc 0 + `1`) and `definitely_missing_xyz` (miss → rc 1, no output) — **sudo-install arm never triggered in either** (`which which` succeeds on this box), so no package manager is invoked
   * `file_size` (site 987): real function extracted; existing temp file (stat hit, `-h` and plain) + non-existent path (stat fail → rc 1)
   * Remaining 14 sites are sudo/parted/losetup/udisksctl/whiptail/menu-interactive — not agent-runnable; proven by the equivalence argument above + per-hunk `git diff` read-through
3. shellcheck: **62 → 44**, codes **11 → 10**; sorted full-report site diff = exactly the 18 SC2181 lines removed, **0 added**; SC2086 keep-list 17/17 (shifted lines verified).
4. `git diff --stat`: `36 insertions / 18 deletions` (18× `ES=$?` inserted + 18× `if` line rewritten); 18 hunks, each mapping to one site in the table.

## Deliverables

1. `pisafe` modified per approved items.
2. `REVIEW_ROUNDS.md` Round 6 section.
3. Chat report, then **stop and wait for user functional testing + commit approval**. Candidate message: `review R6: capture $? into ES before testing (SC2181×18 → 44 findings)`. No push / tag / version bump.

**Status: APPROVED (user: "Approve all (recommended)") + APPLIED + VERIFIED — awaiting user functional testing and commit approval.**

## Results (measured 2026-09-25)

1. `bash -n pisafe` PASS; `bash pisafe -v` → `1.2.12.beta1`; `grep -c 'if (( $? ))'` → **0** (all 18 sites converted).
2. **A/B battery `/tmp/opencode/r6_ab.sh` — 5/5 PASS** (pristine R5 commit `f6cb58d` snapshot `/tmp/opencode/pisafe_preR6.txt` vs live):
   * `env_which` (sites 614/621): `bash` (hit → rc 0, prints `1`) and `definitely_missing_xyz` (miss → rc 1, no output) — byte-identical pre vs live; sudo-install arm provably never fires (`which which` succeeds on this box), so no package manager is invoked in either run
   * `file_size` (site 987): existing 5KB temp file with `-h` and plain modes — identical; non-existent path → rc 1 both (stat-fail guard proven)
   * Remaining 14 sites (sudo/parted/losetup/udisksctl/whiptail/menu-interactive) are not agent-runnable — proven by the equivalence argument (capture immediate, test immediate, no clobber window) + per-hunk `git diff` read-through
3. shellcheck (`-f gcc`): **62 → 44 findings, 11 → 10 codes** — site-diff shows exactly the **18 SC2181 lines removed**, all other findings present with line-shifts only; **zero new findings, zero unrelated removals**.
4. SC2086 keep-list: **17/17** at 129, 971, 1868, 1988, 2078, 2480, 2482, 2486, 2488, 2490, 2501, 2503×3, 2907, 2916, 2936.
5. File 2918 → **2936 lines** (exactly +18). `git diff --stat`: **36 insertions / 18 deletions** — 18 hunks, each = one `ES=$?` insertion + one `if (( $? ))`→`if (( ES ))` rewrite; full read-through found nothing outside the approved pattern.

### Note on the draft's keep-list prediction

The draft's worked example guessed 1859→1867; the correct (and measured) shift is **1859→1868** — nine insertions precede that line (300, 614, 621, 987, 1152, 1586, 1593, 1748, 1850), the draft's example had miscounted. The measured values above are authoritative.
