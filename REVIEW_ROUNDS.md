# REVIEW_ROUNDS.md — review campaign progress log

Campaign: step through `pisafe` from the `v1.2.11` baseline toward a new release, one approved round at a time.
Branch model: work on `dev`; `main` is release-only; commits only on explicit user approval; never push/tag/version-bump during review.

---

## Round 1 — SAFE cleanup (prompt: `REVIEW_ROUND_1.md`)

**Status: DONE — pending user functional testing (changes on `dev`, uncommitted).**
Baseline: branch `dev`, `pisafe` byte-identical to `v1.2.11` before work; `bash -n` and `bash pisafe -v` verified pre and post.

### Scope applied (count-asserted transform, 1066 ops; real file byte-identical to reviewed audit copy)

| Cat | Change | Count | Lines (original) |
|---|---|---|---|
| A | `*1024*1024*1024*2014` → `*1024*1024*1024*1024` (TB arm, `get_bytes`) | 1 | 844 |
| B | `x ; then` / `x ; do` → `x; then` / `x; do` — regex ` +; (then|do)\b` consumes the **full** stray-space run (6 sites had 2–3 spaces in the original, e.g. orig 1354 `]]   ; then`) | 49 | 273, 290, 312, 327, 396, 441, 597, 598, 688, 784, 790, 795, 800, 812, 880, 907, 934, 957, 979, 1113, 1136, 1281, 1294, 1333, 1339, 1354, 1374, 1380, 1528, 1689, 1697, 1703, 1750, 1986, 2003, 2014, 2070, 2079, 2089, 2101, 2257, 2356, 2385, 2386, 2394, 2408, 2542, 2549, 2885 |
| C | `env_terminal`: 9× `[ $(env_which X) ];then` → `[[ $(env_which X) ]]; then`; 9× `TERMINAL1=` 6sp→8sp | 9 + 9 | 569–585 / 570–586 |
| D | tabs → 4-space indentation (author convention: 1 tab = 1 level) | 70 | 686, 689, 711, 712, 714, 715, 1100–1107, 1257–1268, 1308, 1310, 1311, 1597, 1986–1999 (full list in audit report) |
| E | trailing whitespace stripped | 458 | (full list in audit report) |
| E-keep | trailing ws **kept** — EOL inside open multi-line string (user-visible `MSG`/`MESG`/`ui_msg_warning`/`ui_msg_error` content); verified with `cat -A` | 7 | 252, 1316, 1317, 1450, 1452, 1769, 1775 (=252, 1324, 1325, 1458, 1460, 1777, 1783 post-H) |
| F | `if  [[` → `if [[` (no `elif  [[` exists) | 7 | 321, 1294, 1703, 1750, 2051, 2206, 2853 |
| G | double-space clutter in arg lists / keyword adjacency (`;  do`×2 = 539+2470, `do_beep_up ;;`, `findmnt  -n -e  -o`, `column  -t`, ` $1  2>`×3, `ntfsprogs  #`, `get_args  $*` etc.) | 23 | 352, 396, 539, 557, 962, 1023, 1028, 1029, 1045, 1395, 1405, 1597, 2106, 2155, 2206, 2208, 2211, 2333, 2340, 2368, 2470 (2 hits), 2871 |
| H | one-line `if…fi` → multi-line | 5 | 1188, 1195 (12sp→12/16/12), 1202, 1208 (16sp→16/20/16), ~2468 defaults arm (1→4 lines) — **source of all +11 net lines** |
| I | quoting SAFE single-token expansions (command args, `[[ ]]` LHS, test operands, `return $ES`, `$(…)` results, whiptail args, `menu_cli` args…) | 237 | sum of ~60 pair ops (full per-pair list in audit report); incl. `return $ES`×22 [133…2805, 2839, 2902], `$(media_name $OUTDEV)`×9, `$(media_name $DEVICE)`×3 [2033, 2046, 2136], `INTERFACE`-cli×11, `SILENT`-y×5 |
| RULE | trailing `$FORCE` / `$LINENO` args on `ui_msg_*` calls quoted | 18 + 30 | `$FORCE`×18 [477–484, 487–494, 497, 498]; `$LINENO`×30 [1104, 1106, 1107, 1116, 1142, 1185, 1194, 1195, 1204, 1212, 1221, 1222, 1605, 1624, 1636, 1637, 1649, 1650, 1662, 1663, 1664, 2062, 2065, 2068, 2082, 2091, 2104, 2118, 2123, 2143] |
| J | `;;` alignment in top-level case spans (143 lines across 22 spans) | 143 | column = span's max content end + 1 space |

TOTAL ops: 1066 = **1059 conversions + 7 E-KEPT log entries** (script counts kept-ws lines as ops). `git diff`: 970 insertions / 959 deletions (net +11) · 2891 → 2902 lines.

### A: note on the round's claim

`REVIEW_ROUND_1.md` describes the L844 bug as "1000× too small". Actual: `2014/1024 ≈ 1.978`× **too large** — `get_bytes 2t -B1` returned `4325032067072` instead of the correct `2199023255552` (2×1024⁴). All other multipliers in the file were swept (924/980, 1096, 1402, 714, 1512 and the bc pipelines) — all correct; the `let`/global-`parts` issues in `get_ver_to_int` are flagged for R2, not touched.

### Verification (agent-safe only)

* `bash -n pisafe` — PASS before and after.
* `bash pisafe -v` — `1.2.11` before and after.
* **`get_bytes` before/after isolation** (`/tmp/opencode/get_bytes_before.sh`, `get_bytes_after.sh`, `gb_driver.sh`, 25 inputs covering every branch):
  ```
  BEFORE:  INPUT=[2t|-B1] RC=0 OUT=[4325032067072]      (same for 2tb / 2TB)
  AFTER:   INPUT=[2t|-B1] RC=0 OUT=[2199023255552]      (same for 2tb / 2TB)
  ```
  The other 22 outputs (k/m/g/b conversion, all human-readable length arms, pass-throughs, non-numeric) are byte-identical.
* `grep -P '[ \t]+$'` post: only the 7 deliberately-kept string lines (252, 1324, 1325, 1458, 1460, 1777, 1783).
* `grep -P '\t'` post: **0** matches.
* `grep -nE ' +; (then|do)\b'` post: only comment line L2318 (B skips comments by design); the `; do_beep*` separator lines at 2479–2481 never match (`do\b`).
* Full `git diff` read-through completed (transformed file byte-identical to the reviewed audit copy); `git diff -w`: 298 ins / 287 del (whitespace-only changes vanish; remaining = quoting + H expansions + the A fix).
* **B leftover sweep (post-audit):** 6 of B's 49 sites had 2–3 spaces before the `;` in the original (1294, 1354, 1374, 1380, 1703, 1750), so a single-space regex left 1–2 residual spaces (` ]] ; then` / ` ]]  ; then`). That is in-round SAFE (scope: "double-space clutter at construct boundaries"), so B's regex was widened to ` +; (then|do)\b` — provably the same 49 lines, same count assert — the pipeline was re-run from pristine, and the delta vs. the previously accepted state was verified to be exactly those 6 lines, whitespace-only (hence `git diff` stat identical: 970/959 and 298/287 with `-w`). Every battery item above was re-run after the change and passed; `get_bytes` after-file re-extracted from the final file (only the 3 TB lines differ vs. before).
* `menu_cli $1 "$2" "$3" "$YESNO"` (quoted `$YESNO`): proven safe — `YESNO` is initialized `-n` (L35) and only set to `-y`, never empty; receivers use `${N:-"-n"}` (L1072, L1563, L1979) so empty≡unset anyway.

### Judgment calls / deliberately left unchanged

* **Unquoted (L27 class — could be echo flags/list content/eval material):** `echo $BYTES` (2 sites), `echo $ON`, `echo $INPUT`, `echo $PRODUCTNAME ver $SCRIPTVER`, `printf $FILES`, `sed $VAR` (L462), `get_args $*` (only the double space removed), `local ARGS=$*`, `eval $CMD`-style, `media_format $2 $3 $4` (positional args; contrast: `media_backup/restore "$2" "$3" $4`).
* **List loops left unquoted (word-splitting semantics):** `for TOOL in $REQUIRED_TOOLS`, `for INSTALLER in $INSTALLERS`, `for TEXT_EDITOR in $TEXT_EDITORS`, `for DIR/FILE in $(find …)` / `$(ls …)`, `FILES+=($FILE)`.
* **`=~` RHS left unquoted (regex RHS must stay unquoted):** `[[ $arrayelement =~ $num ]]`, `[[ ! "$ARCH" =~ $BITS ]]` (double space before `$BITS` normalized, LHS quoted).
* `PARTITION=$DEVICE\1` — untouched.
* `cd $DIR` left unquoted (not in catalog; quoting it would *fix* a latent space-path bug = behavior change); `cd "$OLD_PWD"` quoted per catalog. Both logged for R2.
* J: `LOG)` arm in `menu_tools` case has `;;   # trailing comment` — cannot align without moving the comment; left as-is (only `;;`-terminating lines align). Max alignment column is 167 (span with a very long arm) — accepted cosmetic over-padding.
* `$FORCE`/`$LINENO` tail rules hit 3 comment lines (1194/1195-area, 1343, 1249/1251) — quoting inside comments, harmless.
* Inside `whiptail_fselect`: `FILES+=("$DIR" "     folder")` quoted (catalog) while sibling `FILES+=($FILE)` left as-is (list provenance) — inconsistency noted for R2.

### R2 candidates (observed, not touched)

1. `get_ver_to_int`: no `local`s, global `parts` array, `let`, tab indentation (indent fixed in R1) — `pisafe` ~701–712 post.
2. Same-family unquoted numeric args not in the R1 catalog: `get_bytes $BYTES_TO_READ -h`, `get_elapsed_time $TIME2 $TIME3`, `get_elapsed_time $TIME3 $TIME4`, `echo $INPUT`.
3. `cd $DIR` vs `cd "$OLD_PWD"` consistency; `FILES+=($FILE)` vs `FILES+=("$DIR")` consistency.
4. `sudo $INSTALL dosfstools` family (`$INSTALL` unquoted) — decide quoting policy.
5. Stale harness: `test_pisafe` references removed `pisafe_beta` file (user decides).
6. Copyright header `2018 - 2022` (L3) — release round.
7. Leftover cosmetic double-space sites outside the R1 catalog: L838 `else  # comment` (2 spaces), L1536 `[[ … = primary  ]]` (2 spaces inside `[[ ]]`).
8. **Functional-test finding — backup-estimate bug (pre-existing in v1.2.11, user saw it on a fat32 box):** `media_backup_estimate` returns its text via stdout (`echo "$MSG"`), but its `*` arm (final L1546, under the author's own comment `# need to verify next line works.`) calls `ui_echo`, whose `MSG="$1"` has **no `local`** — bash dynamic scoping means it **clobbers the caller's `local MSG`** — and its colored display goes to **stdout**. The two capture sites, `menu_get_outfile` (L2512) and `media_details` (L2163), therefore receive: the ANSI-wrapped warning (whiptail shows the codes literally), the *earlier* MSG content (estimate header, Media size, freespace, proper warning) lost to the clobber, and `Shrink filesystem by…` fused onto the warning (no separating newline). Verified byte-identical in pristine v1.2.11; R1 footprint in this region is whitespace/quoting-only (hunk `@@ -1518,33 +1526,33 @@`). Only the non-ext final-filesystem path is affected (ext4 arm has no `ui_echo`). Fix is RISKY (adds `local`; moves display stdout→stderr): either harden `ui_echo` itself (`local MSG`, `local COLOR`, `>&2` on all display arms) — fixes both capture sites at the root — or replace L1546 with `ui_log …` + `echo_red … >&2` (preserves log entry + terminal color, most surgical). No other function captured via `$(…)` calls `ui_echo`; nothing pipes its stdout. **User chose Fix B during functional testing — applied and verified; separate commit pending (below).**

### Commit (pending user approval)

`review R1: fix TB multiplier, quote SAFE expansions, normalize whitespace/indentation, split one-line ifs, align ';;' + round log`
— covering `pisafe` + `REVIEW_ROUNDS.md` (`AGENTS.md` and `REVIEW_ROUND_1.md` are already on `dev` at `9bab5f9`). **No push, no tag, no version bump.**

### Post-round fix (approved during functional testing) — `ui_echo` scope & stream (pre-existing v1.2.11 bug)

User saw the broken box while functional-testing with a fat32 last partition (duplicated warning, literal `^[[1;31m…^[[0m`, fused `not shrink.Shrink filesystem by 0`, estimate lines missing). Root cause = R2 candidate #8.

**Applied (Fix B — harden `ui_echo` itself; 6 lines, `pisafe` L1872–1873 + the 4 display arms):**

```diff
-    MSG="$1"
-    COLOR="${2:-grey}"
+    local MSG="$1"
+    local COLOR="${2:-grey}"
     local LOGIT="${3:-log}"   # or nolog
     ...
     case $COLOR in
-        red)        echo_red "$MSG"   ;;
-        white)      echo_white "$MSG" ;;
-        blue)       echo_blue "$MSG"  ;;
-        *)          echo -e "$MSG"    ;;
+        red)        echo_red "$MSG" >&2   ;;
+        white)      echo_white "$MSG" >&2 ;;
+        blue)       echo_blue "$MSG" >&2  ;;
+        *)          echo -e "$MSG" >&2    ;;
```

Blast-radius check: `ui_log` (file write) untouched; no caller captures/pipes the stdout of any function that calls `ui_echo` except the two estimate sites this fix repairs; interactive terminal output unchanged (stderr also reaches the terminal).

**Verified:**

* `bash -n pisafe` — PASS. `bash pisafe -v` — `1.2.11`.
* Harness `/tmp/opencode/ue_harness.sh` (extracts the real `ui_echo` from the file; caller mimics the `*`-arm pattern: `local MSG`, `ui_echo … red log`, append, return via stdout; captures stdout/stderr separately):
  * **BEFORE:** capture = `^[[1;31m~ Warning … will not shrink.^[[0m` + `~ Warning … shrink.Shrink filesystem by 0 …` — reproduces the user's box verbatim (duplicated, ANSI, fused, header/correct-warning lost).
  * **AFTER:** capture = only the accumulated estimate text (no ANSI, no duplication, no loss); the red warning now on stderr (terminal) as `ui_echo` was always meant to do; log path unchanged.

---

## Open items across rounds

| Item | Location | Round |
|---|---|---|
| `get_ver_to_int` (no locals, global `parts`, `let`) | `pisafe` ~701–712 | R2+ |
| `echo $INPUT` unquoted | `pisafe` ~1237 | R2+ |
| `cd $DIR` unquoted | `pisafe` ~1066 | R2+ |
| `FILES+=($FILE)` unquoted | `pisafe` ~2738 | R2+ |
| `sudo $INSTALL …` unquoted | `pisafe` fat16/fat32/exfat/ntfs arms | R2+ |
| Stale `test_pisafe` harness | `test_pisafe` | later, user decides |
| Cosmetic double-space sites (`else  #`, `[[ … = primary  ]]`) | `pisafe` 838, 1536 | R2+ |
| Backup-estimate `ui_echo` clobber + stdout pollution (pre-existing; fat32 box shows literal ANSI + fused lines) | `pisafe` L1546, L1872–1873, L2163, L2512 | **applied during R1 functional testing** (own commit pending) |
| Copyright header `2018 - 2022` | `pisafe`:3 | release round |
