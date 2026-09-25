# Review Round 10 — full shellcheck processing: 17 residual findings → **0**, then lock down as a no-new-features beta

**Baseline:** `dev` at R9 (commit `3119819`, `review R9: …`), 2918 lines, **17 findings / 8 codes**, `1.2.12.beta1`.
**Goal (user directive 2026-09-25):** fully process *all* shellcheck issues and lock the code down as a no-new-features beta before moving to `things to fix.md`.

**Policy applied per campaign rules:** each item is either (a) fixed behavior-preserving with an equivalence proof + A/B, or (b) removed/commented with user approval (RISKY), or (c) explicitly kept with a documented `# shellcheck disable=` **only** where unquoted expansion is *semantically required* (whiptail argv). That third form is what actually *locks* it down: any future regression re-ignites a finding.

**Environment note:** bash 5.2.37 (mapfile available); the script uses **no** `set -u/-e/-o` flags, so empty-array expansion `"${arr[@]}"` = zero words — safe.

## Inventory — all 17 findings, each with a disposition

### Group B — behavior-preserving quotes/rewrites (SAFE-class, equivalence-proven)

| # | Site (pre-R10 line) | Code | Current | Change | Equivalence proof |
|---|---|---|---|---|---|
| B1 | L125 (run_command) | SC2086 | `eval $CMD` | `eval "$CMD"` | `eval` joins its args then re-parses. A/B (old vs new form, direct): **identical** for plain strings, unquoted double-spaces (both collapse), and parted/dd call shapes. One theoretical edge differs: a double space *inside a quoted region* of the CMD string (`echo "a  b"`). Grep of all **34** `run_command "…"` call sites: **zero** contain double spaces → provably equivalent for every call in this file |
| B2 | L777 (get_bytes) | SC2021 | `tr -cd '[[:digit:]]'` | `tr -cd '0123456789'` | identical 10-character set, same `-cd` action |
| B3 | L897 (file_fs_freespace) | SC2021 | same | same | same |
| B4 | L901 (file_fs_freespace) | SC2021 | same | same | same |
| B5 | L2001 (media_format) | SC2027 | `NAME="$(lsblk … ) ("$DEVICE")"` — nested quotes *unquote* `$DEVICE` (that is the trap) | `NAME="$(lsblk … ) ($DEVICE)"` | current result is already `<lsblk-out> (sda)` (unquoted single-token expansion); the rewrite produces the **same** string with clean quoting. `lsblk` output is unchanged |
| B6 | L2066 (media_format) | SC2086 | `sudo umount $DEVICE? 2>/dev/null` — trailing `?` is a **legacy glob**: unmounts `/dev/sda1`–`sda9` (single-char partitions); the line *before* (L2065) unmounts the disk itself | `sudo umount "$DEVICE"? 2>/dev/null` | quoting only the `$DEVICE` token changes nothing: the `?` still globs exactly as before (non-matching → literal passed to umount → silent fail, same as today). Kills SC2086, zero behavior delta |
| B7 | L2081 (media_format) | SC1001 | `PARTITION=$DEVICE\1` — `\1` = literal `1` (append partition "1"): **intended** | `PARTITION="${DEVICE}1"` | same single-token result for any device path; no backslash magic left |
| B8 | L2889 (CLI dispatch) | SC2086 | `pisafe_uninstall $2` | `pisafe_uninstall "$2"` | `pisafe_uninstall` reads `SILENT=${1:-"-n"}` — `:-` falls back on *empty* too, so empty-arg and missing-arg both yield `SILENT=-n`; non-empty arg passes identically |
| B9 | L2918 (tail dispatch) | SC2086 | `menu_cli $1 "$2" "$3" "$YESNO"` | `menu_cli "$1" "$2" "$3" "$YESNO"` | `$1` is the command word (single token); empty `$1` matches the same `*` case pattern whether absent or `""` |

### Group A — RISKY-class (user approves each; all have A/B tests)

| # | Site | Code | Disposition (proposed) | Rationale |
|---|---|---|---|---|
| A1 | L3 | SC2034 | Move the notice to the file header as a **comment** — `# By Richard Reed 2018 - 2022` — and delete the dead `COPYRIGHT` variable | The variable is unread anywhere (shellcheck agrees); the notice currently lives *only* there, so it is preserved as a comment, not lost. Exact date text kept (date update remains a release-time decision). Line-count neutral (in-place swap) |
| A2 | L47–93 | SC2215×2 | Convert `notes_desktop_environment()` — dead (zero call sites, verified by grep) — to a **comment block**, keeping the 2021 OS/terminal reference table as documentation | If called, the table would execute as *commands* (that is what tripped SC2215 on `--- ARM ---`); comment-out removes the code, preserves the reference data, and kills both findings |
| A3 | L1855–1859 | SC2086 (L1857) | **Delete** `media_power_off()` — dead (zero call sites) **and broken**: its only umount is `umount $MEDIA?` (the same legacy-glob typo class) and `udisksctl power-off` never ran either | No behavior is ever executing; the latent bug dies with the function. (If the power-off intent matters later, it gets re-built properly as a feature — out of beta scope) |
| A4 | L1969 (ui_yesno) | SC2086 | Conditional-argument array: `YT_FLAGS=(); [[ -n "$DEFAULT" ]] && YT_FLAGS+=("$DEFAULT")` then `whiptail … "${YT_FLAGS[@]}" --yesno …` (no `local` — matches the function's existing global style; no `set -u`, so empty array = zero words) | `$DEFAULT` is `""` (default Yes) or `--defaultno`; unquoted empties *must* drop from the command line and a non-empty value must be exactly one word — the array gives both, provably. A/B with a whiptail stub printing argv: `DEFAULT=""` → zero words (identical to today); `--defaultno` → one word (identical to today) |
| A5 | L2628 (menu_select_device) | SC2207 | `mapfile -t options < <(media_list "$2" \| sed 's/ / '"'"$FIELD_SEPERATOR"'"' /')` | mapfile is exactly the split SC2207 asks for; line-based, so identical elements to the IFS-newline `$(…)` today (spaces in a line survived the sed anyway — each line is one element either way). **Checked edge:** `ES=$?` after the line currently captures the pipeline status; with process substitution it is always 0 — but all 4 call sites (`L1429/1743/2829/2840`) test **truthiness only** (`if (( ES ))`), and the empty-list case is caught by the existing `arraylength = 0` guard → equivalent. bash 5.2 ✓ |
| A6 | L2635 (menu_select_device) | SC2068 + SC2027 | `""${options[@]}""` → `${options[@]}` + rationale comments + a clean directive line directly above the call: `# shellcheck disable=SC2068` | **Mechanism (verified A/B, N=0…3):** `IFS=$FIELD_SEPERATOR` (`|`) is set immediately before the call, and the *unquoted* `@` then splits each `name \| desc` option into the `[tag item]` word pair the menu needs — tag = `sda ` (trailing space, exactly what this function's own "strip one trailing space" comment documents). The `""`-context strings attach as empty and contribute no words, so removing them is a byte-identical argv change (whiptail stub argv vectors equal for N=0,1,2,3; N=0 → rc=1 in both). Quoting `"${options[@]}"` would pass each full line as one tag and *break the menu* — so the directive (with rationale) is the honest lock. **Directive-format note:** shellcheck 0.10 *rejects* free-form text on the directive line itself (inline `IFS="|"` triggered SC1125; earlier inline prose silently failed to suppress) — hence the rationale lives in plain comment lines directly above the bare `# shellcheck disable=SC2068` |

**Observation (no finding) — user decision: leave as-is.** `notes_performance()` (L95+…) is the same dead raw-text-function pattern as A2 (never called) but its body never trips shellcheck; the user chose to leave it untouched.

## Result — locked-down baseline

* shellcheck on `pisafe`: **0 findings** (the only directive in the file: the SC2068 on the whiptail menu line, with rationale).
* New residual-arc line for the campaign log: `17 → 0`.
* Beta freeze: after this round no code changes until `things to fix.md` work is explicitly re-scoped as post-beta feature rounds.

## Lock-in machinery — **APPROVED (`Full A+B+lint`), created and executable**

* **`lint.sh`** (new file at repo root, `chmod +x`): runs `shellcheck -s bash -f gcc pisafe`. **Passes iff 0 findings**; otherwise prints the findings and exits 1. Success message: `shellcheck: CLEAN (0 findings)`.
* This converts the single sanctioned directive (SC2068 on the whiptail menu line) into a hard gate: any future regression that re-ignites *any* finding fails the lint.
* Currently: `./lint.sh` → `shellcheck: CLEAN (0 findings)`, exit 0 (measured).

## Verification — MEASURED results (agent-safe, stubs only, no devices, no TTY)

**Harness:** `/tmp/opencode/r10_ab.sh` — functions extracted from the true pre baseline (`git show 3119819:pisafe`; note: the *first* snapshot `/tmp/opencode/pisafe_preR10.txt` was taken after 45870c1 already contained B1, so the eval section was re-run against the true baseline separately) and the live file; whiptail/media_list/ui_echo stubs.

1. **S1 tr (B2–B4):** PASS×4 (digit/mixed/suffix/numeric inputs, old vs new form).
2. **S2 eval (B1):** PASS×5 (plain; unquoted double-space; parted shape; dd shape; `true`); 1 documented edge: double space *inside a quoted region* of CMD differs — proven absent at all **34** `run_command "…"` call sites.
3. **S3 ui_yesno (A4):** PASS×2 — whiptail argv vectors byte-identical for `DEFAULT=""` (zero words) and `--defaultno` (one word); out+rc equal; function diff shows only the two intended changes.
4. **S4 menu (A5+A6):** PASS×4, N ∈ {0,1,2,3} — options arrays (`declare -p`) identical element-for-element (incl. internal multi-space lines), whiptail stub argv identical (`sda ` / ` KINGSTON 64G` tag/item pairs — N=1; N=0 → rc=1, no whiptail call, both).
5. **S5 umount (B6):** PASS×2 — matching-glob CWD (sda1/sda2 expand identically, sda10 correctly unmatched) and non-matching CWD (literal passed, silent fail — same as today).
6. **S6–S9 (B5/B7/B8/B9):** PASS×6 — PARTITION append, SILENT default semantics for missing vs empty arg, menu_cli dispatch (set + empty word), NAME string identical.
7. `bash -n` PASS · `bash pisafe -v` → `1.2.12.beta1` clean (no stderr) · `shellcheck -f gcc pisafe` → **0 findings** · `lint.sh` → `shellcheck: CLEAN` exit 0.
8. Line count: 2918 → **2913** (A2 header-join −1, A2 stray-`#}` removal −1, A3 −6, A4 +2, A6 +1, rest line-neutral) — measured.

### ⚠ Incident (caught and fixed this round)

First A2 pass used `sed '47,93s/^\(\S\)/# \1/'` which only commented **column-0** lines (the signature + `}`) because every body line is 4-space-indented. Result committed in `45870c1`: the 45-line table became **top-level executable code** — `bash pisafe -v` printed ~30 `command not found` lines and `arch -S` actually executed. Caught immediately (battery `bash pisafe -v` + shellcheck SC2215 still present), fixed by commenting the indented body lines and removing the stray `# }` remnant; `bash pisafe -v` verified clean before proceeding. Lesson recorded: never trust a sed range/regex without a post-run `bash pisafe -v` smoke test.

## Deliverables

1. `pisafe` — all approved items applied.
2. `lint.sh` — **approved, created, executable, currently CLEAN** (gate: `shellcheck -s bash -f gcc pisafe`, pass iff 0 findings).
3. `REVIEW_ROUNDS.md` — R10 section (17→0 table, proofs, measured, beta-freeze note); open items: all 8 codes **closed**; `COPYRIGHT` release-row closed (moved to comment); SC2086 keep-list retired (0 sites); observation rows for `notes_performance` / power-off intent if left.
4. Chat report → **stop for user functional test + commit approval.**

## Commit — history note (race with user commit)

Timeline: user committed R9 as `3119819` (17:08:19, clean, exactly R9's 16 line-changes). My commit `45870c1` (17:10:52, **R9 message but R10 content**: A1, A3, B1–B9, and a *partially-applied A2* — see incident above) landed right after. So the R10 baseline is now `45870c1`, and the remaining R10 work (A2-fix, A4, A5, A6, `lint.sh`) is in the working tree, uncommitted.

**Decision (user, 2026-09-25: “good, commit”) → option 1, adopted.**
1. ✅ **(clean history — ADOPTED)** `git reset --soft 3119819` → one commit `review R10: zero shellcheck findings (17→0): quotes/rewrites, dead-code comment-out/removal, ui_yesno args array, mapfile menu (beta lock-in)` covering everything with the right message; the broken A2 intermediate never enters history.
2. (append) commit the working tree on top as `review R10: …` — would have left `45870c1` (R9 message, R10 content) in history. Not used; `45870c1` becomes a dangling, unreferenced object.

Staged either way: `pisafe`, `REVIEW_ROUNDS.md`, `REVIEW_ROUND_10.md`, `lint.sh`. **No push, no tag, no version bump.**

**Status: ✅ COMMITTED on `dev` (2026-09-25, user-approved; option 1 — soft-reset to `3119819`, single clean R10 commit). Beta freeze in effect per user directive.**
