# Review Round 14 — whiptail dialog layer (inventory group 8, `whiptail_*`): 3 functions reviewed, 1 defect fixed, 6 observations

**Baseline:** `development` @ `8f02414` (R13). `pisafe` = 3008 lines, blob `b0ddbd1`, version `1.2.12-beta.5`. `shellcheck` clean, `bash -n` clean.

**Goal (approved 2026-10-18, "next"):** complete the function review of inventory **group 8 — whiptail dialog helpers**: `whiptail_calc_wt_size`, `whiptail_fselect`, `whiptail_countdown` (3 functions, all `open`). Campaign focus applies: **reliability first, then standards and readability — no unneeded changes.**

**Outcome:** all 3 scope functions read in full and exercised by a behavior battery that **stubs `whiptail` and `tput`** (nothing interactive is ever launched) and captures the exact dialog arg list per call — so the *menu contents themselves* are assertable. **1 defect found and fixed (D-1, user-approved):** in the subdirectory menu of the file browser the documented `..` back-entry was silently clobbered, trapping the user in the subdirectory (the real app's only fselect site is the RESTORE image-file picker). `pisafe` **+2/−1 line** (blob `b0ddbd1` → `58440e9`, 3008 → 3009 lines). 6 minor observations logged (O1–O6), none block.

## Scope + findings (each function read in full at `8f02414`)

| function | finding | evidence |
|---|---|---|
| `whiptail_calc_wt_size` | size calc from `tput` correct for normal terminals; 120-wide clamp live; **three structurally dead guards** (L2391–2396 compare `WT_WIDTH`, which was unconditionally set to literal `80` three lines earlier — `-z`/`-lt 60`/`-gt 178` against a constant can't hold; likely intent was a *lower* clamp on `WT_WIDTH_WIDE` for small terminals — **O1**); if `tput` emits nothing (TERM unset) the tall/wide values go **negative** and only an upper clamp exists — **O2** (pinned) | T01 (24×100 → 14/93/13/20/80), T02 (60×200 → tall 50, wide clamped 120), T03 (empty tput → wide `−7` pinned; pre-existing behavior recorded) |
| `whiptail_fselect` | **D-1 (defect, fixed):** L2433 conditionally appends the `..` back-entry, but L2437's `FILES=("FILENAME" …)` is a full array *assignment* that wiped it. The back protocol was fully implemented elsewhere (L2491–2492 handles a `..` selection; L2496–2498 re-presents the parent menu when the child returns `..`; descent passes `"yes"` at L2495; the header documents arg 4 = "yes to allow go back in the file system") — only the menu entry never materialized. In the app (RESTORE picker, L1768) a user picking a subdirectory was **stuck** — ESC cancels the whole selection. Rest of the function verified sound: IFS tab/newline splitting keeps spaced names whole; `[tag, size]` pair protocol composes correctly; shared-global `FILE_SELECTED` recursion protocol works across levels (that's *why* L2496 sees the child's `..`); IFS set/unset always paired; Box-guard diagnostic works. Observations: **O3** documented arg-3 `FILE_MASK` unused (find hardcodes the six image extensions; L2429 shows intent; the real caller passes `"zip"` anyway) · **O4** `FILES=(no files)` fallback unreachable (header pair keeps length ≥ 2) · **O5** numeric-named directory would be misread as a size slot (pathological; clean fix = redesign pair protocol) | T07 (top-level pick → rc0 full path), T08 (ESC → rc1), T09 (descent → child pick → full path), **T10 red pre-fix → green post-fix (child menu contained no `..` entry pre-fix — the D-1 evidence)**, T11 (back-protocol: child `..` → parent re-presents → pick succeeds), T12 (spaced subdir name round-trip), T13 (empty dir → header row only, no crash), T14 (Box-guard aborts with diagnostic, in subshell) |
| `whiptail_countdown` | the Yes/No gate works as documented in its comment (this newt build has no `--timeout`; `--defaultno` = stop is the **safe** default for a destructive-op gate); `ES=$?` captured directly (no pipeline) ✓; **O6** arg-1 `MAX` is set but never used — the caller (L1931) passes `$SECONDS` into the dead parameter | T04 (Yes → rc0; args carry `--defaultno --yesno` + MB sizes), T05 (stub rc1 → function rc1), T06 (`42` provably never reaches the dialog — O6 pinned) |

## The fix (D-1, one line — user-approved "Fix D-1 and commit")

```diff
-    FILES=("FILENAME" "     SIZE   (IMAGESIZE)")
+    # append (not assign): keeps the conditional ".." back-entry added above
+    FILES+=("FILENAME" "     SIZE   (IMAGESIZE)")
```

`FILES` is `local` and starts empty (L2431), so append-vs-assign only differs when the `..` pair was added (i.e. the recursive descent path). **Top-level behavior is byte-identical** — the only call site (L1768) passes `ALLOW_BACK="no"`, so L2433 is a no-op and the array starts empty there. Descent menus gain exactly one leading `.. ..` pair (even count preserved for whiptail's tag/label pairing).

## Verification (measured 2026-10-18)

* **Pre-fix battery: 13/14 — exactly T10 (the D-1 intent check) red**, T11 green proving the back-protocol handler was live (forcing a `..` response works), isolating the failure to the missing menu entry.
* **Post-fix battery: 14/14 green** (`/tmp/opencode/r14_battery.sh`, re-runnable): 3 scope functions + real `get_bytes`/`file_ext`/`file_image_size` (the `.img` arm is plain `stat`); `whiptail` stubbed with **dialog-arg capture + scripted responses**; `tput` stubbed with fixed/empty values; test tree in `$OUT` (incl. a spaced-name dir and an empty dir).
* **Harness lesson found and fixed before the green run (documented for transparency):** the app invokes whiptail with `3>&1 1>&2 2>&3`; the stub must honor that by returning its response on **fd 2** (inside the stub that *is* the caller's `$( )` capture). The first battery version responded on stdout — selections arrived empty and 6 tests failed for the wrong reason; after the fd fix the pre/post evidence was clean.
* Gates post-fix: `bash -n` ✓ · `bash pisafe -v` → `1.2.12-beta.5` ✓ · `./lint.sh` **0 findings** ✓
* `git diff pisafe` = **+2/−1** (fix + comment); diff read in full before reporting.
* Extraction note: the fix adds one line — `whiptail_countdown` moved 2512–2526 → 2513–2527; battery ranges updated accordingly (position-sensitive, per established convention).

## Status changes

3 functions `open → reviewed`: `whiptail_calc_wt_size`, `whiptail_countdown`, `whiptail_fselect`.
Inventory totals: **47 reviewed / 2 partial / 29 open** (was 44/2/32).
Re-scanned with the v4 scanner post-fix (backup `inv_v4_r13.json`); rendered with the R14 ST annotations.

## Open items

* **O1–O6** noted, none block (details in the table above + inventory annotations).
* Next in inventory order: **group 9 — small action runners** (`do_countdown`, `do_beep`, `do_beep_up`, `do_beep_down`, `do_list_info`), then `media`, `menu` (29 `open` + 2 `partial` remain).
* New user-facing behavior to include in the destructive-harness pass: in the RESTORE file picker, pick a subdirectory and verify the new `..` row returns to the parent listing (previously a dead-end).
* Release ladder unchanged: code done + battery green → user's destructive-harness pass on that exact code → beta.6 tag + push (each step separately confirmed).
