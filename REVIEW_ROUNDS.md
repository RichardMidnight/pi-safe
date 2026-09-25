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

## Open items across rounds

| Item | Location | Round |
|---|---|---|
| `get_ver_to_int` (R2 quoted `parts=("$1")`; **no locals, global `parts`, `let` remain**) | `pisafe` ~710 | R3+ |
| ~~`echo $INPUT` unquoted~~ — **closed in R2** (class 3: `printf '%s\n' "$INPUT"`) | (was ~1237) | ✅ R2 |
| ~~`cd $DIR` unquoted~~ — **closed in R2** (class 1: `cd "$DIR"`) | (was ~952) | ✅ R2 |
| ~~`FILES+=($FILE)` unquoted~~ — **closed in R2** (class 5: `FILES+=("$FILE")`) | (was 2350) | ✅ R2 |
| ~~`sudo $INSTALL …` unquoted~~ — **closed in R2** (class 1: all bare `sudo "$INSTALL" …` arms quoted) | `pisafe` 278/298/2080–2115 | ✅ R2 |
| ~~`echo $DEVICE_SELECTED` trailing-space regression~~ (menu tag `sda␣`; R2 quoting unmasked latent ` | ` separator quirk; broke all 4 TUI device pickers in 1.2.12.beta1) — **closed** (Fix C: `DEVICE_SELECTED="${DEVICE_SELECTED% }"` before the quoted `echo`; see Round 2 regression section) | `pisafe` ~2643 | ✅ R2-regression-fix |
| Stale `test_pisafe` harness | `test_pisafe` | later, user decides |
| Cosmetic double-space sites (`else  #`, `[[ … = primary  ]]`) | `pisafe` 838, 1536 | R2+ |
| Backup-estimate `ui_echo` clobber + stdout pollution (pre-existing; fat32 box shows literal ANSI + fused lines) | `pisafe` L1546, L1872–1873, L2163, L2512 | **applied during R1 functional testing** (commit `e174ebe`) |
| **Dead function `notes_desktop_environment` (L50–95) — never called; body is an unquoted table that would run `arch` etc. as commands if invoked** | `pisafe` L50–95 | R2+ (user: leave for now) |
| `tr -cd '[[kmgtbKMGTB]]'` suffix-set quirk (tr `[[` = literal-`[` escape) | `pisafe` L782 (cf. 899, 903) | R2+ (needs care + test) |
| **102 residual shellcheck findings / 19 codes** (SC2181×18, SC2086×17 keep-list, SC2034×15, SC2155×13, SC2005×9, SC2002×5, SC2021×4 tr-`[[`, SC2125×4 bc-strings, SC2143×3, SC2053×2 `[[=]]` glob-RHS, SC2027×2 (1 FP @1992), SC2164×2, SC2215×2, + 6 singletons) — all RISKY/intentional/backlog | `pisafe` (full breakdown in Round 2 section) | R3+ per-item if user wants |
| Copyright header `2018 - 2022` | `pisafe`:3 | release round |
