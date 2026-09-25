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

## Shellcheck safe-bucket cleanup (post-R1; user-approved 2026-09-25, pre-R2)

**Status: APPLIED to working tree on `dev` — pending user functional testing and commit approval (no commit yet).**
Trigger: user asked which remaining shellcheck findings could be fixed automatically and safely. Ran `shellcheck 0.10.0` (`-s bash`) on the current file (post R1 + `ui_echo` fix + version bump): **353 findings / 32 codes**. Classified each bucket against the campaign's SAFE/RISKY rules; the 5 provably-equivalent, mechanical buckets were approved by the user (recommended scope). **Committed as part of the approved round when approved (commit message TBC with user — options: dedicated `shellcheck: …` message, or fold into R2 if R2 prompt asks).**

### Scope applied (count-asserted transform `/tmp/opencode/scfix_transform.py`; 74 lines, 74 ins / 74 del)

| Bucket | Finding | Change | Count |
|---|---|---|---|
| SC2004 | redundant `$`/`${}` in arithmetic | `(( $ES ))`→`(( ES ))`, `$(( $A-$B ))`→`$((A-B))`, `FILES[$i]`→`FILES[i]`, `for ((i=$MAX))`→`for ((i=MAX))`, `${arraylength}`→`arraylength`; applied at each exact flagged span (55 findings / 49 lines); the inner `$(media_size …)` at L1100 intentionally untouched | 55 |
| SC2236 | `! -z` in `[[ ]]` | `[[ ! -z X ]]`→`[[ -n X ]]` (bash-equivalent) | 17 |
| SC2062 | unquoted constant `grep` pattern | `grep ^[1-9]:`→`grep '^[1-9]:'` (strictly safer; output identical) | 4 |
| SC2124 | `"$@"` joined in assignment | `MSG="$@"`→`MSG="$*"` in `ui_msg_error` / `ui_msg_warning` (identical joining) | 2 |
| SC2235 | test-only subshell | `( [[ ]] && [[ ]] )`→`{ [[ ]] && [[ ]]; }` at L1536 and L2896 (no assignments inside) | 2 |

Total: 80 findings; all other codes untouched. Pre-snapshot: `/tmp/opencode/pisafe.prescfix`.

### Verification (agent-safe only)

* `bash -n pisafe` — PASS pre/post.
* `bash pisafe -v` — `1.2.12.beta1`.
* `shellcheck --format=gcc` before/after: **353 → 273 findings (−80, exactly the 5 buckets; the 5 target codes all → 0)**. Line-level `comm` diff of the two reports: only removed lines are the 80 bucket findings (plus 5 findings at L2366 reappearing at ±1-column shifted positions after `FILES[$i]`→`FILES[i]`, and 2 `SC2143` notes whose messages reworded from `[ -z .. ]` to `[ -n .. ]` — same finding, still 3). **Zero new findings; zero unrelated removals.**
* Spot-test harness `/tmp/opencode/scfix_spot.sh` (stubs UI/bell helpers; extracts the real `get_bytes`, `get_elapsed_time`, `ui_msg_error/warning` from the file under test): **run identical on BEFORE (`pisafe.prescfix`) and AFTER** — 23 PASS; the single FAIL is a harness-expectation arithmetic error (`599999÷1024` truncates to `585kb`, identical in both runs = pre-existing). Covers: all bc `-h` arms (kb/mb/gb/tb), the de-`$`ed case arms L841–844 (`10kb -b`→10240 … `3tb -b`→3298534883328), passthroughs, the `ui_msg_warning` path (`abcdef -h`), `get_elapsed_time` 4 inputs, both `MSG` joins (multi-word + inner double-space preserved).
* Full `git diff` read-through: all 74 line-pairs belong to the 5 buckets; no other change; no lines added/removed.

### Deliberately NOT applied (logged; user decides per item)

* **SC2086 (126) / SC2046 (37):** residue of the R1 leave-list — echo/printf flags, `for in $(lists)`, `grep $VAR`, `cd $DIR`, `printf $FILES`, `local ARGS=$*`, `get_args $*`, `media_format $2 $3 $4`, `sed` programs, `PARTITION=$DEVICE\1`, `ls`-loops (SC2045/SC2035). Quoting any of these can change behavior (flag semantics, word-splitting, glob-RHS) — RISKY by rule.
* **SC2053 (2):** `[[ … = $OUTDEV ]]` / `[[ $1 = $ROOT ]]` — quoting `=`-RHS is the glob-pattern-RHS class the campaign classifies RISKY.
* **SC2155 (13)** local+assign (forbidden), **SC2181 (18)** `if (( $? ))` family (flow), **SC2034 (15)** mostly dynamic-scope false positives (`MEDIA_*` set for callers, `BLUE` via subshell echoes, config values), **SC2162 (5)** `read -r`, **SC2001 (5)** echo→printf, **SC2005/SC2116 (9+5)** `echo $(…)` idiom (trailing-newline/flag semantics — behavior-adjacent), **SC2143 (3)** `! grep -q` (exit-code subtlety), **SC2002 (5)**, **SC2012 (2)** ls→find, **SC2206/SC2207 (3)** array/list splitting, **SC2219 (1)** `let` (already the `get_ver_to_int` backlog item), **SC2116 `$(echo …)` in `MSG=$(echo "$MSG.$i")`** — echo-flag class.
* **SC2021 `tr` sets (L781–782, 899, 903) — potential real quirk, NOT applied:** L782 `tr -cd '[[kmgtbKMGTB]]'` — in `tr`, `[[` is the escape for a *literal* `[`, so the suffix set (and possibly the result) is muddled; `[[:digit:]]` (781/899/903) is the standard form. Changing these alters displayed suffixes → needs a dedicated fix + test, user decides.
* **SC2125 (L805–808) — works as-is, NOT applied:** `local m_ega=$k_ilo*$k_ilo` et al. assign **strings** (`1024*1024`); functional only because `bc` evaluates the parenthesized expressions (`…/(1024*1024*1024)`). Every "fix" would change the values → left.
* **SC2215 (L79/87) + dead code — NOT applied:** `notes_desktop_environment()` (L50–95) is **defined but never called**; its body is an unquoted OS reference table (`RaspberryPiOS-stretch lxterminal …`, `--- ARM ---`, `arch / manjaro - pacman -S`, …) that, if ever invoked, would run `arch` and friends as **real commands**. Pre-existing since v1.2.11 (dormant — zero callers). User chose: **leave it** (deletion = RISKY; backlog).
* **SC1001 (L2070):** `PARTITION=$DEVICE\1` — `\1` is an intentional literal `1` (e.g. `/dev/sda1`); informational, untouched.
* Residual shellcheck state after this cleanup: **273 findings / 27 codes**, all in the RISKY/backlog classes above (plus the pre-existing quirks) — nothing auto-fixable within the campaign's SAFE bar remains.

---

## Round 2 — Shellcheck Classes 1/2/3/5 (user-approved 2026-09-25)

**Status: APPLIED to `dev` working tree, full battery green — committed this round (see below).**
Baseline: pristine `903530f` (post R1 + `ui_echo` fix + version bump + 5-bucket shellcheck) → **273 findings / 27 codes, 2902 lines**.
Count-asserted transform `/tmp/opencode/sc_round2_transform.py`; **134 line-pairs → 172 findings resolved**; +1 net line (glob-loop guard) → 2902 → 2903.

### Scope applied

| Class | Findings addressed | Change |
|---|---|---|
| **1 — quote SAFE single-token expansions** | SC2086 (all but 17 keep-list) | install/self-copy (`"$SCRIPTNAME"`, `/usr/local/bin/"$SCRIPTNAME"`, `sudo "$INSTALL" "$TOOL"`, `bash/mv/rm "$SCRIPTNAME.tmp"`, `pi-safe/main/"$SCRIPTNAME" -O "$SCRIPTNAME.tmp"`), config `sed` ×3 (`sed 's~'"$SETTING"'=.*$~…'  "$CONFIG"`), `mkdir -p "$(file_path "$CONFIG")"`, `grep "$ROOT_MAJ":0`, `which "$FILE"`, `echo "$(env_terminal/installer/texteditor/root_device)"`, `-f "$FREQ" … sleep "$TIME"`, `echo "$(basename "$*")"`, `df "$(dirname "$FILENAME")"`, `echo "$(get_bytes "$SIZE_BYTES" -h)"` ×3, `cd "$DIR"`, `file_fs_freespace "$DEFAULT_PATH"`, `media_backup_checklist "$SILENT"`, the `echo Media/Skipping/Reading…` capture lines, `echo Compression set to level "$COMPRESSION_LEVEL"`, `echo_white "$(ls -s -h …)"` + `echo_white "Step 1/2/3 took $(get_elapsed_time …)"`, `get_bytes "$LARGE_DEVICE_READ_WARNING" -b`, `"(file_path "$OUTFILE")"`, `"$(file_base "$OUTFILE").img"` ×2, `parted "$INDEV" "$MEDIA" unit B`, all `get_bytes/media_size/file…` numeric args, `lsblk "$MEDIA" "$DEVICE" … grep "$MEDIA_LAST_PARTITION_NAME"`, `dd of="$OUTDEV"`, `pv -n -s "$RESTORE_BYTES"` ×4, whiptail `"$WT_HEIGHT" "$WT_WIDTH"` ×6 + `"$WT_HEIGHT_TALL" "$WT_WIDTH_WIDE"`, `udisksctl mount -b "$MEDIA""$PARTITION"` + `power-off "$MEDIA"`, `do_countdown "$SECONDS" "$MESSAGE"`, `ui_echo … "$COLOR" nolog`, `sudo umount "$DEVICE"`, `sudo "$INSTALL"` fat16/fat32/exfat/ntfs arms (×7), `grep "^$PARTITION:"`, `echo_white/red/echo "$MSG"`, `media_os "$INDEV"` / `media_backup_estimate "$INDEV"`, `options=($(media_list "$2" | sed 's/ / '"$FIELD_SEPERATOR"' /'))` |
| **2 — `read -r` + drop no-op `$(echo …)`** | SC2162 (5 → 0) + SC2005 (2) | `read -r …` on the 5 reads (menu key, whiptail-countdown ×2, `ui_yesno yn`, "Press any key to return"); `MSG=$(echo "$MSG.$i")` → `MSG="$MSG.$i"` ×2; `PREVIOUS_ELEMENT=$(echo "${FILES[$i]}")` → `PREVIOUS_ELEMENT="${FILES[$i]}"` |
| **3 — `echo`→`printf '%s\n'` (flag-eating / pipe contexts) + bc arms** | SC2001/SC2005 echo→printf family | `get_bytes` bc `-h` arms: 12 lines `echo $(echo …bc)kb` → `printf '%skb\n' "$(…bc)"` (kb/mb/gb/tb); `echo $BYTES` pass-throughs ×4 → `printf '%s\n' "$BYTES"`; `BASE`/`SUFFIX` `echo $BYTES\|tr` ×2 → `printf`; the `\|sed` pipes `FILE_NS`/`INFO`/`MSG`/`arrayelement`/`ON` → `printf`; countdown `echo $INPUT` → `printf '%s\n' "$INPUT"` |
| **5 — loop / array / exact size** | SC2086 ls-loop + size precision | `file_list_image_files`: `for FILE in $(ls *.img *.zip *.xz *.gz *.zst *.iso 2>/dev/null)` → real glob loop **+ guard line `[[ -e $FILE ]] || continue`** (+1 line); `ls -s|cut -f1|×1024` → `stat -c%s -- "$INFILE"` (924) / `"$FILE"` (981) — **exact byte size** (sparse now reports apparent size = approved semantic, was an `ls`-block KiB approximation); `parts=("$1")` in `get_ver_to_int` (quoting only — locals/`let`/global `parts` stay backlog); `FILES+=($FILE)` → `FILES+=("$FILE")`; `FILES[i]=$(echo "    " …  \((…)\))` → `FILES[i]="    $(…) (…)"` (fixes 4-space prefix + paren-escape) |

### Kept (RISKY / intentional — exactly 17 SC2086 survive, shifted +1 after L957)

`eval $CMD` (129), `printf $FILES` (963), `umount $MEDIA?` (1850), `$DEFAULT --yesno` (1970), `sudo umount $DEVICE?` (2056), `media_backup|restore "$2" "$3" $4` (2453/2455), dispatch `$2` (2459/2461/2463), `media_format $2 $3 $4` ×3 (2474/2476), `pisafe_uninstall $2` (2874), `get_args $*` (2883), `menu_cli $1 …` (2903). **Nothing new introduced.**

### Verification (agent-safe only) — all green

* `bash -n pisafe` — PASS pre & post. `bash pisafe -v` — `1.2.12.beta1`.
* `shellcheck 0.10.0 -s bash -f json`: **273 → 102 findings** — 172 findings resolved (exactly the four approved classes) + 1 new shellcheck FP, net −171. Line-level diff vs baseline: only the applied findings removed; zero unrelated removals, zero new (other than the one FP below).
* **Residual 102 = 19 codes:** SC2181×18 · SC2086×17 (keep-list) · SC2034×15 · SC2155×13 · SC2005×9 · SC2002×5 · SC2021×4 (tr `[[`) · SC2125×4 (bc string-as-value) · SC2143×3 · SC2053×2 (`[[ = ]]` glob-RHS) · SC2027×2 · SC2164×2 · SC2215×2 (dead `notes_desktop_environment`) · singletons SC1001/SC2048/SC2059/SC2068/SC2207/SC2219.
* **New shellcheck FP (1):** SC2027 @ L1992 — `local NAME="$(lsblk "$DEVICE" …) ("$DEVICE")"`. shellcheck 0.10.0 mis-parses the `…cmd "$X") ("$X")"` form. Minimal repro flags the pattern, but `bash -n` passes and **runtime output is byte-correct** (`NAME=[VENDOR MODEL SIZE TYPE for /dev/sdb (/dev/sdb)]`). L2634 SC2027 (`whiptail ""${options[@]}""`) is pre-existing (baseline L2633).
* keep-list: all 17 SC2086 present at the +1-shifted lines; nothing new (list above).
* Spot harness `/tmp/opencode/scfix_spot.sh` (extracts the real `get_bytes`/`get_elapsed_time`/`ui_msg_*`): **25/25 PASS**. (Two expectations corrected on the harness side, not the app: `sed` extraction range 1926→1927 to absorb the +1 line; expected `586kb`→`585kb` — bc `scale=0` truncates, identical in pristine and live.)
* `get_bytes` pristine-vs-live: **byte-identical output on 20 inputs**.
* `config_var_set/clear/get`: LIVE ≡ PRISTINE (temp-CONFIG test).
* Size fns: regular file byte-identical (27,262,976 both); **sparse now apparent size** (1,025,024 vs old `ls`-based 16,384) = approved `stat -c%s`.
* `read -r` @ nested-quote sites (1992) proven valid at runtime; `bash -n` clean.
* **3 transform-script defects caught & fixed by the battery** (source of truth = `/tmp/opencode/sc_round2_transform.py`; none reached the file): (a) L1991 `old` swallowed the outer closing `"` → quote-parity breach → syntax error; fixed `new` to re-emit it. (b) L1348 Python **raw** string wrote literal `\"` into bash (→ passed literal quotes to `file_path` + spurious SC2086); fixed to plain nested quotes. (c) L924/981 `stat -c%s` replacement left a residual `* 1024` (1024× inflation — `ls` blocks are KiB but `stat -c%s` is bytes); empirically proven, fixed to plain `stat -c%s`.
* **1 RISKY-class slip found in full `git diff` read-through & removed:** Step-3 timing line had two delimiter spaces baked into the visible string (orig `echo_white  Step 3 took`, extra space = delimiter). Fixed to `echo_white "Step 3 took …"` (no leading spaces in output).
* `git diff --stat`: **134 insertions / 133 deletions** (net +1 = the L957 loop-guard line). Every hunk read through — all in the approved classes (quoting-only or the approved restructures); no out-of-class change.

### Commit (approved by user 2026-09-25)

`review R2: shellcheck classes 1/2/3/5 — quote expansions, read -r, echo→printf, stat -c%s sizes, ls→glob loop (273 → 102 findings)`
— covering `pisafe` + `REVIEW_ROUNDS.md`. **No push, no tag, no version bump.**

---

## Round 2 regression fix — device-selector trailing space (found in user functional testing 2026-09-25)

**Status: DONE — committed (see below).**

User testing `1.2.12.beta1` hit: `~ Error at line 1304. IN-DEV '/dev/sda' not found` — backup → pick `/dev/sda`. Repro signature: a **trailing space** inside the quotes. 1.2.11 (same action) worked.

### Root cause (proven, not guessed)

The whiptail menu tags built by `menu_select_device` **always** carry exactly one trailing space: `media_list`'s line is `sed 's/ / | /'`-ed (space-pipe-space) and then split on the pipe **only** (`""${options[@]}""` with `IFS='|'` field-splitting), so tag = `sda␣`, text = `␣SanDisk …`. True since v1.2.11 — but 1.2.11 ended the function with **unquoted** `echo $DEVICE_SELECTED`, whose word-splitting accidentally stripped the space and **masked** the dirty tag.

R2 class-1's quoting of that line (`echo "$DEVICE_SELECTED"`) is the *correct* change (no flag-eating) but unmasked the latent quirk: `INDEV`/`OUTDEV`/`DEVICE` = `sda␣` → `[[ ! -e "/dev/sda " ]]` → error. Affects **all four** TUI device pickers (backup L1426, restore L1738→L1754, media-details L2816, erase L2826) — they all consume this single `echo`.

Sweeps performed to bound the regression set:
* **every** R1/R2 `echo $VAR` → `echo "$VAR"` change re-audited (via the 1.2.11 pristine, `9bab5f9`): this one is the only value-capture from a `|`-split menu; the rest are printf-in-pipe to `sed`/`tr` on numbers/messages — all verified equivalent in the R2 battery.
* **every** `""…@…""` splitter idiom: only `menu_select_device` (plus one `"$MEDIA""$PARTITION"` concatenation, not a list).
* **every** `for X in $LIST` loop: still unquoted / word-splitting intact (only `seq 1 "$MAX"`, R2 glob rewrite, `find "$LOCAL_PATH"` changed — all fine).

→ **No other regression of this class.**

### Applied (Fix C — user-chosen; keeps correct quoting, zero display change)

```diff
   #  OUTDEV=$DEVICE_SELECTED
   #  INDEV=$DEVICE_SELECTED
+    # The menu separator ' | ' is split only on '|', so the returned tag carries one trailing space
+    # (e.g. 'sda '). Strip it so device names are clean for [[ -e ]] / path checks downstream.
+    DEVICE_SELECTED="${DEVICE_SELECTED% }"
     echo "$DEVICE_SELECTED"
```

* `${var% }` strips **at most one** trailing space — exactly the space the ` | ` separator always inserts; no-op if absent; device names contain no spaces so nothing legitimate is lost.
* No unquoted-echo reintroduced, no word-splitting reliance, menu display identical to 1.2.11.
* Considered alternatives: A = revert to `echo $DEVICE_SELECTED` (pure 1.2.11, but re-introduces the anti-pattern and leans on word-splitting); B = change the separator sed to a bare `|` (root-cause, but changes visible menu text — out of SAFE scope). C restores identical behavior with the cleaner mechanism.

### Verification

* `bash -n pisafe` PASS; `bash pisafe -v` → `1.2.12.beta1`.
* End-to-end harness `/tmp/opencode/run_seldev.sh`: drives the **real live** `menu_select_device` (extracted from the file) with a stubbed `media_list` and a fake `whiptail` honoring the real `3>&1 1>&2 2>&3` convention (tag → fd3/capture pipe, dialog → fd1/terminal) that returns the first tag exactly as the menu built it (`sda␣`). **BEFORE fix:** returned `sda␣` → `/dev/sda␣` FAILS `[[ -e ]]` (reproduces the user's error verbatim). **AFTER fix:** returns clean `sda` → `/dev/sda` OK.
* `git diff`: +3 lines (2 comment + 1 trim) inside `menu_select_device` only; nothing else touched.

### Commit (approved by user 2026-09-25)

`review R2: fix device-selector trailing-space regression (menu tag 'sda ' -> 'sda')`
— covering `pisafe` + `REVIEW_ROUNDS.md`. **No push, no tag, no version bump.**

---

## Post-R2 safe cleanup — `get_bytes` bc-string multipliers (SC2125)

**Status: APPLIED + VERIFIED (change on `dev`, uncommitted — commit pending user approval).**
User-approved 2026-09-25, after the R2 regression fix.

### Scope applied (4 lines, `get_bytes` `-h` arm)

Quote the four `bc`-string multipliers so the literal `*` is unambiguously not a glob — this is exactly what SC2125 asks for:

| line | before | after |
|---|---|---|
| 805 | `local m_ega=$k_ilo*$k_ilo;`  | `local m_ega="$k_ilo*$k_ilo";`  |
| 806 | `local g_iga=$m_ega*$k_ilo;` | `local g_iga="$m_ega*$k_ilo";` |
| 807 | `local t_era=$g_iga*$k_ilo;` | `local t_era="$g_iga*$k_ilo";` |
| 808 | `local p_eta=$t_era*$k_ilo;` | `local p_eta="$t_era*$k_ilo";` |

**Why SAFE (provably value-neutral):** an assignment performs no glob or word-splitting expansion, quoted or not, so the value is unchanged — `1024*1024`, `1024*1024*1024`, etc. Subshell A/B confirmed: `unquoted=[1024*1024]  quoted=[1024*1024]  -> IDENTICAL`. The strings are interpolated **verbatim** into `bc` expressions (`echo "scale=2; $BYTES/($m_ega)" | bc`), where `bc` does the arithmetic — quoting the *assignment* cannot affect that. The earlier 5-bucket "don't apply" note was about the *numeric* fix (`$((k_ilo*k_ilo))`), which would have broken `bc`; quoting is the neutral fix.

### Verification (agent-safe only)

* `bash -n pisafe` PASS; `bash pisafe -v` → `1.2.12.beta1`.
* Subshell A/B: quoted vs unquoted assignment value byte-identical; `bc` demo `123456/(1024*1024)` = `.11`.
* `get_bytes` functional spot-test (stubbed UI helpers, all arms): human `1024→1.00kb`, `1048576→1.00mb`, `1073741824→1.00gb`, `1099511627776→1.00tb`; byte `10kb→10240`, `5mb→5242880`, `2gb→2147483648`, `1tb→1099511627776`; pass-through `100 -h→100`, `1024kb -h→1024kb`, `300 -h→300`. **All correct.**
* shellcheck: **SC2125 ×4 → 0**; total findings **102 → 98** (19 → 18 codes).
* `git diff --stat`: `pisafe | 8 +++++----` — exactly the 4 intended lines, nothing else.

### Commit

Pending user approval (SAFE, verified). Candidate message: `review cleanup: quote get_bytes bc-string multipliers (SC2125×4 → 0)`.

---

## Round 3 — small, testable shellcheck fixes (all 7 approved)

**Status: APPLIED + VERIFIED (changes on `dev`, uncommitted — commit pending user approval).**
User-approved 2026-09-25 (all of R3.1–R3.7; R3.5 chosen as `cd || true`).
Prompt: `REVIEW_ROUND_3.md`.

### Scope applied (7 lines)

| item | Finding (line) | before | after |
|---|---|---|---|
| R3.1 | SC2021 (782) `get_bytes` | `tr -cd '[[kmgtbKMGTB]]'` | `tr -cd 'kmgtbKMGTB'` |
| R3.2 | SC2053 (1771) `media_restore_checklist` | `[[ $(file_device "$INFILE") = $OUTDEV ]]` | `… = "$OUTDEV" ]]` |
| R3.3 | SC2053 (2023) `media_format` | `[[ $1 = $ROOT ]]` | `… = "$ROOT" ]]` |
| R3.4 | SC2164 (952) `file_list_image_files` (entry `cd`) | `cd "$DIR"` | `cd "$DIR" \|\| return 1` |
| R3.5 | SC2164 (966) restore `cd` | `cd "$OLD_PWD"` | `cd "$OLD_PWD" \|\| true` |
| R3.6 | SC2143 (2215) `media_partition_info` | `[[ -n $(echo "$BITS" \| grep 32) ]]` | `echo "$BITS" \| grep -q 32` |
| R3.7 | SC2143 (2217) `media_partition_info` | `[[ -n $(echo "$BITS" \| grep 64) ]]` | `echo "$BITS" \| grep -q 64` |

### Rationale / why each is safe

* **R3.1** — tr parsed `[[kmgtb…]]` as literal `[` + set + literal `]`, so the set *accidentally* also kept `[`/`]`. Proven identical: for every realistic size input (`1024kb`, `5mb`, …) both forms return the **same** suffix; only diverges if a size string ever contains a bracket (it never does). The `[[:digit:]]` cases (781/899/903) are *correct* POSIX classes — left untouched (shellcheck FPs).
* **R3.2 / R3.3** — `[[ a = b ]]` matches `b` as a *pattern*; quoting forces a literal. Both operands are device paths (`/dev/sda`), never globs → quoting only makes the equality check more correct. (AGENTS.md lists "glob-pattern RHS" as RISKY — flagged and explicitly approved per item.)
* **R3.4** — entry `cd`; if it failed, the glob loop would have run in the caller's cwd. Fail-fast is the correct semantic.
* **R3.5** — best-effort cleanup *after* the list is already printed; a hard `return 1` would retroactively fail a successful call, so `‖ true` silences SC2164 without changing the observable return (approved alternative to leaving it).
* **R3.6 / R3.7** — `grep -q` exits 0 on match / 1 on no match, the exact truth value of `-n` over the captured output. Verified byte-identical across `x32y`/`64bit`/`arm`/`` /`32`/`64`.

### Verification (agent-safe only) — all green

1. `bash -n pisafe` PASS; `bash pisafe -v` → `1.2.12.beta1`.
2. **R3.1** suffix/base extraction for `1024kb 5mb 2gb 1tb 100 512mb 10 7tb` — base + suffix correct and identical to pre-fix (`100`→base `100`/suffix `""`; `1024kb`→`1024`/`kb`).
3. **R3.6/7** `grep -q` vs old `-n $(…)` — 6/6 inputs identical (32-arm, 64-arm, none, empty, bare `32`, bare `64`).
4. **R3.4/5** subshell harness of the real `file_list_image_files`: good dir → lists both files, `rc=0`; non-existent dir → `cd: … No such file or directory`, **`rc=1`, header never printed** (fail-fast proven).
5. shellcheck: **98 → 91** findings (−7: SC2053×2, SC2164×2, SC2021×1, SC2143×2); **18 → 16** codes (SC2053 and SC2164 now zero).
6. `git diff` — 8 hunks (7 R3 + the SC2125 fix), each mapping exactly to one approved item; nothing else touched.

### Explicitly left for later (out of scope this round)

* SC2143 **L1507** (multi-stage pipeline — `-q` would change which command's exit code is tested; needs redesign).
* SC2181×18, SC2155×13, SC2005×9, SC2002×5, SC2034×15 — the large mechanical sweeps / dead-var removal; each needs its own approved round + test battery.
* All previously-classified leave-as-is (SC2086 keep-list, menu idiom, L1992 SC2027 FP, SC2059/SC2048, SC2215 dead fn, SC1001, the three `[[:digit:]]` SC2021 FPs).

### Commit

✅ Committed `ed37b40` `review R3: quote = RHS + tr suffix, fail-fast cd, grep -q, bc-string quoting (102→91 findings)` (staged: `pisafe`, `REVIEW_ROUNDS.md`, `REVIEW_ROUND_3.md`). User functional testing of `1.2.12.beta1` passed before R4 started.

---

## Round 4 — variable hygiene (+ `get_ver_to_int` bug fix)

Full scope/approval/verification record: `REVIEW_ROUND_4.md`. Baseline: `ed37b40` (R3), 2906 lines, 91 findings / 16 codes, `1.2.12.beta1`.

### Changes applied (all user-approved)

1. **R4.1 — `get_ver_to_int` (L710–717):** `parts`/`val` → local; `let` → `(( ))`; `echo $val` → `echo "$val"`; dead `unset IFS` deleted.
2. **R4.1e — pre-existing bug FIX (discovered in R4 A/B, approved):** `parts=("$1")` is a *quoted* expansion → never word-splits (local IFS irrelevant) → **every dotted version** hit `let: 1.2.11: syntax error: invalid arithmetic operator (error token is ".2.11")` (stderr) + **empty stdout**, rc=0 — A/B-proven against the v1.2.11 baseline. Consequence in baseline: sole caller (update check L364, `SERVER_VER` dotted) compares `"" -gt ""` → **"UPDATE AVAILABLE" prompt dead since v1.x**, plus a syntax error printed to the user's terminal on every update check. Fixed with shellcheck-endorsed robust idiom: `IFS='.' read -r -a parts <<< "$1"` (user chose this over the minimal `parts=($1)`, which adds SC2206×1).
3. **R4.2 — SC2155 ×13:** split `local X=$(…)` → `local X` + `X=$(…)` at 271, 333, 781, 782, 854, 855, 1024, 1029, 1030, 1597, 1990, 1991, 1992. 12 sites provably neutral (no `$?`/`ES` consumed after). L1024 (`media_name`): the following `ES=$?` check is **dead today** (`local` always returns 0; post-split it captures the trailing `sed`'s status, effectively still 0) → **observable behavior unchanged**, verified good+bad device A/B.
4. **R4.3 — SAFE nits:** `else  #` → `else #` (838); `= primary  ]]` → `= primary ]]` (1537).

### Verification (all green)

1. `bash -n` PASS; `bash pisafe -v` = `1.2.12.beta1`.
2. `get_ver_to_int` A/B: baseline dotted → error+empty; live fixed: `1.2.3→1002003  1.2.11→1002011  0.1.0→1000  2→2000000  1.2→1002000  9.9.9→9009009  0.0.0→0  abc→0`; non-dotted inputs byte-identical to baseline. Global-leak: `parts`/`val` **unset** after live call (previously leaked).
3. `get_bytes` A/B (9 inputs): identical except WARN `$LINENO` diagnostic `11→13` (accepted). `file_base` A/B (5): identical. `media_name` A/B stubbed `lsblk` (good+bad): identical both.
4. shellcheck: 91 → **77 findings**, 16 → **14 codes** (SC2155×13→0, SC2219×1→0, nothing new). SC2086 keep-list: same 17 sites, lines shifted +5/+9/+12 by the splits above (… 968, 1859, 1979, 2068, 2465, 2467, 2471, 2473, 2475, 2486, 2488×3, 2889, 2898, 2918).
5. `git diff` — 17 hunks, each mapping to one approved item. File 2906 → 2918 lines (net +12).

### Explicitly left for later

* **`media_name` dead error check** (pre-existing, found in R4): `lsblk … | sed …` pipeline swallows lsblk failure, so `ES=$?`/`if (( ES ))` never fires — bad devices report ` -  ()` instead of failing. Needs `PIPESTATUS[0]` or empty-output check = logic change → backlog, user decides.
* SC2181×18, SC2005×9, SC2002×5, SC2034×15, SC2143×1 (L1507→now L1515) — later rounds.
* All leave-as-is classes (SC2086 keep-list, menu idioms, FPs).

### Commit

✅ Committed `00b05fc` `review R4: variable hygiene — get_ver_to_int fix+locals, split local X=$(…) (SC2155/2219 → 77 findings)` (staged: `pisafe`, `REVIEW_ROUNDS.md`, `REVIEW_ROUND_4.md`). **No push, no tag, no version bump.**

---

## Round 5 — pipeline & command hygiene

**Status: APPLIED + VERIFIED (changes on `dev`, uncommitted — commit pending user approval).**
User-approved 2026-09-25 ("Approve all (recommended)"). Prompt: `REVIEW_ROUND_5.md`.
Baseline: `00b05fc` (R4), 2918 lines, **77 findings / 14 codes**, `1.2.12.beta1`.

### Changes applied (15 single-line replacements, line-neutral)

| item | Site | Change |
|---|---|---|
| R5.1 ×8 | 633–636 `env_sysinfo`; 945 `file_image_size`; 991 `file_size`; 1062 `media_size`; 1017 `do_list_info` | `echo "$(cmd)"` → `printf '%s\n' "$(cmd)"` — byte-identical **including** the empty-output edge: `env_terminal`/`env_texteditor`/`env_root_device` (can fail silently empty) and `get_bytes` (warn-return → empty stdout) print a **blank line** today; a bare `cmd` call would print nothing = behavior change. `printf '%s\n'` preserves exactly that, zero new findings |
| R5.2 | 877 `file_ext` | `echo "$(basename "$*")" | grep \\. \| sed …` → `basename "$*" | grep \\\. \| sed …` (output piped, not displayed; empty vs blank-line both miss `grep \.` identically) |
| R5.3 ×5 | 470 `config_var_get`; 1009 `do_list_info`; 2224 / 2245 / 2253 `media_partition_info` | `cat FILE \| grep …` → `grep … FILE` (identical bytes; mount sites already `[[ -e ]]`-guarded; failure class unchanged — grep-on-missing-file reports and outputs nothing, pipe status still the last command's) |
| R5.4 | 1515 `media_partition_info` (RISKY: exit-status restructure, approved per item) | `if [[ -z $(… \| grep primary) ]]` → `if ! … \| grep -q primary` — the L1515 site deferred in R3, now resolvable because **only the emptiness** of the capture is used; branch-decision identical on all inputs (pipeline status = last command's, in both forms; `-q` can only SIGPIPE upstream, which cannot change it) |

### Verification (agent-safe) — all green

1. `bash -n pisafe` PASS; `bash pisafe -v` → `1.2.12.beta1`.
2. **A/B battery `/tmp/opencode/r5_ab.sh` — 23/23 PASS** (pristine `00b05fc` snapshot `/tmp/opencode/pisafe_preR5.txt` vs live): `env_sysinfo` ×3 scenarios (all-present; editor-missing = silent empty; terminal-fail + root empty) — identical incl. empty→blank-line edge; `file_ext` ×5 + pipe form ×4 — identical; `get_bytes`-wrap non-empty + empty — identical; `media_list`-wrap multi-line + empty — identical; `config_var_get` hit + miss on a real temp `$CONFIG` — identical; os-release / fstab / cmdline expressions hit + miss — identical; **L1515 branch: 3 `PARTED_OUTPUT` fixtures (primary-last → not taken; no-primary → taken; primary with Free line after → not taken) — identical rc pre vs live on all 3**.
3. shellcheck (`-f gcc`, one line per finding): **77 → 62 findings, 14 → 11 codes** — exactly SC2005×9, SC2002×5, SC2143×1 removed; sorted full-report site diff = **15 removed lines, 0 added**.
4. SC2086 keep-list: **17/17 same lines** — 129, 968, 1859, 1979, 2068, 2465, 2467, 2471, 2473, 2475, 2486, 2488×3, 2889, 2898, 2918.
5. File stays **2918 lines** (all edits single-line). `git diff --stat`: **15 insertions / 15 deletions** — 15 one-line hunks, each mapping to an approved item; nothing else touched.

### Explicitly left for later

* **`media_name` dead error check** (pre-existing, R4 discovery — still open): `lsblk | sed` swallows lsblk failure; `ES=$?`/`if (( ES ))` never fires. Needs `PIPESTATUS[0]` or empty-output check = logic change.
* SC2181×18 (`if (( $? ))` family — flow restructuring), SC2034×15 (dead/dynamic-scope vars — deletion = RISKY), SC2207×1 (menu splitter idiom), SC2068×1, SC2059/SC2048/SC1001, SC2027×2 (1 FP), SC2021×3 (FPs), SC2215×2 (dead `notes_desktop_environment`) — later rounds if the user wants; all classified leave-as-is/RISKY.

### Commit

✅ Committed `f6cb58d` `review R5: drop useless echo/cat, grep files directly, -q emptiness test (SC2005/2002/2143 → 62 findings)` (staged: `pisafe`, `REVIEW_ROUNDS.md`, `REVIEW_ROUND_5.md`). **No push, no tag, no version bump.**

---

## Round 6 — SC2181: capture `$?` into `ES` before testing (18 sites)

**Status: COMMITTED as `87b6a38` on `dev` (user approved 2026-09-25).**
User-approved 2026-09-25 ("Approve all (recommended)"). Prompt: `REVIEW_ROUND_6.md`.
Baseline: `f6cb58d` (R5), 2918 lines, **62 findings / 11 codes**, `1.2.12.beta1`.

### Change applied (uniform, 18 sites in 10 functions)

Every `if (( $? )); then` → insert `ES=$?` on the line after the tested command + `if (( ES )); then`.
Sites: `pisafe_install_tool` 300 · `env_which` 614/621 · `file_size` 987 · `media_backup` 1152 · `media_restore` 1586/1593 · `media_restore_checklist` 1748 · `media_mount` 1850 · `media_format` 2060/2157 · `media_partition_info` 2200/2207/2211/2217 · `menu_settings_options` 2777 · `menu_tools` 2832/2842.

**Why SAFE:** `$?` is captured immediately after the command with nothing executable in between; `(( ES ))` tests the identical truth value; the file's **own idiom** — bare `ES=$?` already appears **47×** elsewhere (no function declares `local ES`/`local RC`, so scoping untouched); no rename/reorder/deletion/string/exit-code/signature change; nested losetup sites (2207/2211) each re-capture before their own test.

### Verification (agent-safe) — all green

1. `bash -n` PASS; `bash pisafe -v` → `1.2.12.beta1`; `grep -c 'if (( $? ))'` → **0**.
2. **A/B battery `/tmp/opencode/r6_ab.sh` — 5/5 PASS** (pristine `f6cb58d` vs live): `env_which` hit+miss identical (sudo arm provably never fires), `file_size` hit-`-h` / hit-bytes / stat-fail identical. The 14 sudo/parted/losetup/udisksctl/whiptail/menu sites: proven by the equivalence argument + hunk read-through (not agent-runnable).
3. shellcheck (`-f gcc`): **62 → 44 findings, 11 → 10 codes**; site-diff = exactly the 18 SC2181 lines removed, everything else line-shifted only; **0 new, 0 unrelated removals**.
4. SC2086 keep-list: **17/17** at 129, 971, 1868, 1988, 2078, 2480, 2482, 2486, 2488, 2490, 2501, 2503×3, 2907, 2916, 2936.
5. File 2918 → **2936 lines** (+18 exactly). `git diff --stat`: **36 ins / 18 del** — 18 hunks, each = one `ES=$?` + one `if` rewrite; full read-through clean.

### Residual classes (all classified leave/RISKY-decided)

* SC2086×17 keep-list (campaign policy: never quote — flag/list/eval/`for-in` RHS semantics)
* SC2034×15 (mostly dynamic-scope false positives; deletion = RISKY)
* SC2207×1 (menu `""${options[@]}""` idiom — R2-regression-fix territory), SC2215×2 (dead `notes_desktop_environment` — user: leave), SC2068×1 + SC2027×2 (one FP) same `""…""` idiom, SC2059×1 `printf $FILES`, SC2048×1, SC1001×1 (intentional), SC2021×3 `[[:digit:]]` FPs
* **`media_name` dead error check** (pre-existing; logic change — user decides)

### Commit

Committed on `dev` as **`87b6a38`** (staged: `pisafe`, `REVIEW_ROUNDS.md`, `REVIEW_ROUND_6.md`). No push, no tag, no version bump.

---

## Round 7 — decision round: dead variables (SC2034×15) + 2 flagged idioms

**Status: COMMITTED — `8c42bd2` on `dev` (2026-09-25).**
Per-item user approval 2026-09-25: B1 approve · B2 **defer to release** · B3 approve · B4 approve · B5 approve · B6 leave + document. Prompt: `REVIEW_ROUND_7.md`.
Baseline: `87b6a38` (R6), 2936 lines, **44 findings / 10 codes**, `1.2.12.beta1`.

### Changes applied (19 line deletions + 2 line rewrites; every item RISKY per campaign rules, all evidence-backed)

* **B1 — 13 dead variables/locals deleted** (zero reads file-wide; no `export` anywhere in the file; no caller passes the affected positional args): `CURRENT_DIR` (22), `OPTIONAL_TOOLS` (28), `BLUE` (41), `run_command` `QUIET` (126), `SETTINGS_SCRIPT_VER` (506), `VERIFY` (515), `SAFETY` (528), `env_root_device` `ROOT_PARTITION`+`ROOT_DRIVE` (557/558), `get_bytes` `p_eta` (814), `MEDIA_PARTITION_LIST` (1504), `ui_yesno` `TIMEOUT` (1972), `media_partition_info` `READONLY` (2207). (pre-R7 line numbers)
* **B3 — dead `EXT` store block in `menu_get_outfile` deleted** (3 writes, 0 reads file-wide; the real extension handling is the final `file_ext` check + append) — 6 lines.
* **B4 — `printf $FILES | column -t` → `printf '%b' "$FILES" | column -t`** (L971). **Fixed a real bug**: the data string was the printf *format*, so any `%` or `\` in a filename was interpreted as a conversion — A/B fixture `gamma 50%.xz` rendered as `gamma_50z` under the old code; new code renders it cleanly and is byte-identical for sane filenames.
* **B5 — `get_args $*` → `get_args "$@"`** (L2916) — strictly safer positional-arg forwarding (no re-split of space-containing args).
* **B2 — DEFERRED TO RELEASE**: L3 `COPYRIGHT="By Richard Reed 2018 - 2022"` kept; delete/rehome + date is a release-time decision (text preserved in `REVIEW_ROUND_7.md`).
* **B6 — left as-is, documented**: `media_name` dead error check — return code is swallowed at **all 5 call sites** (each embedded in a `$(…)` string), so a `PIPESTATUS[0]` fix would change no user-visible behavior; the real fix (empty-output check + callers surfacing the error) is feature work beyond the campaign.

### Verification (agent-safe) — all green

1. `bash -n` **PASS**; `bash pisafe -v` → `1.2.12.beta1`; file 2936 → **2917 lines** (−19).
2. **A/B battery `/tmp/opencode/r7_ab.sh` — ALL PASS** (pristine `87b6a38` `/tmp/opencode/pisafe_preR7.txt` vs live): `get_bytes` lens 1–18 + suffix/invalid/empty arms byte-identical; `file_list_image_files` clean-dir byte-identical + **% fixture documents the B4 bug fix (live rc 0)**; `run_command` ok/fail/compound/3-arg identical; `ui_yesno` y/n/stray-then-y/4th-arg identical; `env_root_device` real read-only `findmnt`/`lsblk` identical; `get_args` `$*` vs `"$@"` identical globals incl. space-token; `config_var_get_settings` shared globals identical.
3. shellcheck (`-f gcc`): **44 → 26 findings, 10 → 8 codes**; site-diff = exactly **18 removed** (SC2034×14, SC2059×1, SC2048×1, SC2086×2) and **0 added, 0 unrelated**. Note: the two B4/B5 lines carried a double SC2086 flag, so SC2086 went 17 → 15.
4. SC2086 keep-list: **15/15** at 125, 1857, 1976, 2066, 2467, 2469, 2473, 2475, 2477, 2488, 2490×3, 2888, 2917.
5. `git diff --stat`: **2 ins / 21 del** — 19 pure deletions + 2 line rewrites (B4/B5); full read-through clean, nothing else touched.

### Residual classes (all classified leave/RISKY-decided, unchanged)

* SC2086×15 keep-list (campaign policy: never quote — flag/list/eval/`for-in`/menu semantics)
* **SC2034×1 = L3 `COPYRIGHT` — deferred to release round (user decision B2)**
* SC2021×3 `[[:digit:]]` FPs, SC2027×2 (1 FP, L2013 nested-quote), SC2215×2 (dead `notes_desktop_environment` — user: leave), SC2207×1 + SC2068×1 (menu `""${options[@]}""` idiom, R2-regression territory), SC1001×1 (intentional `$DEVICE\1`)

### New backlog items (from the R7 audit)

* `media_partition_info` builds `ROOTREADONLY` **without `local`** → leaks into the global namespace (hygiene; user decides) — `pisafe` ~2224. **→ resolved in R8 (R8.1).**
* `media_name` known-limitation noted (B6 above).
* R7's B4 documents+fixes the `%`-filename mangling in `file_list_image_files` (was silent in v≤1.2.12.beta1).

### Commit

**`8c42bd2`** on `dev` (2026-09-25, user-approved): `review R7: delete dead vars/locals (SC2034×14), printf %b, get_args "$@" (44→26 findings)` (staged: `pisafe`, `REVIEW_ROUNDS.md`, `REVIEW_ROUND_7.md`; untracked user files excluded). **No push, no tag, no version bump.**

---

## Round 8 — final decision round: `local ROOTREADONLY` + stale open-item correction (prompt: `REVIEW_ROUND_8.md`)

**Status: COMMITTED — `c4aca2b` on `dev` (2026-09-25).**
User approval 2026-09-25: R8.1 approve · R8.2 approve (docs only).
Baseline: `8c42bd2` (R7), 2917 lines, **26 findings / 8 codes**, `1.2.12.beta1`.

### Changes applied (1 line added; R8.1 is RISKY class — "adding `local`" — user-approved)

* **R8.1 — `local ROOTREADONLY=` added to `media_partition_info`** (L2197). The var is conditionally set (only when `$MOUNTDIR/etc/fstab` exists) and read by the final `echo`, but was the function's one un-`local`ed variable. Consequences: (a) global leak; (b) **cross-call contamination** — a first call on a read-only `/boot` Linux image leaves `ROOTREADONLY="(READONLY)"` in the global namespace, so a second call on a Windows image (no `fstab` → branch skipped) wrongly reports it as read-only. The A/B harness **reproduces the leak on pre** (call B: `'Windows'(READONLY)`) and **proves live clean** (`'Windows'`), with first-call behavior byte-identical. Nothing else in the file reads it (grep-proven; all 4 references inside the function).
* **R8.2 — docs**: the open-item "`tr -cd '[[kmgtbKMGTB]]' suffix-set quirk" was **stale/mis-diagnosed** — the kmgtb set was **already fixed in R3** (R3.1); the remaining SC2021×3 are shellcheck FPs on the correct `[[:digit:]]` POSIX class. Open-item row closed.

### Verification (agent-safe) — all green

1. `bash -n` **PASS**; `bash pisafe -v` → `1.2.12.beta1`; 2917 → **2918 lines** (+1).
2. **A/B harness `/tmp/opencode/r8_ab.sh` — ALL PASS** (pristine `8c42bd2` `/tmp/opencode/pisafe_preR8.txt` vs live; function exercised in the same shell with `sudo`/`mktemp`/`file` stubbed and fixture fs trees):
   * first-call sequences (ro-fstab Linux image; Windows image) → pre/live **byte-identical**;
   * contamination sequence (call A then call B, same shell) → **pre: `B:['Windows'(READONLY)]` (bug reproduced); live: `B:['Windows']` (fixed)**; call A output identical in both versions.
3. shellcheck (`-f gcc`): **26 findings / 8 codes — unchanged**; site-list diff = exactly the one-line downward shift from the insertion, **0 added / 0 removed**.
4. SC2086 keep-list: **15/15** at 125, 1857, 1976, 2066, 2468, 2470, 2474, 2476, 2478, 2489, 2491×3, 2889, 2918 (post-R8 line numbers).
5. `git diff`: **1 ins / 0 del** — exactly `+    local ROOTREADONLY=` in the `media_partition_info` local block; nothing else touched.

### Commit

Pending user approval. Candidate message: `review R8: local ROOTREADONLY (fix cross-call (READONLY) bleed in media_partition_info)` (staged: `pisafe`, `REVIEW_ROUNDS.md`, `REVIEW_ROUND_8.md`; untracked user files excluded). **No push, no tag, no version bump.**

---

## Round 9 — verification round: pv/compression syntax (user item #3) + global-leak audit + 2 small fixes (prompt: `REVIEW_ROUND_9.md`)

**Status: COMMITTED — `3119819` on `dev` (2026-09-25, user commit).**
User decision 2026-09-25: R9.0 docs ✓ · R9.1 (L1659 log `-p`→`-d`) ✓ · R9.1b (user's own menu_cli SAFE quotes) ✓ · R9.2 (raw-img restore `-s`) **deferred**.
Baseline: `c4aca2b` (R8), 2918 lines, **26 findings / 8 codes**, `1.2.12.beta1`.

### Verification verdicts (see `REVIEW_ROUND_9.md` for full detail) — **user item #3 CLOSED**

* **`xz -z` on the compress path (L1199) is CORRECT** — `xz --help`: `-z, --compress`; refuted earlier suspicion of decompress; proven empirically (xz 5.8.1, 2 MB sample: rc 0, `xz -t` valid, byte-identical roundtrip). **Not changed.**
* All compress arms verified (zip `… -` stdin ✓; xz ✓; pigz ✓; zstd `--rm` output lands at `$OUTFILE` **by virtue of** the enforced `.img.<EXT>` naming convention via `file_base`/`check_outfile` — consistent today, fragility **noted**); all restore decompress arms verified (`unzip -p`, `xz -d -c`, `pigz -d -k -c`, `zstd -d -c`); all `pv` usages syntactically valid (`-s`, `-n`).
* **R9.1 applied**: L1659 restore log message said `pigz -p -k -c` but the command runs `pigz -d -k -c` → message now matches. (User-visible string — RISKY class, user-approved.)
* **R9.2 noted, deferred**: raw img/iso restore (L1618/L1622) is the only restore path without `-s $RESTORE_BYTES` (no % denominator) — user-visible progress behavior change, on hold.

### R9.1b — user-authored SAFE quotes (approved into R9)

`menu_cli` case arms: `backup`/`restore` `$4`, `install`/`update`/`uninstall`/`details` `$2`, `erase|format` `$3 $4` → all single-token expansions quoted. Resolves exactly the 9 SC2086 keep-list sites of that cluster. A/B dispatch test (`/tmp/opencode/r9_ab.sh`, stubs) **ALL PASS** — 6 arms incl. 3-arg calls byte-identical pre/live.

### Global-leak audit (ROOTREADONLY class, R7/R8 follow-up) — **CLOSED, no further bugs**

Systematic scan of every function for "read while only conditionally written + never `local`": every flagged name triaged — others are unconditionally set-before-read, early-return before read (`file_image_size`), have covered case/if-else arms (`ROOT_FILTER`, `MEDIA_LAST_PARTITION_TYPE`, `PI_SHRINK_OPTS`, `START_OF_FREESPACE`, `TIME3`), or are intentional cross-step globals. **`media_partition_info` (R8) was the one real instance.** Hygiene residual: per-item fns still use bare globals provably set-before-read (`SIZE_BYTES`, `OS`, `PARTED_OUTPUT`, `MEDIA_PARTITIONS`, `FILE_NS`, …) — behavior-safe; **recommend no churn locals round** (logged as backlog).

### Measured

* `bash -n` PASS; `-v` → `1.2.12.beta1`; 2918 lines (unchanged).
* shellcheck (`-f gcc`): **26 → 17 findings, 8 codes (SC2086 15 → 6)**; site-diff = exactly the 9 menu_cli sites removed, 0 added.
* SC2086 keep-list now **6**: 125, 1857, 1976, 2066, 2889, 2918.
* `git diff --stat`: **8 ins / 8 del** (L1659 + 7 menu_cli arms); nothing else touched.

### Commit

✅ Committed on `dev` as **`3119819`** (2026-09-25, user commit): `review R9: verify pv/tool syntax (item #3 closure), fix pigz log -p→-d, quote menu_cli args (26→17 findings)` (staged: `pisafe`, `REVIEW_ROUNDS.md`, `REVIEW_ROUND_9.md`; untracked user files excluded). **No push, no tag, no version bump.**

---

## Round 10 — full shellcheck processing: 17 findings → **0** + beta lock-in (prompt: `REVIEW_ROUND_10.md`)

**Status: ✅ COMMITTED on `dev` (2026-09-25, user-approved; history option 1 — soft-reset to `3119819`, single clean R10 commit).**
User approval 2026-09-25: **Full A+B+lint (recommended)**; **A2+A3 approved as drafted**; `notes_performance` (also dead raw-text, not flagged) left as-is per user.
Baseline: `3119819` (R9), 2918 lines, **17 findings / 8 codes**, `1.2.12.beta1`.

### All 17 findings dispositioned (per-item equivalence proofs in `REVIEW_ROUND_10.md`)

**Group B — behavior-preserving, equivalence-proven (SAFE):**

| # | Site | Code | Change |
|---|---|---|---|
| B1 | `run_command` L125 | SC2086 | `eval $CMD` → `eval "$CMD"` (A/B + all 34 call sites scanned; sole theoretical edge — double space inside a *quoted* CMD region — proven absent) |
| B2–B4 | L777 / L897 / L901 | SC2021 | `tr -cd '[[:digit:]]'` → `tr -cd '0123456789'` (×3; output A/B-identical for all test inputs) |
| B5 | `media_format` `NAME` | SC2027 | `(" "$DEVICE")"` nested-quote unquoting → `($DEVICE)` — identical string for any single-token device |
| B6 | `media_mount` | SC2086 | `sudo umount $DEVICE?` → `sudo umount "$DEVICE"?` — legacy `?`-glob kept (`sda1`–`sda9` unmount, `sda10` not); A/B with matched/unmatched CWD fixtures |
| B7 | `media_format` | SC1001 | `PARTITION=$DEVICE\1` → `PARTITION="${DEVICE}1"` |
| B8 | dispatch | SC2086 | `pisafe_uninstall $2` → `pisafe_uninstall "$2"` (receiver's `${1:--n}` makes missing≡empty) |
| B9 | `menu_cli` final line | SC2086 | `menu_cli $1 …` → `menu_cli "$1" …` (empty matches the same `*` case) |

**Group A — RISKY, user-approved per item (dead-code removals + rewrites):**

| # | Site | Codes | Change |
|---|---|---|---|
| A1 | L3 | SC2034 | dead `COPYRIGHT=` var → header comment `# By Richard Reed 2018 - 2022` (notice preserved verbatim; was the var's only content) |
| A2 | L47–92 | SC2215×2 | `notes_desktop_environment` (zero call sites) → fully commented reference block, header `— DEAD FUNCTION (zero call sites); body kept as reference documentation:` |
| A3 | `media_power_off` L1855–1860 | SC2086 (in its body) | **deleted** — zero call sites *and* its `umount $MEDIA?` was broken (relative-path glob); −6 lines |
| A4 | `ui_yesno` | SC2086 | `$DEFAULT` → `YT_FLAGS=()` + `[[ -n "$DEFAULT" ]] && YT_FLAGS+=("$DEFAULT")` → `whiptail … "${YT_FLAGS[@]}" --yesno …` (empty → zero words; `--defaultno` → exactly one word; no `set -u` in file) |
| A5 | `menu_select_device` | SC2207 | `options=($(…))` → `mapfile -t options < <(…)` (line-based; the `ES=$?` guard is now inert by design — the empty case is still caught by the `arraylength = 0` check, A/B-verified N=0 → rc=1 both) |
| A6 | `menu_select_device` | SC2068 + SC2027 | 3 continuation lines joined to 1; `""${options[@]}""` → `${options[@]}` + rationale comments + bare `# shellcheck disable=SC2068` directly above |

**A6 mechanism (the one that mattered):** the `IFS=$FIELD_SEPERATOR` (`|`) set immediately before the call plus the *unquoted* `@` split each `name ⎮ desc` option into exactly the `[tag item]` word pair whiptail's menu needs (tag = `sda␣` — the trailing space the function's own strip comment documents). The old `""…""` contexts contributed zero words, so removal is a byte-identical argv change (A/B: stub argv vectors equal, N=0…3). Quoting would pass each whole line as one tag and break the menu — hence the sanctioned, one-off, documented directive.

**Lock-in:** new `lint.sh` at repo root (approved, `chmod +x`) — the shellcheck gate: pass iff `shellcheck -s bash -f gcc pisafe` returns **0 findings**; else print findings and exit 1. One directive in the tree = the lock.

### Verification (agent-safe, stubs only — battery green)

1. A/B harness `/tmp/opencode/r10_ab.sh` (true pre baseline `git show 3119819:pisafe` vs live; whiptail/media_list/ui_echo stubbed): **23/23 PASS** — covers tr (B2–B4), `run_command` eval (B1), `ui_yesno` argv both DEFAULT states (A4), `menu_select_device` N∈{0,1,2,3} incl. `declare -p options` + whiptail argv pairs (A5+A6), umount-`?` glob both worlds (B6), PARTITION/SILENT/menu_cli/NAME equivalence (B7/B8/B9/B5).
2. Final battery: `bash -n` PASS · `bash pisafe -v` → `1.2.12.beta1`, **no stderr noise** · `shellcheck -s bash -f gcc pisafe` → **0 findings** · `./lint.sh` → `shellcheck: CLEAN (0 findings)` rc=0 · file **2913 lines** (2918 − A2×2, − A3×6, + A4×2, + A6×1, rest line-neutral).
3. `git diff` of the uncommitted remainder maps exactly to A2-fix + A4 + A5 + A6; nothing else touched.

### ⚠ Two incidents, caught and fixed this round (full record in `REVIEW_ROUND_10.md`)

1. **First-pass A2 was broken and briefly landed in `45870c1`.** The comment-out sed (`s/^\(\S\)/# \1/`) only matched **column-0** lines, so only the signature and `}` got `#`-prefixed; the 45-line indented OS table became **top-level executable code** — a `bash pisafe -v` smoke test exposed ~30 `command not found` lines and one real `arch -S` execution. Fixed same round: indented body commented, stray `# }` deleted, `bash pisafe -v` verified clean before continuing.
2. **shellcheck 0.10 directive format.** Free-form text on the directive line is rejected (inline `IFS="|"` produced SC1125; earlier inline prose silently failed to suppress). Final form = rationale in plain comment lines, bare `# shellcheck disable=SC2068` immediately above the command.

### Commit — history note (race with user commit)

Timeline: user committed R9 as `3119819` (17:08:19, clean — exactly R9's content). My commit `45870c1` (17:10:52, **R9's message but R10's content**: A1, A3, B1–B9, and a partially-applied A2) landed immediately after, so the R10 baseline is now `45870c1`; the remaining R10 work (A2-fix, A4–A6, `lint.sh`, this documentation) is in the working tree, uncommitted.

**Decision (user, 2026-09-25): option 1 — adopted.**
1. ✅ **(clean history — ADOPTED)** `git reset --soft 3119819` → one commit `review R10: zero shellcheck findings (17→0): quotes/rewrites, dead-code comment-out/removal, ui_yesno args array, mapfile menu (beta lock-in)` — the broken A2 intermediate never enters history; `45870c1` becomes an unreferenced (dangling) object.
2. (append) commit the working tree on top as R10 — would have left `45870c1` (R9 message, R10 content) in history. Not used.

Staged either way: `pisafe`, `REVIEW_ROUNDS.md`, `REVIEW_ROUND_10.md`, `lint.sh`. **No push, no tag, no version bump.**

### Beta lock-in (user directive) — **IN EFFECT since R10 commit**

**Code changes are frozen** until `things to fix.md` is explicitly re-scoped into post-beta feature rounds. Version stays `1.2.12.beta1` (bump + tag remain a separate explicit release action). The `lint.sh` gate + the zero-finding baseline + the single documented `SC2068` directive are the regression re-ignition lock.

---

| Item | Location | Round |
|---|---|---|
| ~~**pv/compression syntax confirmation** (user `things to fix.md` item #3)~~ — **closed in R9**: all compress/restore arms verified correct (incl. `xz -z` = `--compress`, refuted suspicion); L1659 log typo `-p`→`-d` fixed; residual R9.2 (raw-img restore `-s`) deferred below | `pisafe` L1110–1674 | ✅ R9 |
| **Raw img/iso restore missing `-s "$RESTORE_BYTES"`** (only restore arm without a size denominator; L1618 cli + L1622 tui) | `pisafe` L1618, L1622 | **R9 deferred** (RISKY display change — user's call) |
| **zst compress arm naming fragility** — `zstd IMG --rm` writes `IMG.zst` = `$OUTFILE` **only because** `check_outfile` enforces the `.img.<EXT>` convention; a convention change would silently break it (verified working today — no action requested) | `pisafe` L1225 | R9 (noted) |
| ~~`get_ver_to_int` (no locals, global `parts`, `let`)~~ — **closed in R4** (locals added; `let`→`(( ))`; **pre-existing dotted-version bug fixed** via `IFS='.' read -r -a parts <<< "$1"` — "UPDATE AVAILABLE" check now functional; A/B-proven) | `pisafe` ~710 | ✅ R4 |
| **`media_name` dead error check** — `lsblk | sed` pipeline swallows lsblk failure; `ES=$?`/`if (( ES ))` can never fire; bad device → silent ` -  ()`. **R7: left as-is + documented** — return code is swallowed at all 5 call sites (embedded in `$(…)` strings), so an idiom fix changes no visible behavior; real fix (empty-output check + caller surfacing) = feature work | `pisafe` ~1024 | R7 (user: leave) |
| ~~**`ROOTREADONLY` not `local` in `media_partition_info`**~~ — **closed in R8** (R8.1: `local ROOTREADONLY=`; fixes the cross-call `(READONLY)` contamination the stale-value path caused — A/B reproduced on pre, live proven clean; sibling vars were already local) | `pisafe` ~2197 (post-R8) | ✅ R8 |
| ~~`echo $INPUT` unquoted~~ — **closed in R2** (class 3: `printf '%s\n' "$INPUT"`) | (was ~1237) | ✅ R2 |
| ~~`cd $DIR` unquoted~~ — **closed in R2** (class 1: `cd "$DIR"`) | (was ~952) | ✅ R2 |
| ~~`FILES+=($FILE)` unquoted~~ — **closed in R2** (class 5: `FILES+=("$FILE")`) | (was 2350) | ✅ R2 |
| ~~`sudo $INSTALL …` unquoted~~ — **closed in R2** (class 1: all bare `sudo "$INSTALL" …` arms quoted) | `pisafe` 278/298/2080–2115 | ✅ R2 |
| ~~`echo $DEVICE_SELECTED` trailing-space regression~~ (menu tag `sda␣`; R2 quoting unmasked latent ` | ` separator quirk; broke all 4 TUI device pickers in 1.2.12.beta1) — **closed** (Fix C: `DEVICE_SELECTED="${DEVICE_SELECTED% }"` before the quoted `echo`; see Round 2 regression section) | `pisafe` ~2643 | ✅ R2-regression-fix |
| Stale `test_pisafe` harness | `test_pisafe` | later, user decides |
| ~~Cosmetic double-space sites (`else  #`, `[[ … = primary  ]]`)~~ — **closed in R4** (R4.3) | `pisafe` 838, 1537 | ✅ R4 |
| Backup-estimate `ui_echo` clobber + stdout pollution (pre-existing; fat32 box shows literal ANSI + fused lines) | `pisafe` L1546, L1872–1873, L2163, L2512 | **applied during R1 functional testing** (commit `e174ebe`) |
| ~~**Dead function `notes_desktop_environment` (L50–95) — never called; body is an unquoted table that would run `arch` etc. as commands if invoked**~~ — **closed in R10** (A2, user-approved: fully commented reference block with `— DEAD FUNCTION (zero call sites)` header; SC2215×2 gone; `notes_performance` sibling left as-is per user) | `pisafe` L47–92 pre-R10 | ✅ R10 |
| **Dead function `media_power_off` — zero call sites AND broken umount (`umount $MEDIA?`, relative path)** | `pisafe` L1855–1860 pre-R10 | **closed in R10** (A3: deleted, −6 lines) |
| ~~`tr -cd '[[kmgtbKMGTB]]'` suffix-set quirk~~ — **closed in R8 as stale/mis-diagnosed**: the kmgtb set was **already fixed in R3** (R3.1 → `tr -cd 'kmgtbKMGTB'`); the remaining SC2021×3 are shellcheck FPs on the correct `[[:digit:]]` POSIX-class form (L777, L897, L901) and stay on the file as known FPs | `pisafe` L779 (cf. L777, L897, L901) | ✅ R3 (fix) / R8 (row closed) |
| ~~**102 residual shellcheck findings / 19 codes**~~ → ~~**91 findings / 16 codes**~~ → ~~**77 findings / 14 codes**~~ → ~~**62 findings / 11 codes**~~ → ~~**44 findings / 10 codes**~~ → ~~**26 findings / 8 codes**~~ → **17 findings / 8 codes** (SC2086×6 keep-list at 125, 1857, 1976, 2066, 2889, 2918; SC2034×1 = L3 `COPYRIGHT` deferred to release; SC2021×3 (FPs); SC2027×2 (1 FP); SC2215×2 (dead fn); SC2207×1 (menu idiom); SC2068×1; SC1001×1) — SC2125×4 **closed post-R2**; SC2053×2, SC2164×2, SC2021×1, SC2143×2 **closed in R3**; **SC2155×13, SC2219×1 closed in R4**; **SC2005×9, SC2002×5, SC2143×1 (incl. L1515) closed in R5**; **SC2181×18 closed in R6**; **SC2034×14 + SC2059×1 + SC2048×1 + SC2086×2 closed in R7**; **SC2086×9 (menu_cli cluster) closed in R9** (user SAFE quotes) → ~~**17 findings / 8 codes**~~ → **0 findings (R10 — all 17 processed: 9 SAFE rewrites + 8 user-approved dead-code/removal/rewrite items)** — the SC2086 keep-list is retired (every one of its 15 then-6 sites closed in R7/R9/R10; `media_power_off` deleted in R10); the single remaining sanctioned directive in the file is `# shellcheck disable=SC2068` on the `menu_select_device` whiptail line (documented; the only place unquoted `@` is semantically required); locked in by the new `lint.sh` gate | `pisafe` (full breakdown in Round 2 / 3 / 4 / 5 / 6 / 7 / 9 / 10 sections) | ✅ R10 — **0 findings** |
| Copyright notice `2018 - 2022` (was the L3 dead `COPYRIGHT` var — the only place the notice lives) | `pisafe`:3 | **R10 (code side)**: dead var → header comment `# By Richard Reed 2018 - 2022`, notice preserved verbatim, SC2034 closed. **Remaining at release**: update the date range (release-time decision, separate explicit user action) |
